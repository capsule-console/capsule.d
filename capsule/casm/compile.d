module capsule.casm.compile;

import capsule.core.ascii : isDigit;
import capsule.core.crc : CRC32, CRC64ISO;
import capsule.core.encoding : CapsuleArchitecture, CapsuleHashType;
import capsule.core.encoding : CapsuleTextEncoding, CapsuleTimeEncoding;
import capsule.core.enums : getEnumMemberAttribute, getEnumMemberWithAttribute;
import capsule.core.file : File, FileLocation;
import capsule.core.lz77 : lz77Deflate;
import capsule.core.math : lcm, isPow2;
import capsule.core.obj : CapsuleObject;
import capsule.core.path : Path;
import capsule.core.programsource : CapsuleProgramSource;
import capsule.core.time : getUnixSeconds;
import capsule.core.types : CapsuleOpcode, CapsuleInstruction;

import capsule.casm.messages : CapsuleAsmMessageStatus, CapsuleAsmMessageMixin;
import capsule.casm.messages : CapsuleAsmMessageStatusSeverity;
import capsule.casm.parse : CapsuleAsmParser;
import capsule.casm.reference : findCapsuleObjectPcRelHighReference;
import capsule.casm.reference : resolveCapsuleObjectReference;
import capsule.casm.reference : resolveCapsuleObjectReferenceValue;
import capsule.casm.syntax : CapsuleAsmNode;

public:

/// TODO: Load from a config file or something instead of hardcoding
static const uint MaxAcceptableAlignment = 256;
static const uint MaxAcceptableIncludeDepth = 256;

/// Representation of a Capsule object section generated internally
/// by the compiler and used later to assemble a CapsuleObject instance
struct CapsuleCompilerObjectSection {
    alias Constant = CapsuleCompilerObjectConstant;
    alias Label = CapsuleCompilerObjectLabel;
    alias Node = CapsuleAsmNode;
    alias Reference = CapsuleCompilerObjectReference;
    alias Source = CapsuleProgramSource;
    alias Symbol = CapsuleCompilerObjectSymbol;
    alias Type = CapsuleObject.Section.Type;
    
    /// Where in the source code the section is declared
    FileLocation location;
    /// Whether the section is .text, .data, or .rodata
    Type type = Type.None;
    /// LCM of values given by .align directives
    uint alignment = 4;
    /// Section's priority value, as given by a .priority directive
    int priority = 0;
    /// Set when the first .priority directive is found in the section
    bool hasPriority = false;
    ///
    uint length = 0;
    ///
    string name = null;
    /// Compiled bytecode or other binary data
    ubyte[] bytes = null;
    /// List of label definitions
    Label[] labels = null;
    /// List of scoped symbol declarations without definitions,
    /// i.e. via the directives .export, .global
    Symbol[] symbols = null;
    /// List of symbol references
    Reference[] references = null;
    /// Indicates the syntax node for the most recent .procedure directive
    /// The property is set to a null node after applying the directive
    /// to a definition
    Node definitionTypeNode = Node.init;
    /// Indicates whether there has been an instruction alignment
    /// status message yet for this section (as to not be repetitious)
    bool badInstructionAlignment = false;
    ///
    bool makeSourceMap = false;
    ///
    Source.Map sourceMap;
    
    /// Add a single byte to an initialized data section
    void addByte(in FileLocation location, in ubyte value) {
        assert(this.isInitialized);
        if(this.makeSourceMap) {
            this.sourceMap.add(location, this.length, 1);
        }
        this.bytes ~= value;
        this.length++;
        assert(this.length == this.bytes.length);
    }
    
    /// Add a half word to an initialized data section
    void addHalfWord(in FileLocation location, in ushort value) @trusted {
        assert(this.isInitialized);
        if(this.makeSourceMap) {
            this.sourceMap.add(location, this.length, 2);
        }
        const offset = this.bytes.length;
        this.bytes.length += 2;
        *(cast(ushort*) &this.bytes[offset]) = value;
        this.length += 2;
        assert(this.length == this.bytes.length);
    }
    
    /// Add a word to an initialized data section
    void addWord(in FileLocation location, in uint value) @trusted {
        assert(this.isInitialized);
        if(this.makeSourceMap) {
            this.sourceMap.add(location, this.length, 4);
        }
        const offset = this.bytes.length;
        this.bytes.length += 4;
        *(cast(uint*) &this.bytes[offset]) = value;
        this.length += 4;
        assert(this.length == this.bytes.length);
    }
    
    /// Add bytes to an initialized data section
    void addBytes(T)(in FileLocation location, in T[] values) {
        assert(this.isInitialized);
        if(this.makeSourceMap) {
            this.sourceMap.add(location, this.length, cast(uint) values.length);
        }
        this.bytes ~= cast(ubyte[]) values;
        this.length += T.sizeof * values.length;
        assert(this.length == this.bytes.length);
    }
    
    /// Reserve bytes in the section.
    /// The given fill value will be used when reserving bytes in an
    /// initialized data section, otherwise the fill value will always
    /// be treated as zero.
    void reserveBytes(in FileLocation location, in uint count, in ubyte fill = 0) {
        if(this.makeSourceMap) {
            this.sourceMap.add(location, this.length, count);
        }
        if(this.isInitialized) {
            uint i = cast(uint) this.bytes.length;
            this.bytes.length += count;
            while(i < this.bytes.length) {
                this.bytes[i++] = fill;
            }
        }
        this.length += count;
        assert(!this.isInitialized || this.length == this.bytes.length);
    }
    
    void reserveHalfWords(
        in FileLocation location, in uint count, in ushort fill = 0
    ) @trusted {
        if(this.makeSourceMap) {
            this.sourceMap.add(location, this.length, 2 * count);
        }
        if(this.isInitialized) {
            uint i = cast(uint) this.bytes.length;
            this.bytes.length += 2 * count;
            while(1 + i < this.bytes.length) {
                *(cast(ushort*) &this.bytes[i]) = fill;
                i += 2;
            }
            assert(i == this.bytes.length);
        }
        this.length += 2 * count;
        assert(!this.isInitialized || this.length == this.bytes.length);
    }
    
    void reserveWords(
        in FileLocation location, in uint count, in uint fill = 0
    ) @trusted {
        if(this.makeSourceMap) {
            this.sourceMap.add(location, this.length, 4 * count);
        }
        if(this.isInitialized) {
            uint i = cast(uint) this.bytes.length;
            this.bytes.length += 4 * count;
            while(3 + i < this.bytes.length) {
                *(cast(uint*) &this.bytes[i]) = fill;
                i += 4;
            }
            assert(i == this.bytes.length);
        }
        this.length += 4 * count;
        assert(!this.isInitialized || this.length == this.bytes.length);
    }
    
    void alignWord() {
        if(this.length % 4 != 0) {
            this.reserveBytes(FileLocation.init, 4 - (this.length % 4), 0);
        }
    }
    
    void alignHalfWord() {
        if(this.length % 2 != 0) {
            this.reserveBytes(FileLocation.init, 1, 0);
        }
    }
    
    /// Check whether the section type is for a segment containing
    /// initialized data (data, rodata, text) or uninitialized data (bss).
    bool isInitialized() const {
        return CapsuleObject.Section.typeIsInitialized(this.type);
    }
}

struct CapsuleCompilerObjectLabel {
    alias Type = CapsuleObject.Symbol.Type;
    alias Visibility = CapsuleObject.Symbol.Visibility;
    
    FileLocation location;
    string name = null;
    uint offset = 0;
    uint length = 0;
    Type type = Type.Label;
    Visibility visibility = Visibility.None;
    uint section;
}

struct CapsuleCompilerObjectSymbol {
    alias Type = CapsuleObject.Symbol.Type;
    alias Visibility = CapsuleObject.Symbol.Visibility;
    
    FileLocation location;
    Type type;
    Visibility visibility;
    string name;
}

struct CapsuleCompilerObjectReference {
    alias LocalType = CapsuleObject.Reference.LocalType;
    alias Type = CapsuleObject.Reference.Type;
    
    /// Location of this reference in the source file
    FileLocation location;
    /// Indicates the size and expected content of the reference
    Type type = Type.None;
    /// Name of the symbol being referenced
    string name = null;
    /// Byte offset of reference in section
    uint offset = 0;
    /// Will be added to the value being referenced
    int addend = 0;
    /// Forward or backward local label reference,
    /// in the case that it is a local reference?
    LocalType localType;
    /// Whether the reference has been resolved by the compiler
    bool resolved = false;
    /// The resolved value
    uint symbolValue = 0;
    /// The length of the resolved symbol value
    uint symbolLength = 0;
    
    /// Determine whether this reference is PC-relative.
    bool isPcRelative() const {
        return CapsuleObject.Reference.isPcRelativeType(this.type);
    }
    
    /// Determine whether this reference represents the low half
    /// of a PC-relative offset.
    bool isPcRelativeLowHalf() const {
        return CapsuleObject.Reference.isPcRelativeLowHalfType(this.type);
    }
    
    /// Determine whether this reference is the low half of a
    /// reference and should have a corresponding high half someplace.
    bool isNearLowHalfType() const {
        return CapsuleObject.Reference.isNearLowHalfType(this.type);
    }
    
    /// Get the high half reference type corresponding to this reference's
    /// low half type, or CapsuleObject.Reference.Type.None if this
    /// reference type has no corresponding high half type.
    Type getHighHalfType() const {
        return CapsuleObject.Reference.getHighHalfType(this.type);
    }
    
    /// Get a value added to the reference's own offset indicating a
    /// position where bytes are modified in resolving the reference.
    uint typeOffset() const {
        return CapsuleObject.Reference.typeOffset(this.type);
    }
    
    /// Get the number of bytes starting from the sum of the reference's
    /// offset or address and its `typeOffset` that are overwritten when
    /// resolving a reference.
    uint typeLength() const {
        return CapsuleObject.Reference.typeLength(this.type);
    }
}

struct CapsuleCompilerObjectConstant {
    alias Visibility = CapsuleObject.Symbol.Visibility;
    
    FileLocation location;
    Visibility visibility;
    string name;
    uint value;
    uint section;
}

struct CapsuleCompilerObjectSymbolDeclaration {
    FileLocation location;
    string name;
}

enum CapsuleCompilerObjectGlobalType: uint {
    None = 0,
    Constant,
    Label,
    Extern,
}

struct CapsuleCompilerObjectGlobal {
    alias Type = CapsuleCompilerObjectGlobalType;
    
    FileLocation location = FileLocation.init;
    uint sectionIndex;
    string name = null;
    Type type = Type.None;
    /// Constant value or label offset
    uint value = 0;
    /// Symbol length value
    uint length = 0;
    
    static bool isDefinedType(in Type type) {
        switch(type) {
            case Type.None: return false;
            case Type.Constant: return true;
            case Type.Label: return true;
            case Type.Extern: return false;
            default: return false;
        }
    }
    
    bool isDefined() const {
        return typeof(this).isDefinedType(this.type);
    }
}

struct CapsuleAsmCompiler {
    mixin CapsuleAsmMessageMixin;
    
    alias Architecture = CapsuleArchitecture;
    alias Constant = CapsuleCompilerObjectConstant;
    alias DirectiveType = CapsuleAsmNode.DirectiveType;
    alias Export = CapsuleCompilerObjectSymbolDeclaration;
    alias Extern = CapsuleCompilerObjectSymbolDeclaration;
    alias Global = CapsuleCompilerObjectGlobal;
    alias GlobalMap = Global[string];
    alias HashType = CapsuleHashType;
    alias Label = CapsuleCompilerObjectLabel;
    alias LocalType = CapsuleObject.Reference.LocalType;
    alias Node = CapsuleAsmNode;
    alias Object = CapsuleObject;
    alias Parser = CapsuleAsmParser;
    alias PseudoInstructionType = CapsuleAsmNode.PseudoInstructionType;
    alias Reference = CapsuleCompilerObjectReference;
    alias Section = CapsuleCompilerObjectSection;
    alias Source = CapsuleObject.Source;
    alias Symbol = CapsuleCompilerObjectSymbol;
    alias SectionType = CapsuleObject.Section.Type;
    alias SymbolType = CapsuleObject.Symbol.Type;
    alias TextEncoding = CapsuleTextEncoding;
    alias TimeEncoding = CapsuleTimeEncoding;
    alias Visibility = CapsuleObject.Symbol.Visibility;
    
    /// Compile code from these concatenated sources
    File[] sourceFiles;
    /// Will store the full list of syntax nodes upon parsing sources
    Node[] nodes;
    /// Current index in the node list during compliation
    size_t nodeIndex = 0;
    
    /// Concatenation of .comment directive strings
    string comment;
    /// A list of object file section representations
    Section[] sections;
    /// A list of exported symbols, indexed by name
    Export[string] exports;
    /// A list of names given by .extern symbol declarations
    Extern[] externs;
    /// A list of contants defined via .const directives
    Constant[] constants = null;
    /// Set to true when the first .entry directive is encountered
    bool entryExplicit = false;
    /// Indicates which section the entry point is located in
    uint entrySectionIndex = 0;
    /// Indicates the offset of the entry point within the containing section
    uint entryOffset = 0;
    /// Compiled object file data
    Object object;
    /// Data structure used to index globally-visible declarations
    GlobalMap globalMap;
    
    /// Configuration flag to set whether local references (references to
    /// a symbol within the same section) are resolved by the compiler before
    /// outputting an object, or left in the object for a linker to resolve
    /// later on.
    /// This isn't particularly useful right now, but it could be in the
    /// future if the linker is able to "relax" jumps & etc.
    bool doResolveLocalReferences = true;
    
    /// Try these directory paths in order when resolving a relative path
    /// for an .incbin or .include directive.
    string[] includePaths = null;
    
    /// Flag determines whether source file content is included in the
    /// outputted object data.
    bool doWriteDebugInfo = false;
    /// If sources are included (doWriteDebugInfo is true) then this value
    /// indicates what encoding or compression scheme should be used for
    /// representing source code file content.
    Source.Encoding objectSourceEncoding = Source.Encoding.CapsuleLZ77;
    /// List of sources used in compiling an object, but the list is only
    /// populated if doWriteDebugInfo was true
    Source[] objectSources = null;
    
    this(Log* log, File sourceFile) {
        this(log, [sourceFile]);
    }
    
    this(Log* log, File[] sourceFiles) {
        assert(log);
        this.log = log;
        this.sourceFiles = sourceFiles;
        this.addSection(FileLocation.init, SectionType.None);
    }
    
    void addReferenceStatus(in Status status, in Reference reference) @trusted {
        const typeName = getEnumMemberAttribute!string(reference.type);
        const localType = cast(string) (reference.localType ?
            [cast(char) reference.localType] : null
        );
        const context = (reference.name ~ localType ~ "[" ~ typeName ~ "]");
        this.addStatus(reference.location, status, context);
    }
    
    Section* currentSection() @system {
        assert(this.sections.length);
        return this.sections.length ? &this.sections[$ - 1] : null;
    }
    
    uint currentSectionIndex() const {
        assert(this.sections.length);
        return this.sections.length ? cast(uint) (this.sections.length - 1) : 0;
    }
    
    /// To be used when retrieving the current section, but where
    /// retrieving the unconditionally generated first untyped section that
    /// may contain declarations such as .const and .extern won't do.
    Section* requireDeclaredSection(in FileLocation location) @trusted {
        auto section = this.currentSection;
        if(!section) {
            this.addStatus(location, Status.OperationInUndeclaredSection);
        }
        return section;
    }
    
    Section* requireInitializedSection(in FileLocation location) @trusted {
        auto section = this.requireDeclaredSection(location);
        if(!section.isInitialized) {
            this.addStatus(location, Status.DataInUninitializedSection);
        }
        return section;
    }
    
    auto addSection(in FileLocation location, in SectionType type) {
        if(this.sections.length >= uint.max) {
            this.addStatus(location, Status.TooManySections);
            return;
        }
        if(this.sections.length && this.sections[$ - 1].definitionTypeNode) {
            const defNode = this.sections[$ - 1].definitionTypeNode;
            this.addStatus(
                defNode.location,
                Status.HangingDefinitionTypeDirective,
                defNode.getName(),
            );
        }
        Section section = {
            location: location,
            type: type,
        };
        section.sourceMap.sources = this.objectSources;
        section.makeSourceMap = this.doWriteDebugInfo;
        this.sections ~= section;
    }
    
    void addReference(Section* section, in Reference reference) {
        assert(section !is null);
        assert(section.type);
        assert(reference.type);
        assert(reference.name.length);
        assert(!isDigit(reference.name[0]) || reference.localType);
        if(section && section.references.length >= uint.max) {
            this.addStatus(FileLocation.init, Status.TooManyReferences);
            return;
        }
        if(section !is null) {
            section.references ~= reference;
        }
    }
    
    void addReference(
        Section* section, in FileLocation location, in Node.Number number,
        in uint offset, in uint targetLength, in uint maxRefLength,
        in bool allowPcRelative
    ) {
        // Make sure this isn't an absolute word (32 bit) reference
        // trying to get crammed into a 16 bit immediate or something
        const refLength = Object.Reference.typeLength(number.referenceType);
        const refOffset = Object.Reference.typeOffset(number.referenceType);
        const pcRel = Object.Reference.isPcRelativeType(number.referenceType);
        if(refLength > maxRefLength || refLength + refOffset > targetLength ||
            (pcRel && !allowPcRelative)
        ) {
            this.addStatus(
                location, Status.InvalidObjectReference, number.name
            );
            return;
        }
        // Keep track of the reference needed to resolve the immediate
        Reference reference = {
            location: location,
            type: number.referenceType,
            name: number.name,
            offset: offset + (targetLength - refOffset - refLength),
            addend: number.addend,
            localType: number.localType,
        };
        this.addReference(section, reference);
    }
    
    uint byteOffset() const {
        assert(this.sections.length);
        return cast(uint) this.sections[$ - 1].length;
    }
    
    typeof(this) compile() {
        // Handle debug info
        if(this.doWriteDebugInfo) this.objectSources = this.getObjectSources();
        // Given the list of assembly sources, get a list of syntax nodes
        this.nodes = this.parseSources();
        if(this.log.anyErrors) return this;
        // Compile the parsed nodes into a list of object sections and etc.
        this.compileSources();
        if(this.log.anyErrors) return this;
        // Make sure every .export'ed symbol was actually defined someplace
        this.checkExportSymbols();
        if(this.log.anyErrors) return this;
        // Resolve references to labels defined in the same section
        if(this.doResolveLocalReferences) this.resolveReferences();
        if(this.log.anyErrors) return this;
        // Put together the resulting object
        this.object = this.createObject();
        if(this.log.anyErrors) return this;
        // All done
        return this;
    }
    
    Node[] parseSources() {
        assert(this.log);
        this.addStatus(FileLocation.init, Status.CompileParseSources);
        Node[] nodes;
        foreach(source; this.sourceFiles) {
            this.addStatus(FileLocation(source), Status.CompileParseSourceFile);
            auto parser = Parser(this.log, source);
            parser.parse();
            nodes ~= parser.nodes;
            if(this.log.anyErrors) {
                return nodes;
            }
        }
        return nodes;
    }
    
    Source[] getObjectSources() const {
        Source[] objectSources = [];
        foreach(sourceFile; this.sourceFiles) {
            const source = this.getObjectSource(sourceFile);
            if(!this.hasObjectSource(source)) {
                objectSources ~= source;
            }
        }
        return objectSources;
    }
    
    Source getObjectSource(in File file) const {
        const fileName = Path(file.path).normalize().toString();
        const useLz77 = (
            this.objectSourceEncoding is Source.Encoding.CapsuleLZ77
        );
        const encoding = (useLz77 ?
            Source.Encoding.CapsuleLZ77 : Source.Encoding.None
        );
        const content = (useLz77 ?
            cast(string) lz77Deflate(file.content) : file.content
        );
        const checksum = Source.getChecksum(fileName, file.content);
        const Source objectSource = {
            encoding: encoding,
            checksum: checksum,
            name: fileName,
            content: content,
        };
        return objectSource;
    }
    
    bool hasObjectSource(in Source source) const {
        foreach(objectSource; this.objectSources) {
            if(source == objectSource) {
                return true;
            }
        }
        return false;
    }
    
    void addExport(in Export exported) {
        assert(exported.name.length);
        this.exports[exported.name] = exported;
    }
    
    bool isExportedSymbolName(in string name) {
        return (name in this.exports) !is null;
    }
    
    void addConstantToGlobalMap(in Constant constant) {
        if(constant.name in globalMap) this.addStatus(
            constant.location, Status.DuplicateSymbolDeclaration, constant.name
        );
        Global globalConstantDecl = {
            location: constant.location,
            sectionIndex: constant.section,
            name: constant.name,
            type: Global.Type.Constant,
            value: constant.value,
            length: 0,
        };
        globalMap[constant.name] = globalConstantDecl;
        const addStatus = (constant.visibility is Visibility.Global ?
            Status.CompileCreateGlobalMapIndexGlobalConst :
            Status.CompileCreateGlobalMapIndexExportConst
        );
        this.addStatus(constant.location, addStatus, constant.name);
    }
    
    void addExternToGlobalMap(in Extern external) {
        if(external.name in globalMap) this.addStatus(
            external.location, Status.DuplicateSymbolDeclaration, external.name
        );
        Global globalExternDecl = {
            location: external.location,
            sectionIndex: 0,
            name: external.name,
            type: Global.Type.Extern,
            value: 0,
            length: 0,
        };
        globalMap[external.name] = globalExternDecl;
        this.addStatus(
            external.location,
            Status.CompileCreateGlobalMapIndexGlobalExtern,
            external.name
        );
    }
    
    void addLabelToGlobalMap(in Label label) {
        assert(label.visibility is Visibility.Global ||
            label.visibility is Visibility.Export
        );
        if(label.name in globalMap) this.addStatus(
            label.location, Status.DuplicateSymbolDeclaration, label.name
        );
        Global globalLabelDecl = {
            location: label.location,
            sectionIndex: label.section,
            name: label.name,
            type: Global.Type.Label,
            value: label.offset,
            length: label.length,
        };
        globalMap[label.name] = globalLabelDecl;
        const addStatus = (label.visibility is Visibility.Global ?
            Status.CompileCreateGlobalMapIndexGlobalLabel :
            Status.CompileCreateGlobalMapIndexExportLabel
        );
        this.addStatus(label.location, addStatus, label.name);
    }
    
    /// Look for any hanging .export declarations that refer to symbols that
    /// were never defined, and emit a status message for each problem found.
    void checkExportSymbols() {
        this.addStatus(FileLocation.init, Status.CompileCheckExportSymbols);
        foreach(exported; this.exports.values) {
            if(const global = exported.name in globalMap) {
                if(!global.isDefined) this.addStatus(
                    exported.location, Status.ExportUndefinedSymbol, exported.name
                );
            }
            else {
                this.addStatus(
                    exported.location, Status.ExportUndeclaredSymbol, exported.name
                );
            }
        }
    }
    
    void resolveReferences() {
        this.addStatus(FileLocation.init, Status.CompileResolveLocalReferences);
        for(size_t i = 0; i < this.sections.length; i++) {
            for(size_t j = 0; j < this.sections[i].references.length; j++) {
                this.resolveReference(i, j);
            }
        }
    }
    
    void resolveReference(in size_t sectionIndex, in size_t referenceIndex) {
        alias LinkDirectiveType = Node.Number.LinkDirectiveType;
        assert(sectionIndex < this.sections.length);
        assert(referenceIndex < this.sections[sectionIndex].references.length);
        auto section = this.sections[sectionIndex];
        auto reference = section.references[referenceIndex];
        if(reference.resolved) {
            return;
        }
        this.addStatus(
            reference.location, Status.CompileTryResolveReference, reference.name
        );
        if(!section.isInitialized) {
            this.addStatus(
                reference.location,
                Status.ReferenceInUninitializedSection,
                reference.name
            );
            return;
        }
        uint symbolValue = 0;
        uint symbolLength = 0;
        uint pcOffset = reference.offset;
        // Resolve offsets for references to local labels
        if(reference.localType !is LocalType.None) {
            const localDefinition = this.getLocalLabelDefinition(
                cast(uint) sectionIndex, reference.offset,
                reference.name, reference.localType
            );
            if(localDefinition.status != Status.Ok) {
                this.addStatus(
                    reference.location, localDefinition.status, reference.name
                );
                return;
            }
            symbolValue = localDefinition.label.offset;
            symbolLength = localDefinition.label.length;
        }
        // References of type pcrel_near_lo look for a corresponding pcrel_hi
        // reference in the immediately previous word
        else if(reference.isNearLowHalfType) {
            symbolValue = reference.offset - 4;
        }
        else if(reference.name.length && reference.name[0] == '.' &&
            getEnumMemberWithAttribute!LinkDirectiveType(reference.name[1 .. $])
        ) {
            this.addStatus(
                reference.location,
                Status.CompileResolveReferenceNotEnoughInfo,
                reference.name
            );
            return;
        }
        // Resolve references to global labels defined in the same section
        else if(auto global = reference.name in this.globalMap) {
            if(!(global.type is Global.Type.Constant || (
                global.type is Global.Type.Label &&
                global.sectionIndex == sectionIndex
            ))) {
                this.addStatus(
                    reference.location,
                    Status.CompileResolveReferenceNotEnoughInfo,
                    reference.name
                );
                return;
            }
            symbolValue = global.value;
            symbolLength = global.length;
        }
        // Handle references to undeclared symbols
        else {
            this.addStatus(
                reference.location, Status.UndeclaredSymbolReference, reference.name
            );
            return;
        }
        // Handle pcrel_lo references to local labels; the result depends
        // on the resolved value of a corresponding pcrel_hi reference
        if(reference.isPcRelativeLowHalf) {
            const hiRefIndex = findCapsuleObjectPcRelHighReference(
                section.references, reference.type, reference.name, symbolValue
            );
            if(!hiRefIndex.ok) {
                const status = (reference.type is Reference.Type.PCRelativeAddressLowHalf ?
                    Status.ObjectReferenceUnmatchedPCRelLo :
                    Status.ObjectReferenceUnmatchedPCRelNearLo
                );
                this.addReferenceStatus(status, reference);
                return;
            }
            else if(!section.references[hiRefIndex.index].resolved) {
                this.resolveReference(sectionIndex, hiRefIndex.index);
            }
            if(!section.references[hiRefIndex.index].resolved) {
                this.addReferenceStatus(
                    Status.CompileResolveReferenceNotEnoughInfo, reference
                );
                return;
            }
            pcOffset = symbolValue;
            symbolValue = section.references[hiRefIndex.index].symbolValue;
            symbolLength = section.references[hiRefIndex.index].symbolLength;
        }
        // Resolve and write the referenced value to the compiled section
        const resolved = resolveCapsuleObjectReference(
            section.bytes, reference.type, reference.offset,
            pcOffset, reference.addend, symbolValue, symbolLength
        );
        if(resolved.status !is Status.Ok) {
            this.addReferenceStatus(resolved.status, reference);
        }
        else {
            section.references[referenceIndex].resolved = true;
            section.references[referenceIndex].symbolValue = symbolValue;
            section.references[referenceIndex].symbolLength = symbolLength;
            this.addReferenceStatus(
                Status.CompileResolveReferenceSuccess, reference
            );
        }
    }
    
    auto getLocalLabelDefinition(
        in uint sectionIndex, in uint offset,
        in string name, in LocalType localType
    ) {
        struct Result {
            Status status;
            Label label;
        }
        assert(sectionIndex < this.sections.length);
        const section = this.sections[sectionIndex];
        uint closestIndex = cast(uint) section.labels.length;
        uint closestOffset = uint.max;
        for(uint i = 0; i < section.labels.length; i++) {
            const label = section.labels[i];
            if(label.visibility is Visibility.Local) {
                if(localType is LocalType.Backward &&
                    label.offset <= offset &&
                    offset - label.offset < closestOffset &&
                    label.name == name
                ) {
                    closestIndex = i;
                    closestOffset = offset - label.offset;
                }
                else if(localType is LocalType.Forward &&
                    label.offset > offset &&
                    label.offset - offset < closestOffset &&
                    label.name == name
                ) {
                    closestIndex = i;
                    closestOffset = label.offset - offset;
                }
            }
        }
        if(closestIndex < section.labels.length) {
            return Result(Status.Ok, section.labels[closestIndex]);
        }
        else {
            return Result(Status.UndefinedSymbol);
        }
    }
    
    string getObjectSourceUri() const {
        string uri = "";
        foreach(source; this.sourceFiles) {
            if(uri.length) uri ~= ",";
            uri ~= source.path;
        }
        return uri;
    }
    
    ulong getObjectSourceHash() @trusted const {
        CRC64ISO crc;
        foreach(source; this.sourceFiles) {
            crc.put(cast(byte[]) source.content);
        }
        return crc.result;
    }
    
    Object createObject() {
        Object object;
        object.comment = this.comment;
        object.hasEntry = this.entryExplicit;
        object.entryOffset = this.entryOffset;
        object.sourceUri = this.getObjectSourceUri();
        object.textEncoding = TextEncoding.Ascii;
        object.timeEncoding = TimeEncoding.UnixEpochSeconds;
        object.architecture = Architecture.Capsule;
        object.sourceHashType = HashType.CRC64ISO;
        object.sourceHash = this.getObjectSourceHash();
        object.timestamp = getUnixSeconds();
        object.sources = this.objectSources;
        object.sectionSourceLocations.reserve(this.sections.length);
        bool tooManyNames = false;
        bool tooManySymbols = false;
        bool tooManyReferences = false;
        bool tooManySections = false;
        uint getNameIndex(in string name) {
            const nameIndex = object.getNameIndex(name);
            if(object.names.length >= uint.max) {
                tooManyNames = true;
                return uint.max;
            }
            if(nameIndex >= object.names.length) {
                object.names ~= name;
            }
            return cast(uint) nameIndex;
        }
        uint getOptionalNameIndex(in string name) {
            return name.length ? getNameIndex(name) : Object.NoName;
        }
        void addObjectSymbol(in Object.Symbol symbol) {
            if(object.symbols.length >= uint.max) {
                tooManySymbols = true;
            }
            else {
                object.symbols ~= symbol;
            }
        }
        foreach(external; this.externs) {
            Object.Symbol objSymbol = {
                section: 0,
                type: Object.Symbol.Type.Undefined,
                visibility: Visibility.Extern,
                name: getNameIndex(external.name),
                value: 0,
                length: 0,
            };
            addObjectSymbol(objSymbol);
        }
        foreach(constant; this.constants) {
            Object.Symbol objSymbol = {
                section: constant.section == 0 ? 0 : constant.section - 1,
                type: Object.Symbol.Type.Constant,
                visibility: constant.visibility,
                name: getNameIndex(constant.name),
                value: constant.value,
                length: 0,
            };
            addObjectSymbol(objSymbol);
        }
        for(size_t i = 0; i < this.sections.length; i++) {
            auto section = this.sections[i];
            const uint sectionIndex = cast(uint) object.sections.length;
            if(i != 0 || section.type !is Section.Type.None) {
                assert(!section.isInitialized ||
                    section.length == section.bytes.length
                );
                if(object.sections.length >= uint.max) {
                    tooManySections = true;
                    break;
                }
                Object.Section objSection = {
                    type: section.type,
                    name: getOptionalNameIndex(section.name),
                    alignment: section.alignment,
                    priority: section.priority,
                    checksum: CRC32.get(section.bytes),
                    length: section.length,
                    bytes: section.bytes,
                };
                if(this.entryExplicit && i == this.entrySectionIndex) {
                    object.entrySection = cast(uint) object.sections.length;
                }
                object.sections ~= objSection;
                object.sectionSourceLocations ~= section.sourceMap.locations;
            }
            else {
                assert(section.length == 0);
                assert(section.bytes.length == 0);
                assert(section.labels.length == 0);
                assert(section.references.length == 0);
                assert(!this.entryExplicit || (i != this.entrySectionIndex));
            }
            foreach(label; section.labels) {
                Object.Symbol objSymbol = {
                    section: sectionIndex,
                    type: label.type,
                    visibility: label.visibility,
                    name: getNameIndex(label.name),
                    value: label.offset,
                    length: label.length,
                };
                addObjectSymbol(objSymbol);
            }
            foreach(reference; section.references) {
                if(reference.resolved) continue;
                // Local references should have been resolved in a prior step
                assert(!this.doResolveLocalReferences || !reference.localType);
                if(object.references.length >= uint.max) {
                    tooManyReferences = true;
                    break;
                }
                Object.Reference objReference = {
                    section: sectionIndex,
                    type: reference.type,
                    localType: reference.localType,
                    name: getNameIndex(reference.name),
                    offset: reference.offset,
                    addend: reference.addend,
                };
                object.references ~= objReference;
            }
        }
        // Emit messages if any list length exceeded uint.max
        if(tooManyNames) {
            this.addStatus(FileLocation.init, Status.TooManyNames);
        }
        if(tooManySymbols) {
            this.addStatus(FileLocation.init, Status.TooManySymbols);
        }
        if(tooManyReferences) {
            this.addStatus(FileLocation.init, Status.TooManyReferences);
        }
        if(tooManySections) {
            this.addStatus(FileLocation.init, Status.TooManySections);
        }
        // All done
        return object;
    }
    
    /// Enumerate all syntax nodes parsed from sources and handle
    /// their compilation.
    void compileSources() {
        bool isFirstPassNode(in Node node) {
            if(node.isDirective) {
                const dirType = node.directiveType;
                return (
                    dirType is Node.DirectiveType.Constant ||
                    dirType is Node.DirectiveType.Comment ||
                    dirType is Node.DirectiveType.Export ||
                    dirType is Node.DirectiveType.Extern ||
                    dirType is Node.DirectiveType.IncludeSource
                );
            }
            return false;
        }
        // First pass: Handle directives that behave the same regardless
        // of which section they are in or where.
        // .const, .comment, .export, .extern
        this.nodeIndex = 0;
        while(this.ok && this.nodeIndex < this.nodes.length) {
            if(isFirstPassNode(this.nodes[this.nodeIndex])) {
                this.compileSyntaxNode(this.nodes[this.nodeIndex]);
            }
            this.nodeIndex++;
        }
        // Mark exported constants, and add them to the globals map
        foreach(ref constant; this.constants) {
            if(this.isExportedSymbolName(constant.name)) {
                constant.visibility = Visibility.Export;
            }
            this.addConstantToGlobalMap(constant);
        }
        // Add extern declarations to the globals map
        foreach(external; this.externs) {
            this.addExternToGlobalMap(external);
        }
        // Second pass: Handle everything else
        this.nodeIndex = 0;
        while(this.ok && this.nodeIndex < this.nodes.length) {
            if(!isFirstPassNode(this.nodes[this.nodeIndex])) {
                this.compileSyntaxNode(this.nodes[this.nodeIndex]);
            }
            this.nodeIndex++;
        }
    }
    
    void compileSyntaxNode(in Node node) {
        // The node respresents a label
        if(node.isLabel) {
            this.compileLabel(node);
        }
        // The node represents an instruction
        else if(node.isInstruction) {
            this.compileInstruction(node);
        }
        // The node represents a pseudo-instruction
        else if(node.isPseudoInstruction) {
            this.compilePseudoInstruction(node);
        }
        // The node represents a directive
        else if(node.isDirective) {
            this.compileDirective(node);
        }
        else {
            assert(false, "Unhandled syntax node type: " ~ node.getName());
        }
    }
    
    void compileLabel(in Node node) {
        assert(node.isLabel);
        assert(node.label.name.length);
        this.addStatus(
            node.location, Status.CompileLabelDefinition, node.label.name
        );
        // Get and verify the containing section
        auto section = this.requireDeclaredSection(node.location);
        if(!section) return;
        // Handle .procedure or other definition type directives
        auto labelType = Symbol.Type.Label;
        if(section.definitionTypeNode) {
            const defType = section.definitionTypeNode.getDirectiveDefinitionType;
            assert(defType !is Symbol.Type.None);
            if(defType !is Symbol.Type.None) {
                labelType = defType;
            }
            section.definitionTypeNode = Node.init;
        }
        // Determine label visibility
        const isLocal = node.label.isLocal;
        auto visibility = isLocal ? Visibility.Local : Visibility.Global;
        if(!isLocal && this.isExportedSymbolName(node.label.name)) {
            visibility = Visibility.Export;
        }
        // Append the label to the section's label list
        const offset = this.byteOffset;
        Label label = {
            location: node.location,
            name: node.label.name,
            offset: offset,
            visibility: visibility,
            type: labelType,
            section: this.currentSectionIndex,
        };
        section.labels ~= label;
        // The first label in a section determines the section's name
        if(offset == 0 && !section.name.length) {
            section.name = node.label.name;
        }
        // Add global label definitions to the globals map
        if(!isLocal) {
            this.addLabelToGlobalMap(label);
        }
    }
    
    void compileInstruction(in Node node) {
        assert(node.isInstruction);
        auto section = this.requireInitializedSection(node.location);
        if(!section) return;
        // Check alignment and emit a message if the instruction isn't
        // going to be written to a 4-byte word boundary
        if(!section.badInstructionAlignment && (
            section.length % 4 != 0 || section.alignment % 4 != 0
        )) {
            this.addStatus(
                node.location, Status.MisalignedInstruction
            );
            section.badInstructionAlignment = true;
        }
        // Determine the instruction's immediate value
        const uint offset = section.length;
        typeof(Node.init.instruction) instruction = node.instruction;
        const immValue = this.tryResolveNumberValue(node.instruction.immediate);
        if(!immValue.ok) this.addStatus(
            node.location, immValue.status, node.instruction.immediate.name
        );
        if(immValue.canWrite) {
            instruction.immediate = Node.Number(immValue.writeValue);
        }
        else {
            this.addReference(
                section, node.location, node.instruction.immediate,
                section.length, 4, 2, true
            );
        }
        // Encode the instruction
        const uint encodedInstr = instruction.encode();
        section.addWord(node.location, encodedInstr);
    }
    
    void compilePseudoInstruction(in Node node) @trusted {
        assert(node.isPseudoInstruction);
        alias Opcode = CapsuleOpcode;
        alias PseudoType = Node.PseudoInstructionType;
        alias Number = Node.Number;
        alias emit = this.compileInstruction;
        const pseudoType = node.pseudoInstructionType;
        const loc = node.location;
        const rd = node.instruction.rd;
        const rs1 = node.instruction.rs1;
        const rs2 = node.instruction.rs2;
        const immediate = node.instruction.immediate;
        void emitHighHalf(in Number high) {
            const isPcRelative = CapsuleObject.Reference.isPcRelativeType(
                high.referenceType
            );
            if(isPcRelative) emit(
                Node(loc, Opcode.AddUpperImmediateToPC, rd, 0, 0, high)
            );
            else if(high) emit(
                Node(loc, Opcode.LoadUpperImmediate, rd, 0, 0, high)
            );
        }
        void emitSameSrcDstStatus() {
            this.addStatus(
                node.location,
                Status.PseudoInstructionBadSrcDstRegisterArgs,
                node.getName()
            );
        }
        if(pseudoType is PseudoType.NoOperation) {
            emit(Node(loc, Opcode.Add, 0, 0, 0));
        }
        else if(pseudoType is PseudoType.CopyRegister) {
            emit(Node(loc, Opcode.Add, rd, rs1, 0));
        }
        else if(pseudoType is PseudoType.Not) {
            emit(Node(loc, Opcode.XorImmediate, rd, rs1, 0, Number(-1)));
        }
        else if(pseudoType is PseudoType.Negate) {
            emit(Node(loc, Opcode.Subtract, rd, 0, rs1));
        }
        else if(pseudoType is PseudoType.Nand) {
            emit(Node(loc, Opcode.And, rd, rs1, rs2));
            emit(Node(loc, Opcode.XorImmediate, rd, rd, 0, Number(-1)));
        }
        else if(pseudoType is PseudoType.Nor) {
            emit(Node(loc, Opcode.Or, rd, rs1, rs2));
            emit(Node(loc, Opcode.XorImmediate, rd, rd, 0, Number(-1)));
        }
        else if(pseudoType is PseudoType.Xnor) {
            emit(Node(loc, Opcode.Xor, rd, rs1, rs2));
            emit(Node(loc, Opcode.XorImmediate, rd, rd, 0, Number(-1)));
        }
        else if(pseudoType is PseudoType.NandImmediate) {
            emit(Node(loc, Opcode.AndImmediate, rd, rs1, 0, immediate));
            emit(Node(loc, Opcode.XorImmediate, rd, rd, 0, Number(-1)));
        }
        else if(pseudoType is PseudoType.NorImmediate) {
            emit(Node(loc, Opcode.OrImmediate, rd, rs1, 0, immediate));
            emit(Node(loc, Opcode.XorImmediate, rd, rd, 0, Number(-1)));
        }
        else if(pseudoType is PseudoType.XnorImmediate) {
            emit(Node(loc, Opcode.XorImmediate, rd, rs1, 0, immediate));
            emit(Node(loc, Opcode.XorImmediate, rd, rd, 0, Number(-1)));
        }
        else if(pseudoType is PseudoType.AndNot) {
            emit(Node(loc, Opcode.XorImmediate, rd, rs2, 0, Number(-1)));
            emit(Node(loc, Opcode.And, rd, rs1, rd));
        }
        else if(pseudoType is PseudoType.OrNot) {
            emit(Node(loc, Opcode.XorImmediate, rd, rs2, 0, Number(-1)));
            emit(Node(loc, Opcode.Or, rd, rs1, rd));
        }
        else if(pseudoType is PseudoType.XorNot) {
            emit(Node(loc, Opcode.XorImmediate, rd, rs2, 0, Number(-1)));
            emit(Node(loc, Opcode.Xor, rd, rs1, rd));
        }
        else if(pseudoType is PseudoType.ShiftLeftLogicalImmediate) {
            emit(Node(loc, Opcode.ShiftLeftLogical, rd, rs1, 0, immediate));
        }
        else if(pseudoType is PseudoType.ShiftRightLogicalImmediate) {
            emit(Node(loc, Opcode.ShiftRightLogical, rd, rs1, 0, immediate));
        }
        else if(pseudoType is PseudoType.ShiftRightArithmeticImmediate) {
            emit(Node(loc, Opcode.ShiftRightArithmetic, rd, rs1, 0, immediate));
        }
        else if(pseudoType is PseudoType.AddImmediate) {
            emit(Node(loc, Opcode.Add, rd, rs1, 0, immediate));
        }
        else if(pseudoType is PseudoType.AddWordImmediate) {
            if(rd == rs1) emitSameSrcDstStatus();
            const values = this.getNumberHalves(immediate);
            const rdz = values.high ? rd : 0;
            emitHighHalf(values.high);
            if(rs1 || values.low || !values.high) {
                emit(Node(loc, Opcode.Add, rd, rs1, rdz, values.low));
            }
        }
        else if(pseudoType is PseudoType.AndWordImmediate) {
            if(rd == rs1) emitSameSrcDstStatus();
            const values = this.getNumberHalves(immediate);
            const addrdz = values.high ? rd : 0;
            const endrdz = (values.low || values.high) ? rd : 0;
            emitHighHalf(values.high);
            if(values.low) {
                emit(Node(loc, Opcode.Add, rd, addrdz, 0, values.low));
            }
            emit(Node(loc, Opcode.And, rd, rs1, endrdz));
        }
        else if(pseudoType is PseudoType.OrWordImmediate) {
            if(rd == rs1) emitSameSrcDstStatus();
            const values = this.getNumberHalves(immediate);
            const addrdz = values.high ? rd : 0;
            const endrdz = (values.low || values.high) ? rd : 0;
            emitHighHalf(values.high);
            if(values.low) {
                emit(Node(loc, Opcode.Add, rd, addrdz, 0, values.low));
            }
            emit(Node(loc, Opcode.Or, rd, rs1, endrdz));
        }
        else if(pseudoType is PseudoType.XorWordImmediate) {
            if(rd == rs1) emitSameSrcDstStatus();
            const values = this.getNumberHalves(immediate);
            const addrdz = values.high ? rd : 0;
            const endrdz = (values.low || values.high) ? rd : 0;
            emitHighHalf(values.high);
            if(values.low) {
                emit(Node(loc, Opcode.Add, rd, addrdz, 0, values.low));
            }
            emit(Node(loc, Opcode.Xor, rd, rs1, endrdz));
        }
        else if(pseudoType is PseudoType.SetLessThanWordImmediateSigned) {
            if(rd == rs1) emitSameSrcDstStatus();
            const values = this.getNumberHalves(immediate);
            const addrdz = values.high ? rd : 0;
            const endrdz = (values.low || values.high) ? rd : 0;
            emitHighHalf(values.high);
            if(values.low) {
                emit(Node(loc, Opcode.Add, rd, addrdz, 0, values.low));
            }
            emit(Node(loc, Opcode.SetLessThanSigned, rd, rs1, endrdz));
        }
        else if(pseudoType is PseudoType.SetLessThanWordImmediateUnsigned) {
            if(rd == rs1) emitSameSrcDstStatus();
            const values = this.getNumberHalves(immediate);
            const rdz = values.high ? rd : 0;
            emitHighHalf(values.high);
            if(values.low) {
                emit(Node(loc, Opcode.Add, rd, rdz, 0, values.low));
            }
            emit(Node(loc, Opcode.SetLessThanUnsigned, rd, rs1, rd));
        }
        else if(pseudoType is PseudoType.CountLeadingOnes) {
            emit(Node(loc, Opcode.XorImmediate, rd, rs1, 0, Number(-1)));
            emit(Node(loc, Opcode.CountLeadingZeroes, rd, rd, 0));
        }
        else if(pseudoType is PseudoType.CountTrailingOnes) {
            emit(Node(loc, Opcode.XorImmediate, rd, rs1, 0, Number(-1)));
            emit(Node(loc, Opcode.CountTrailingZeroes, rd, rd, 0));
        }
        else if(pseudoType is PseudoType.SetEqualZero) {
            emit(Node(loc, Opcode.SetLessThanImmediateUnsigned, rd, rs1, 0, Number(1)));
        }
        else if(pseudoType is PseudoType.SetNotEqualZero) {
            emit(Node(loc, Opcode.SetLessThanUnsigned, rd, 0, rs1));
        }
        else if(pseudoType is PseudoType.SetLessZero) {
            emit(Node(loc, Opcode.SetLessThanSigned, rd, rs1, 0));
        }
        else if(pseudoType is PseudoType.SetGreaterZero) {
            emit(Node(loc, Opcode.SetLessThanSigned, rd, 0, rs1));
        }
        else if(pseudoType is PseudoType.SetLessEqualZero) {
            emit(Node(loc, Opcode.SetLessThanImmediateSigned, rd, rs1, 0, Number(1)));
        }
        else if(pseudoType is PseudoType.SetGreaterEqualZero) {
            emit(Node(loc, Opcode.SetLessThanSigned, rd, rs1, 0));
            emit(Node(loc, Opcode.SetLessThanImmediateUnsigned, rd, rd, 0, Number(1)));
        }
        else if(pseudoType is PseudoType.LoadImmediate) {
            const values = this.getNumberHalves(immediate);
            const rdz = values.high ? rd : 0;
            emitHighHalf(values.high);
            if(values.low || !values.high) {
                emit(Node(loc, Opcode.Add, rd, rdz, 0, values.low));
            }
        }
        else if(pseudoType is PseudoType.LoadAddress) {
            const values = this.getNumberHalves(immediate);
            const rdz = values.high ? rd : 0;
            emitHighHalf(values.high);
            if(values.low || !values.high) {
                emit(Node(loc, Opcode.Add, rd, rdz, 0, values.low));
            }
        }
        else if(pseudoType is PseudoType.LoadByteSignExt) {
            const values = this.getNumberHalves(immediate);
            const rdz = values.high ? rd : 0;
            emitHighHalf(values.high);
            emit(Node(loc, Opcode.LoadByteSignExt, rd, rdz, 0, values.low));
        }
        else if(pseudoType is PseudoType.LoadByteZeroExt) {
            const values = this.getNumberHalves(immediate);
            const rdz = values.high ? rd : 0;
            emitHighHalf(values.high);
            emit(Node(loc, Opcode.LoadByteZeroExt, rd, rdz, 0, values.low));
        }
        else if(pseudoType is PseudoType.LoadHalfWordSignExt) {
            const values = this.getNumberHalves(immediate);
            const rdz = values.high ? rd : 0;
            emitHighHalf(values.high);
            emit(Node(loc, Opcode.LoadHalfWordSignExt, rd, rdz, 0, values.low));
        }
        else if(pseudoType is PseudoType.LoadHalfWordZeroExt) {
            const values = this.getNumberHalves(immediate);
            const rdz = values.high ? rd : 0;
            emitHighHalf(values.high);
            emit(Node(loc, Opcode.LoadHalfWordZeroExt, rd, rdz, 0, values.low));
        }
        else if(pseudoType is PseudoType.LoadWord) {
            const values = this.getNumberHalves(immediate);
            const rdz = values.high ? rd : 0;
            emitHighHalf(values.high);
            emit(Node(loc, Opcode.LoadWord, rd, rdz, 0, values.low));
        }
        else if(pseudoType is PseudoType.StoreByte) {
            if(rd == rs1) emitSameSrcDstStatus();
            const values = this.getNumberHalves(immediate);
            const rdz = values.high ? rd : 0;
            emitHighHalf(values.high);
            emit(Node(loc, Opcode.StoreByte, 0, rs1, rdz, values.low));
        }
        else if(pseudoType is PseudoType.StoreHalfWord) {
            if(rd == rs1) emitSameSrcDstStatus();
            const values = this.getNumberHalves(immediate);
            const rdz = values.high ? rd : 0;
            emitHighHalf(values.high);
            emit(Node(loc, Opcode.StoreHalfWord, 0, rs1, rdz, values.low));
        }
        else if(pseudoType is PseudoType.StoreWord) {
            if(rd == rs1) emitSameSrcDstStatus();
            const values = this.getNumberHalves(immediate);
            const rdz = values.high ? rd : 0;
            emitHighHalf(values.high);
            emit(Node(loc, Opcode.StoreWord, 0, rs1, rdz, values.low));
        }
        else if(pseudoType is PseudoType.BranchEqualZero) {
            emit(Node(loc, Opcode.BranchEqual, 0, rs1, 0, immediate));
        }
        else if(pseudoType is PseudoType.SetEqual) {
            emit(Node(loc, Opcode.Subtract, rd, rs1, rs2, immediate));
            emit(Node(loc, Opcode.SetLessThanImmediateUnsigned, rd, rd, 0, Number(1)));
        }
        else if(pseudoType is PseudoType.SetNotEqual) {
            emit(Node(loc, Opcode.Subtract, rd, rs1, rs2, immediate));
            emit(Node(loc, Opcode.SetLessThanUnsigned, rd, 0, rd, Number(1)));
        }
        else if(pseudoType is PseudoType.SetGreaterEqualSigned) {
            emit(Node(loc, Opcode.SetLessThanSigned, rd, rs1, rs2, immediate));
            emit(Node(loc, Opcode.XorImmediate, rd, rd, 0, Number(1)));
        }
        else if(pseudoType is PseudoType.SetGreaterEqualUnsigned) {
            emit(Node(loc, Opcode.SetLessThanUnsigned, rd, rs1, rs2, immediate));
            emit(Node(loc, Opcode.XorImmediate, rd, rd, 0, Number(1)));
        }
        else if(pseudoType is PseudoType.SetGreaterSigned) {
            emit(Node(loc, Opcode.SetLessThanSigned, rd, rs2, rs1, immediate));
        }
        else if(pseudoType is PseudoType.SetGreaterUnsigned) {
            emit(Node(loc, Opcode.SetLessThanUnsigned, rd, rs2, rs1, immediate));
        }
        else if(pseudoType is PseudoType.SetLessEqualSigned) {
            emit(Node(loc, Opcode.SetLessThanSigned, rd, rs2, rs1, immediate));
            emit(Node(loc, Opcode.XorImmediate, rd, rd, 0, Number(1)));
        }
        else if(pseudoType is PseudoType.SetLessEqualUnsigned) {
            emit(Node(loc, Opcode.SetLessThanUnsigned, rd, rs2, rs1, immediate));
            emit(Node(loc, Opcode.XorImmediate, rd, rd, 0, Number(1)));
        }
        else if(pseudoType is PseudoType.BranchNotEqualZero) {
            emit(Node(loc, Opcode.BranchNotEqual, 0, rs1, 0, immediate));
        }
        else if(pseudoType is PseudoType.BranchLessEqualZero) {
            emit(Node(loc, Opcode.BranchGreaterEqualSigned, 0, 0, rs1, immediate));
        }
        else if(pseudoType is PseudoType.BranchGreaterEqualZero) {
            emit(Node(loc, Opcode.BranchGreaterEqualSigned, 0, rs1, 0, immediate));
        }
        else if(pseudoType is PseudoType.BranchLessZero) {
            emit(Node(loc, Opcode.BranchLessSigned, 0, rs1, 0, immediate));
        }
        else if(pseudoType is PseudoType.BranchGreaterZero) {
            emit(Node(loc, Opcode.BranchLessSigned, 0, 0, rs1, immediate));
        }
        else if(pseudoType is PseudoType.BranchGreaterSigned) {
            emit(Node(loc, Opcode.BranchLessSigned, 0, rs2, rs1, immediate));
        }
        else if(pseudoType is PseudoType.BranchLessEqualSigned) {
            emit(Node(loc, Opcode.BranchGreaterEqualSigned, 0, rs2, rs1, immediate));
        }
        else if(pseudoType is PseudoType.BranchGreaterUnsigned) {
            emit(Node(loc, Opcode.BranchLessUnsigned, 0, rs2, rs1, immediate));
        }
        else if(pseudoType is PseudoType.BranchLessEqualUnsigned) {
            emit(Node(loc, Opcode.BranchGreaterEqualUnsigned, 0, rs2, rs1, immediate));
        }
        else if(pseudoType is PseudoType.Jump) {
            emit(Node(loc, Opcode.JumpAndLink, 0, 0, 0, immediate));
        }
        else if(pseudoType is PseudoType.JumpRegister) {
            emit(Node(loc, Opcode.JumpAndLinkRegister, 0, rs1, 0, immediate));
        }
        else if(pseudoType is PseudoType.Call) {
            const values = this.getNumberHalves(immediate);
            const rdz = values.high ? rd : 0;
            emitHighHalf(values.high);
            emit(Node(loc, Opcode.JumpAndLinkRegister, rd, rdz, 0, values.low));
        }
        else if(pseudoType is PseudoType.Return) {
            emit(Node(loc, Opcode.JumpAndLinkRegister, 0, rs1, 0, immediate));
        }
        else if(pseudoType is PseudoType.ExtensionCallImmediate) {
            const values = this.getNumberHalves(immediate);
            const rdz = values.high ? rd : 0;
            if(values.high) this.addStatus(
                node.location,
                Status.PseudoInstructionBadDstRegisterArgs,
                node.getName()
            );
            emitHighHalf(values.high);
            emit(Node(loc, Opcode.ExtensionCall, rd, rs1, rdz, values.low));
        }
        // Shouldn't happen. Would imply an inconsistency between the parser
        // and the compiler implementation.
        else {
            this.addStatus(node.location, Status.InvalidInstruction, node.getName());
        }
    }
    
    /// Used to determine how a single potentially word-size number value
    /// should be spread across the immediate values of two instructions.
    auto getNumberHalves(in Node.Number number) {
        // Helpful types and aliases
        alias Number = Node.Number;
        struct Result {
            Number low = Number.init;
            Number high = Number.init;
        }
        // Helper function to get the two halves of a constant value
        Result getConstantHalves(in typeof(number.value) value) {
            if(number.value == cast(short) number.value) {
                return Result(number);
            }
            else {
                const short low = cast(short) number.value;
                const short high = cast(short) (
                    (cast(short) (number.value >> 16)) + ((low >> 15) & 1)
                );
                assert((cast(int) high << 16) + low == cast(int) number.value);
                return Result(Number(low), Number(high));
            }
        }
        // Number is a constant literal value?
        if(!number.name.length) {
            return getConstantHalves(number.value);
        }
        // Number refers to a global whose value is already known to the compiler?
        else if(const global = number.name in this.globalMap) {
            if(global.type is Global.Type.Constant) {
                return getConstantHalves(global.value);
            }
        }
        // Number is a word-size absolute reference?
        if(number.referenceType is Reference.Type.AbsoluteWord) {
            return Result(
                number.withReferenceType(Reference.Type.AbsoluteWordLowHalf),
                number.withReferenceType(Reference.Type.AbsoluteWordHighHalf),
            );
        }
        if(number.referenceType is Reference.Type.LengthWord) {
            return Result(
                number.withReferenceType(Reference.Type.LengthWordLowHalf),
                number.withReferenceType(Reference.Type.LengthWordHighHalf),
            );
        }
        // Number is a word-size PC-relative reference?
        else if(number.referenceType is Reference.Type.PCRelativeAddressWord) {
            return Result(
                number.withReferenceType(Reference.Type.PCRelativeAddressNearLowHalf),
                number.withReferenceType(Reference.Type.PCRelativeAddressHighHalf),
            );
        }
        else if(number.referenceType is Reference.Type.EndPCRelativeAddressWord) {
            return Result(
                number.withReferenceType(Reference.Type.EndPCRelativeAddressNearLowHalf),
                number.withReferenceType(Reference.Type.EndPCRelativeAddressHighHalf),
            );
        }
        // Otherwise, the number should already fit into a single half word
        version(assert) {
            const refLength = Object.Reference.typeLength(number.referenceType);
            const refOffset = Object.Reference.typeOffset(number.referenceType);
            assert(refLength <= 2 && refLength + refOffset <= 4);
        }
        // All done
        return Result(number);
    }
    
    /// Get the constant represented by a number value, if possible.
    /// Note: References to compiler-defined constants should be handled here.
    auto tryResolveNumberValue(in Node.Number number) {
        struct Result {
            static enum CannotWrite = typeof(this)(Status.Ok, false, 0);
            
            Status status = Status.Ok;
            bool canWrite = false;
            uint writeValue = 0;
            
            static auto Ok(in uint value) {
                return typeof(this)(Status.Ok, true, value);
            }
            
            bool ok() const {
                return this.status is Status.Ok;
            }
        }
        if(!number.name.length || !number.referenceType) {
            return Result.Ok(cast(uint) number.value);
        }
        else if(number.isPcRelativeReference) {
            return Result.CannotWrite;
        }
        // Number refers to a global whose value is already known to the compiler?
        else if(const global = number.name in this.globalMap) {
            if(global.type is Global.Type.Constant) {
                const resolveValue = resolveCapsuleObjectReferenceValue(
                    number.referenceType, 0, number.addend,
                    global.value, global.length,
                );
                if(resolveValue.ok) {
                    return Result.Ok(resolveValue.writeValue);
                }
                else {
                    return Result(resolveValue.status);
                }
            }
        }
        return Result.CannotWrite;
    }
    
    /// Used by directives such as .byte, .half, .word, .resb, .string
    /// If the directive was immediately preceded by a label then that
    /// label is automagically retroactively marked as a variable with
    /// an appropriate length value.
    bool setLabelVariableLength(in uint length) {
        auto section = this.currentSection;
        assert(section);
        if(section && section.labels.length &&
            section.labels[$ - 1].type is Symbol.Type.Label &&
            section.labels[$ - 1].offset == this.byteOffset
        ) {
            section.labels[$ - 1].type = Symbol.Type.Variable;
            section.labels[$ - 1].length = length;
            return true;
        }
        return false;
    }
    
    void compileDirective(in Node node) {
        assert(node.isDirective);
        const type = node.directiveType;
        this.addStatus(
            node.location, Status.CompileDirective, node.getName()
        );
        // .align
        if(type is DirectiveType.Align) {
            this.compileAlignDirective(node);
        }
        // .bss
        else if(type is DirectiveType.BSS) {
            this.addSection(node.location, Section.Type.BSS);
        }
        // .byte
        else if(type is DirectiveType.Byte) {
            this.compileByteDataDirective!ubyte(node);
        }
        // .comment
        else if(type is DirectiveType.Comment) {
            this.comment ~= node.textDirective.text;
        }
        // .const
        else if(type is DirectiveType.Constant) {
            Constant constant = {
                location: node.location,
                visibility: Visibility.Global,
                name: node.constDirective.name,
                value: node.constDirective.value,
                section: this.currentSectionIndex,
            };
            this.constants ~= constant;
            this.addStatus(
                node.location,
                Status.CompileConstantDirective,
                node.constDirective.name
            );
        }
        // .data
        else if(type is DirectiveType.Data) {
            this.addSection(node.location, Section.Type.Data);
        }
        // .endproc
        else if(type is DirectiveType.EndProcedure) {
            this.compileEndProcedureDirective(node);
        }
        // .entry
        else if(type is DirectiveType.Entry) {
            auto section = this.requireInitializedSection(node.location);
            if(!section) return;
            if(this.entryExplicit) {
                this.addStatus(node.location, Status.MultipleEntryPoints);
                return;
            }
            else {
                this.entryExplicit = true;
                this.entrySectionIndex = this.currentSectionIndex;
                this.entryOffset = this.byteOffset;
            }
        }
        // .export
        else if(type is DirectiveType.Export) {
            this.addExport(Export(node.location, node.symbolDirective.name));
            this.addStatus(
                node.location,
                Status.CompileExportDirective,
                node.symbolDirective.name
            );
        }
        // .extern
        else if(type is DirectiveType.Extern) {
            this.externs ~= Extern(node.location, node.symbolDirective.name);
            this.addStatus(
                node.location,
                Status.CompileExternDirective,
                node.symbolDirective.name
            );
        }
        // .half
        else if(type is DirectiveType.HalfWord) {
            this.compileByteDataDirective!ushort(node);
        }
        // .incbin
        else if(type is DirectiveType.IncludeBinary) {
            this.compileIncludeDirective(node);
        }
        // .include
        else if(type is DirectiveType.IncludeSource) {
            this.compileIncludeDirective(node);
        }
        // .padb
        else if(type is DirectiveType.PadBytes) {
            auto section = this.requireInitializedSection(node.location);
            if(!section) return;
            const fill = cast(ubyte) node.padDirective.fill;
            if(!node.padDirective.size) this.addStatus(
                node.location, Status.DirectivePadZeroUnits, node.getName()
            );
            this.setLabelVariableLength(node.padDirective.size);
            section.reserveBytes(node.location, node.padDirective.size, fill);
        }
        // .padh
        else if(type is DirectiveType.PadHalfWords) {
            auto section = this.requireInitializedSection(node.location);
            if(!section) return;
            const fill = cast(ushort) node.padDirective.fill;
            if(section.length % 2 != 0) this.addStatus(
                node.location, Status.MisalignedHalfWord, node.getName()
            );
            if(!node.padDirective.size) this.addStatus(
                node.location, Status.DirectivePadZeroUnits, node.getName()
            );
            this.setLabelVariableLength(2 * node.padDirective.size);
            section.reserveHalfWords(node.location, node.padDirective.size, fill);
        }
        // .padw
        else if(type is DirectiveType.PadWords) {
            auto section = this.requireInitializedSection(node.location);
            if(!section) return;
            const fill = cast(uint) node.padDirective.fill;
            if(section.length % 4 != 0) this.addStatus(
                node.location, Status.MisalignedWord, node.getName()
            );
            if(!node.padDirective.size) this.addStatus(
                node.location, Status.DirectivePadZeroUnits, node.getName()
            );
            this.setLabelVariableLength(4 * node.padDirective.size);
            section.reserveWords(node.location, node.padDirective.size, fill);
        }
        // .priority
        else if(type is DirectiveType.Priority) {
            auto section = this.requireDeclaredSection(node.location);
            if(!section) return;
            if(section.hasPriority) this.addStatus(
                node.location, Status.MultipleSectionPriorities
            );
            section.priority = node.intDirective.value;
            section.hasPriority = true;
        }
        // .procedure
        else if(type is DirectiveType.Procedure) {
            auto section = this.requireInitializedSection(node.location);
            if(!section) return;
            if(section.definitionTypeNode) this.addStatus(
                node.location,
                Status.MultipleConsecutiveDefinitionTypeDirectives,
                node.getName()
            );
            section.definitionTypeNode = node;
        }
        // .resb
        else if(type is DirectiveType.ReserveBytes) {
            auto section = this.requireDeclaredSection(node.location);
            if(!section) return;
            if(!node.padDirective.size) this.addStatus(
                node.location, Status.DirectiveReserveZeroUnits, node.getName()
            );
            this.setLabelVariableLength(node.padDirective.size);
            section.reserveBytes(node.location, node.padDirective.size);
        }
        // .resh
        else if(type is DirectiveType.ReserveHalfWords) {
            auto section = this.requireDeclaredSection(node.location);
            if(!section) return;
            if(section.length % 2 != 0) this.addStatus(
                node.location, Status.MisalignedHalfWord, node.getName()
            );
            if(!node.padDirective.size) this.addStatus(
                node.location, Status.DirectiveReserveZeroUnits, node.getName()
            );
            this.setLabelVariableLength(2 * node.padDirective.size);
            section.reserveHalfWords(node.location, node.padDirective.size);
        }
        // .resw
        else if(type is DirectiveType.ReserveWords) {
            auto section = this.requireDeclaredSection(node.location);
            if(!section) return;
            if(section.length % 4 != 0) this.addStatus(
                node.location, Status.MisalignedWord, node.getName()
            );
            if(!node.padDirective.size) this.addStatus(
                node.location, Status.DirectiveReserveZeroUnits, node.getName()
            );
            this.setLabelVariableLength(4 * node.padDirective.size);
            section.reserveWords(node.location, node.padDirective.size);
        }
        // .rodata
        else if(type is DirectiveType.ReadOnlyData) {
            this.addSection(node.location, Section.Type.ReadOnlyData);
        }
        // .string
        else if(type is DirectiveType.String) {
            auto section = this.requireInitializedSection(node.location);
            if(!section) return;
            if(section.type is Section.Type.Text) this.addStatus(
                node.location,
                Status.DataInExecutableSection,
                getEnumMemberAttribute!string(section.type)
            );
            this.setLabelVariableLength(
                cast(uint) node.textDirective.text.length
            );
            section.addBytes(node.location, node.textDirective.text);
        }
        // .stringz
        else if(type is DirectiveType.StringZ) {
            auto section = this.requireInitializedSection(node.location);
            if(!section) return;
            if(section.type is Section.Type.Text) this.addStatus(
                node.location,
                Status.DataInExecutableSection,
                getEnumMemberAttribute!string(section.type)
            );
            this.setLabelVariableLength(
                cast(uint) (1 + node.textDirective.text.length)
            );
            section.addBytes(node.location, node.textDirective.text ~ "\0");
        }
        // .text
        else if(type is DirectiveType.Text) {
            this.addSection(node.location, Section.Type.Text);
        }
        // .word
        else if(type is DirectiveType.Word) {
            this.compileByteDataDirective!uint(node);
        }
        // Shouldn't happen. Would imply an inconsistency between the parser
        // and the compiler implementation.
        else {
            this.addStatus(node.location, Status.InvalidDirective, node.getName());
        }
    }
    
    void compileAlignDirective(in Node node) {
        assert(node.directiveType is DirectiveType.Align);
        const size = node.padDirective.size;
        const fill = cast(ubyte) node.padDirective.fill;
        // Make sure a section has been declared
        auto section = this.requireDeclaredSection(node.location);
        if(!section) return;
        // Nonzero fill not allowed in uninitialized sections (e.g. bss)
        if(!section.isInitialized && fill != 0) {
            this.addStatus(node.location, Status.DataInUninitializedSection);
            return;
        }
        // Emit a message for non-power-of-two alignment values
        else if(!isPow2(size)) {
            this.addStatus(node.location, Status.AlignmentNotPowTwo);
        }
        // Find the LCM of the old and new alignments
        const prevAlignment = section.alignment;
        section.alignment = (section.length ?
            lcm(prevAlignment, size) : size
        );
        // Emit a message if the new alignment exceeds a threshold
        if((section.length && section.alignment < prevAlignment) ||
            section.alignment > MaxAcceptableAlignment ||
            size > MaxAcceptableAlignment
        ) {
            this.addStatus(node.location, Status.LargeAlignment);
        }
        // Reserve the needed number of bytes in the section to
        // align the following data on the specified boundarys
        const padding = size - (this.byteOffset % size);
        if(padding && padding < size) {
            section.reserveBytes(node.location, cast(uint) padding, fill);
        }
    }
    
    void compileEndProcedureDirective(in Node node) {
        assert(node.directiveType is DirectiveType.EndProcedure);
        // Make sure a section has been declared
        auto section = this.requireDeclaredSection(node.location);
        if(!section) return;
        // Find the corresponding label for the .endproc directive
        const name = node.symbolDirective.name;
        for(size_t i = section.labels.length; i > 0; i--) {
            if(section.labels[i - 1].name == name) {
                assert(section.labels[i - 1].offset <= this.byteOffset);
                if(section.labels[i - 1].type !is Symbol.Type.Procedure) {
                    this.addStatus(
                        node.location,
                        Status.InvalidCompileEndProcedureName,
                        name
                    );
                    return;
                }
                section.labels[i - 1].length = (
                    this.byteOffset - section.labels[i - 1].offset
                );
                this.addStatus(
                    node.location, Status.CompileEndProcedureDirective, name
                );
                return;
            }
        }
        // If execution reached this point, no corresponding label was found
        this.addStatus(
            node.location, Status.InvalidCompileEndProcedureName, name
        );
    }
    
    void compileByteDataDirective(T)(in Node node) {
        static if(T.sizeof == 1) assert(node.directiveType is DirectiveType.Byte);
        static if(T.sizeof == 2) assert(node.directiveType is DirectiveType.HalfWord);
        static if(T.sizeof == 4) assert(node.directiveType is DirectiveType.Word);
        auto section = this.requireInitializedSection(node.location);
        if(!section) return;
        if(section.type is Section.Type.Text) this.addStatus(
            node.location,
            Status.DataInExecutableSection,
            getEnumMemberAttribute!string(section.type)
        );
        static if(T.sizeof == 2) {
            if(section.length % 2 != 0) this.addStatus(
                node.location, Status.MisalignedHalfWord, node.getName()
            );
        }
        static if(T.sizeof == 4) {
            if(section.length % 4 != 0) this.addStatus(
                node.location, Status.MisalignedWord, node.getName()
            );
        }
        this.setLabelVariableLength(
            cast(uint) node.byteDataDirective.values.length
        );
        foreach(number; node.byteDataDirective.values) {
            const resolveValue = this.tryResolveNumberValue(number);
            if(!resolveValue.ok) this.addStatus(
                node.location, resolveValue.status, number.name
            );
            if(!resolveValue.canWrite) this.addReference(
                section, node.location, number, section.length,
                T.sizeof, T.sizeof, false
            );
            // Write the number's value to the section
            //const uint offset = section.length;
            static if(T.sizeof == 1) {
                section.addByte(node.location, cast(ubyte) resolveValue.writeValue);
            }
            else static if(T.sizeof == 2) {
                section.addHalfWord(node.location, cast(ushort) resolveValue.writeValue);
            }
            else static if(T.sizeof == 4) {
                section.addWord(node.location, cast(uint) resolveValue.writeValue);
            }
            else {
                static assert(false, "Unhandled data type: " ~ T.stringof);
            }
        }
    }
    
    void compileSymbolVisibilityDirective(
        in Node node, in CapsuleObject.Symbol.Visibility visibility
    ) {
        assert(
            node.directiveType is DirectiveType.Export ||
            node.directiveType is DirectiveType.Extern
        );
        if(!node.symbolDirective.name.length) {
            this.addStatus(node.location, Status.InvalidDirective);
            return;
        }
        auto section = this.currentSection();
        assert(section !is null);
        Symbol symbol = {
            location: node.location,
            type: Symbol.Type.Undefined,
            visibility: visibility,
            name: node.symbolDirective.name,
        };
        section.symbols ~= symbol;
    }
    
    /// Helper function to resolve a path and load a file given by an
    /// .incbin or .include directive.
    File getIncludedFile(in string path, in string relativeToFile = null) {
        if(Path(path).isAbsolute) {
            return File.read(path);
        }
        else if(relativeToFile.length) {
            const sourceDirPath = Path(relativeToFile).dirName();
            const relHere = Path(path).relativeTo(sourceDirPath);
            const file = File.read(relHere.toString());
            if(file.ok) {
                return file;
            }
        }
        foreach(includePath; this.includePaths) {
            const relInclude = Path(path).relativeTo(includePath);
            const file = File.read(relInclude.toString());
            if(file.ok) {
                return file;
            }
        }
        return File.init;
    }
    
    /// Process a node representing an .incbin or .include directive.
    void compileIncludeDirective(in Node node) {
        assert(
            node.directiveType is DirectiveType.IncludeBinary ||
            node.directiveType is DirectiveType.IncludeSource
        );
        const includePath = node.textDirective.text;
        auto file = this.getIncludedFile(includePath, node.location.file.path);
        if(file.status is File.Status.ReadError) {
            this.addStatus(node.location, Status.FilePathReadError, file.path);
            return;
        }
        else if(!file.ok) {
            this.addStatus(node.location, Status.FilePathResolutionError, includePath);
            return;
        }
        if(node.directiveType is DirectiveType.IncludeBinary) {
            this.compileIncludeBinaryDirective(node, file);
        }
        else {
            this.compileIncludeSourceDirective(node, file);
        }
    }
    
    /// Process a node representing an .incbin directive.
    void compileIncludeBinaryDirective(in Node node, ref File file) {
        assert(node.directiveType is DirectiveType.IncludeBinary);
        this.addStatus(node.location, Status.CompileIncludeBinary, file.path);
        auto section = this.requireInitializedSection(node.location);
        if(!section) return;
        this.setLabelVariableLength(cast(uint) file.content.length);
        section.addBytes(node.location, file.content);
    }

    /// Process a node representing an .include directive.
    void compileIncludeSourceDirective(in Node node, ref File file) {
        assert(node.directiveType is DirectiveType.IncludeSource);
        assert(this.nodeIndex < this.nodes.length);
        assert(this.log);
        this.addStatus(node.location, Status.CompileIncludeSource, file.path);
        this.addStatus(FileLocation(file), Status.CompileParseSourceFile);
        if(node.includeDepth >= MaxAcceptableIncludeDepth) {
            this.addStatus(node.location, Status.IncludeLevelTooDeep, file.path);
            return;
        }
        const source = this.getObjectSource(file);
        if(!this.hasObjectSource(source)) {
            this.objectSources ~= source;
        }
        auto parser = Parser(this.log, file);
        parser.parse();
        foreach(ref parserNode; parser.nodes) {
            parserNode.includeDepth = node.includeDepth + 1;
        }
        if(parser.ok) this.nodes = (
            this.nodes[0 .. 1 + this.nodeIndex] ~
            parser.nodes ~
            this.nodes[1 + this.nodeIndex .. $]
        );
    }
}
