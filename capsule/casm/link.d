module capsule.casm.link;

import capsule.core.ascii : isDigit;
import capsule.core.crc : CRC32;
import capsule.core.encoding : CapsuleArchitecture, CapsuleHashType;
import capsule.core.encoding : CapsuleTextEncoding, CapsuleTimeEncoding;
import capsule.core.enums : getEnumMemberAttribute, getEnumMemberWithAttribute;
import capsule.core.file : File, FileLocation;
import capsule.core.obj : CapsuleObject;
import capsule.core.program : CapsuleProgram;
import capsule.core.sort : sort;
import capsule.core.time : getUnixSeconds;

import capsule.casm.messages : CapsuleAsmMessageStatus, CapsuleAsmMessageMixin;
import capsule.casm.messages : CapsuleAsmMessageStatusSeverity;
import capsule.casm.reference : findCapsuleObjectPcRelHighReference;
import capsule.casm.reference : resolveCapsuleObjectReference;
import capsule.casm.syntax : CapsuleAsmNumberLinkDirectiveType;

private uint getWordAlignedOffset(in uint offset) {
    return offset + ((4 - (offset & 0x3)) & 0x3);
}

public:

struct CapsuleLinkerSegment {
    alias Type = CapsuleProgram.Segment.Type;
    
    uint offset = 0;
    uint length = 0;
    
    uint end() const {
        assert(uint.max - this.length >= this.offset);
        return this.length + this.offset;
    }
}

struct CapsuleLinkerSection {
    alias Type = CapsuleObject.Section.Type;
    
    /// Index of object file defining this section
    uint object;
    /// Index of this section in the defining object file
    uint section;
    /// The type of section
    Type type;
    /// Align on a boundary of this many bytes
    uint alignment;
    /// Influences section sorting. Sections with lower priority numbers
    /// go closer to the beginning of their segment.
    int priority = 0;
    /// Length of the section in bytes
    uint length;
    /// Compiled byte content for this section, for initialized sections
    ubyte[] bytes = null;
    /// Program data byte offset assigned to this section by the linker
    uint offset = 0;
    
    bool opCast(T: bool)() const {
        return this.type !is Type.None;
    }
    
    /// Check whether the section type is for a segment containing
    /// initialized data (data, rodata, text) or uninitialized data (bss).
    bool isInitialized() const {
        return CapsuleObject.Section.typeIsInitialized(this.type);
    }
}

struct CapsuleLinkerSymbol {
    alias Type = CapsuleObject.Symbol.Type;
    alias Visibility = CapsuleObject.Symbol.Visibility;
    
    /// Index of the object file in which
    /// this symbol is defined (not just declared)
    uint object = 0;
    /// Index of the section in which
    /// this symbol is defined (not just declared)
    uint section = 0;
    
    /// The type of information represented by this symbol
    Type type = Type.None;
    /// Export, global, or local?
    /// Externs don't go here
    Visibility visibility = Visibility.None;
    /// String identifying this symbol
    string name = null;
    ///
    uint length = 0;
    /// Value as originally recorded in the object file,
    /// e.g. the local in-section offset of a label definition
    uint localValue = 0;
    /// Final value as resolved by the linker,
    /// for example an address within the complete program data
    uint value = 0;
    
    bool opCast(T: bool)() const {
        return this.type !is Type.None;
    }
    
    bool isAddress() const {
        return CapsuleObject.Symbol.isAddressType(this.type);
    }
    
    bool isDefined() const {
        return CapsuleObject.Symbol.isDefinedType(this.type);
    }
    
    bool isLocal() const {
        return this.name.length && isDigit(this.name[0]);
    }
}

struct CapsuleLinkerReference {
    alias LocalType = CapsuleObject.Reference.LocalType;
    alias Type = CapsuleObject.Reference.Type;
    
    /// Index of the object file in which this reference appears
    uint object = 0;
    /// Index of the section in which this reference appears
    uint section = 0;
    
    Type type;
    LocalType localType;
    string name = null;
    uint offset = 0;
    int addend = 0;
    
    /// Whether the reference has been resolved by the compiler
    bool resolved = false;
    /// Record the value of the referenced symbol
    uint symbolValue = 0;
    /// Record the length of the referenced symbol
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

/// Implements a data structure to help resolve references to symbols.
struct CapsuleLinkerSymbolMap {
    alias LocalType = CapsuleObject.Reference.LocalType;
    alias Symbol = CapsuleLinkerSymbol;
    alias SymbolType = CapsuleObject.Symbol.Type;
    alias Visibility = CapsuleObject.Symbol.Visibility;
    
    /// Map all exported symbols across all objects by name.
    /// exports[name] - exported symbol with a name
    Symbol[string] exports;
    /// Map global symbols by name for each object.
    /// globals[objectIndex][name] - global in an object with a name
    Symbol[string][] globals;
    /// List local symbols by object and by section.
    /// locals[objectIndex][sectionIndex][i] - local in a section at an index
    Symbol[][][] locals;
    /// A list of all indexed symbols, in no particular order.
    Symbol[] list;
    
    void initialize(in CapsuleObject[] objects) {
        assert(objects.length <= uint.max);
        this.globals.length = objects.length;
        this.locals.length = objects.length;
        for(uint objectIndex = 0; objectIndex < objects.length; objectIndex++) {
            this.locals[objectIndex].length = objects[objectIndex].sections.length;
        }
    }
    
    /// Index a new symbol in the map.
    auto addSymbol(Symbol symbol) {
        assert(symbol.object < this.locals.length);
        assert(symbol.object < this.globals.length);
        struct Result {
            bool exportCollision;
            bool globalCollision;
        }
        Result result;
        if(symbol.visibility is Visibility.Export) {
            result.exportCollision = !!(symbol.name in this.exports);
            this.exports[symbol.name] = symbol;
        }
        if(symbol.visibility is Visibility.Global) {
            result.globalCollision = !!(symbol.name in this.globals[symbol.object]);
            this.globals[symbol.object][symbol.name] = symbol;
        }
        if(symbol.visibility is Visibility.Local) {
            assert(symbol.section < this.locals[symbol.object].length);
            this.locals[symbol.object][symbol.section] ~= symbol;
        }
        this.list ~= symbol;
        return result;
    }
    
    /// Find the symbol being referenced by a given name within a given
    /// object file.
    Symbol getGlobalSymbol(in uint objectIndex, in string name) @trusted {
        assert(objectIndex < this.globals.length);
        if(auto globalSymbol = name in this.globals[objectIndex]) {
            return *globalSymbol;
        }
        else if(auto exportSymbol = name in this.exports) {
            return *exportSymbol;
        }
        else {
            return Symbol.init;
        }
    }
    
    Symbol getLocalSymbol(
        in uint objectIndex, in uint sectionIndex, in uint offset,
        in string name, in LocalType localType
    ) {
        assert(localType);
        assert(objectIndex < this.locals.length);
        assert(sectionIndex < this.locals[objectIndex].length);
        auto localSymbols = this.locals[objectIndex][sectionIndex];
        uint closestIndex = cast(uint) localSymbols.length;
        uint closestOffset = uint.max;
        for(uint i = 0; i < localSymbols.length; i++) {
            const symbol = localSymbols[i];
            if(localType is LocalType.Backward &&
                symbol.localValue <= offset &&
                offset - symbol.localValue < closestOffset &&
                symbol.name == name
            ) {
                closestIndex = i;
                closestOffset = offset - symbol.localValue;
            }
            else if(localType is LocalType.Forward &&
                symbol.localValue > offset &&
                symbol.localValue - offset < closestOffset &&
                symbol.name == name
            ) {
                closestIndex = i;
                closestOffset = offset - symbol.localValue;
            }
        }
        if(closestIndex < localSymbols.length) {
            return localSymbols[closestIndex];
        }
        else {
            return Symbol.init;
        }
    }
}

struct CapsuleLinker {
    mixin CapsuleAsmMessageMixin;
    
    alias Architecture = CapsuleArchitecture;
    alias LocalType = CapsuleObject.Reference.LocalType;
    alias Object = CapsuleObject;
    alias Program = CapsuleProgram;
    alias Reference = CapsuleLinkerReference;
    alias Section = CapsuleLinkerSection;
    alias Segment = CapsuleLinkerSegment;
    alias Source = CapsuleProgram.Source;
    alias Symbol = CapsuleLinkerSymbol;
    alias SymbolMap = CapsuleLinkerSymbolMap;
    alias SymbolType = CapsuleObject.Symbol.Type;
    alias TextEncoding = CapsuleTextEncoding;
    alias TimeEncoding = CapsuleTimeEncoding;
    alias Visibility = CapsuleObject.Symbol.Visibility;
    
    /// The object files being linked
    Object[] objects;
    /// To be used to store a list of sorted and ordered sections
    Section[] sections;
    /// Map sections first by object file index
    /// then section index within that file
    Section[][] sectionMap;
    /// A data structure for indexing symbol definitions across
    /// all the inputted object files
    SymbolMap symbolMap;
    /// A list of references in all object files, enriched with
    /// linker-specific data
    Reference[] references;
    /// Program entry point address, value to be resolved during
    /// the linking process
    uint entryOffset = 0;
    /// Indicate the type of program being compiled
    /// (It's probably Capsule bytecode using the standard ABI)
    Architecture objectArchitecture = Architecture.None;
    ///
    TextEncoding objectTextEncoding = TextEncoding.None;
    ///
    TimeEncoding objectTimeEncoding = TimeEncoding.None;
    /// A program to be constructed from all the linked objects
    Program program;
    /// When source file debugging information is included in the objects,
    /// it is all crammed into this one map to be included in the program.
    Source.Map programSourceMap;
    
    ///
    Segment textSegment;
    Segment readOnlyDataSegment;
    Segment dataSegment;
    Segment bssSegment;
    
    ///
    string programTitle = null;
    string programCredit = null;
    string programComment = null;
    
    ///
    bool includeDebugSymbols = false;
    bool includeLocalSymbols = false;
    bool includeDebugSources = false;
    
    this(Log* log, CapsuleObject object) {
        this(log, [object]);
    }
    
    this(Log* log, CapsuleObject[] objects) {
        assert(log);
        this.log = log;
        this.objects = objects;
    }
    
    /// Helper to add a status message that hasn't got any meaningful
    /// location info.
    void addLinkStatus(in Status status, in string context = null) {
        this.addStatus(FileLocation.init, status, context);
    }
    
    void addLinkStatus(in Status status, in string context, in string path) {
        FileLocation location;
        location.lineNumber = 0;
        location.file = File(path);
        this.addStatus(location, status, context);
    }
    
    void addReferenceStatus(in Status status, in Reference reference) {
        const path = (reference.object < this.objects.length ?
            this.objects[reference.object].filePath : null
        );
        const typeName = getEnumMemberAttribute!string(reference.type);
        const context = reference.name ~ "[" ~ typeName ~ "]";
        this.addLinkStatus(status, context, path);
    }
    
    typeof(this) link() {
        // Determine architecture, text encoding, and time encoding
        this.objectArchitecture = this.resolveArchitecture();
        this.objectTextEncoding = this.resolveTextEncoding();
        this.objectTimeEncoding = this.resolveTimeEncoding();
        if(this.log.anyErrors) return this;
        // Sort and drop all object sections into one list
        this.sections = this.createSectionList();
        if(this.log.anyErrors) return this;
        // Determine the byte offset of each section
        this.resolveSectionOffsets();
        if(this.log.anyErrors) return this;
        // Initialize a data structure for locating a particular section
        this.sectionMap = this.createLinkSectionMap();
        if(this.log.anyErrors) return this;
        // Initialize data structures representing segment offsets and lengths
        this.textSegment = this.createLinkSegment(Section.Type.Text);
        this.readOnlyDataSegment = this.createLinkSegment(Section.Type.ReadOnlyData);
        this.dataSegment = this.createLinkSegment(Section.Type.Data);
        this.bssSegment = this.createLinkSegment(Section.Type.BSS);
        if(this.log.anyErrors) return this;
        // Find the entry point
        this.entryOffset = this.resolveEntryOffset();
        if(this.log.anyErrors) return this;
        // Initialize a data structure for finding symbol definitions
        this.symbolMap = this.createSymbolMap();
        if(this.log.anyErrors) return this;
        // Make a list of all references that will need to be resolved
        this.references = this.createReferenceList();
        if(this.log.anyErrors) return this;
        // Resolve all those references
        this.resolveReferences();
        if(this.log.anyErrors) return this;
        // Get a source map, provided the input objects had source data
        if(this.includeDebugSources) {
            this.programSourceMap = this.createProgramSourceMap();
        }
        if(this.log.anyErrors) return this;
        // Put together the resulting program
        this.program = this.createProgram();
        if(this.log.anyErrors) return this;
        // All done
        return this;
    }
    
    Program createProgram() {
        Program program;
        // Set metadata
        program.architecture = this.objectArchitecture;
        program.textEncoding = this.objectTextEncoding;
        program.timeEncoding = this.objectTimeEncoding;
        program.title = this.programTitle;
        program.credit = this.programCredit;
        program.comment = this.programComment;
        program.timestamp = getUnixSeconds();
        program.entryOffset = this.entryOffset;
        program.sourceMap = this.programSourceMap;
        // Set segment data
        program.textSegment = this.getProgramSegment(Section.Type.Text);
        program.readOnlyDataSegment = this.getProgramSegment(Section.Type.ReadOnlyData);
        program.dataSegment = this.getProgramSegment(Section.Type.Data);
        program.bssSegment = this.getProgramSegment(Section.Type.BSS);
        // Include symbol information
        bool tooManyNames = false;
        bool tooManySymbols = false;
        uint getNameIndex(in string name) {
            const nameIndex = program.getNameIndex(name);
            if(program.names.length >= uint.max) {
                tooManyNames = true;
                return uint.max;
            }
            if(nameIndex >= program.names.length) {
                program.names ~= name;
            }
            return cast(uint) nameIndex;
        }
        if(this.includeDebugSymbols) {
            foreach(symbol; this.symbolMap.list) {
                if(!symbol.isDefined ||
                    (symbol.isLocal && !this.includeLocalSymbols)
                ) {
                    continue;
                }
                else if(program.symbols.length >= uint.max) {
                    tooManySymbols = true;
                    break;
                }
                const Program.Symbol programSymbol = {
                    type: symbol.type,
                    name: getNameIndex(symbol.name),
                    length: symbol.length,
                    value: symbol.value,
                };
                program.symbols ~= programSymbol;
            }
        }
        // Emit messages if any list length exceeded uint.max
        if(tooManyNames) {
            this.addStatus(FileLocation.init, Status.TooManyNames);
        }
        if(tooManySymbols) {
            this.addStatus(FileLocation.init, Status.TooManySymbols);
        }
        // All done
        assert(program.entryOk, "Problem with program entry point.");
        assert(program.lengthOk, "Problem with program memory length.");
        assert(program.textSegmentOk, "Problem with program's text segment.");
        assert(program.readOnlyDataSegmentOk, "Problem with program's rodata segment.");
        assert(program.dataSegmentOk, "Problem with program's data segment.");
        assert(program.bssSegmentOk, "Problem with program's bss segment.");
        assert(program.segmentOrderOk, "Problem with program's segment ordering.");
        assert(program.namesOk, "Problem with program names list.");
        assert(program.symbolsOk, "Problem with program symbols list.");
        assert(program.sourceMapOk, "Problem with program source map.");
        assert(program.ok);
        return program;
    }
    
    Source.Map createProgramSourceMap() {
        // De-duplicate sources shared between objects
        Source[] sources;
        uint[][] sourceIndex = new uint[][this.objects.length];
        foreach(i, object; this.objects) {
            sourceIndex[i].length = object.sources.length;
            ObjectSources:
            foreach(j, objSource; object.sources) {
                foreach(k, programSource; sources) {
                    if(objSource.name == programSource.name &&
                        objSource.encoding == programSource.encoding &&
                        objSource.checksum == programSource.checksum &&
                        objSource.content == programSource.content
                    ) {
                        sourceIndex[i][j] = cast(uint) k;
                        continue ObjectSources;
                    }
                }
                if(sources.length >= uint.max) {
                    this.addLinkStatus(Status.TooManySources);
                    return Source.Map.init;
                }
                sourceIndex[i][j] = cast(uint) sources.length;
                sources ~= objSource;
            }
        }
        // Make one single long list of source locations, with per-section
        // offsets recalculated as program memory addresses
        Source.Location[] locations;
        EnumerateObjects:
        foreach(i, object; this.objects) {
            if(object.sectionSourceLocations.length < object.sections.length) {
                this.addLinkStatus(
                    Status.InvalidObjectSourceLocationData, object.filePath
                );
                continue EnumerateObjects;
            }
            for(uint j = 0; j < object.sectionSourceLocations.length; j++) {
                const section = this.getLinkSection(cast(uint) i, j);
                foreach(objLocation; object.sectionSourceLocations[j]) {
                    Source.Location programLocation = objLocation;
                    if(objLocation.source >= sourceIndex[i].length) {
                        this.addLinkStatus(
                            Status.InvalidObjectSourceLocationData, object.filePath
                        );
                        continue EnumerateObjects;
                    }
                    else if(locations.length >= uint.max) {
                        this.addLinkStatus(Status.TooManySourceLocations);
                        break EnumerateObjects;
                    }
                    programLocation.source = sourceIndex[i][objLocation.source];
                    programLocation.startAddress += section.offset;
                    programLocation.endAddress += section.offset;
                    locations ~= programLocation;
                }
            }
        }
        // Wrap it up
        sort(locations);
        return Source.Map(sources, locations);
    }
    
    Program.Segment getProgramSegment(in Section.Type type) {
        // Initialize a segment
        Program.Segment segment = {
            type: type,
            offset: 0,
            length: 0,
            checksum: 0,
            bytes: null,
        };
        // Enumerate sections making up this segment
        bool foundStart = false;
        foreach(section; this.sections) {
            if(section.type > type) break;
            if(!foundStart && section.type is type) {
                segment.offset = section.offset;
                foundStart = true;
            }
            else if(!foundStart) {
                segment.offset = section.offset + section.length;
            }
            if(section.type is type) {
                segment.length = (
                    section.offset + section.length - segment.offset
                );
                if(section.isInitialized) {
                    assert(section.offset - segment.offset >= segment.bytes.length);
                    size_t offset = segment.bytes.length;
                    segment.bytes.length = section.offset - segment.offset;
                    while(offset < segment.bytes.length) {
                        segment.bytes[offset++] = 0;
                    }
                    segment.bytes ~= section.bytes;
                }
            }
        }
        // Compute CRC checksum
        if(Object.Section.typeIsInitialized(type)) {
            segment.checksum = CRC32.get(segment.bytes);
        }
        // Make sure this is consistent with earlier determinations
        version(assert) {
            const linkSegment = this.getLinkSegment(type);
            assert(segment.offset == linkSegment.offset);
            assert(segment.length == linkSegment.length);
        }
        // All done
        return segment;
    }
    
    Segment getLinkSegment(in Section.Type type) const {
        switch(type) {
            case Section.Type.Text: return this.textSegment;
            case Section.Type.ReadOnlyData: return this.readOnlyDataSegment;
            case Section.Type.Data: return this.dataSegment;
            case Section.Type.BSS: return this.bssSegment;
            default: assert(false, "Invalid section type.");
        }
    }
    
    Segment createLinkSegment(in Section.Type type) const {
        Segment segment = {
            length: 0,
            offset: 0,
        };
        bool foundStart = false;
        foreach(section; this.sections) {
            if(section.type > type) break;
            if(!foundStart && section.type is type) {
                segment.offset = section.offset;
                foundStart = true;
            }
            else if(!foundStart) {
                segment.offset = section.offset + section.length;
            }
            if(section.type is type) {
                segment.length = (
                    section.offset + section.length - segment.offset
                );
            }
        }
        return segment;
    }
    
    /// Check each object file and retrieve the architecture type
    /// which all of them used, or else register an error status
    /// if there was any inconsistency or other issue.
    Architecture resolveArchitecture() {
        Architecture architecture = Architecture.None;
        foreach(object; this.objects) {
            if(!object.architecture) {
                this.addLinkStatus(Status.ObjectNoArchitecture, object.filePath);
                return Architecture.None;
            }
            else if(!architecture) {
                architecture = object.architecture;
            }
            else if(architecture != object.architecture) {
                this.addLinkStatus(Status.ObjectArchitectureMismatch);
                return Architecture.None;
            }
        }
        return architecture;
    }
    
    TextEncoding resolveTextEncoding() {
        TextEncoding textEncoding = TextEncoding.None;
        foreach(object; this.objects) {
            if(!textEncoding) {
                textEncoding = object.textEncoding;
            }
            else if(textEncoding != object.textEncoding) {
                this.addLinkStatus(Status.ObjectTextEncodingMismatch);
                return TextEncoding.None;
            }
        }
        return textEncoding;
    }
    
    TimeEncoding resolveTimeEncoding() {
        TimeEncoding timeEncoding = TimeEncoding.None;
        foreach(object; this.objects) {
            if(!timeEncoding) {
                timeEncoding = object.timeEncoding;
            }
            else if(timeEncoding != object.timeEncoding) {
                this.addLinkStatus(Status.ObjectTimeEncodingMismatch);
                return TimeEncoding.None;
            }
        }
        return timeEncoding;
    }
    
    /// Find the an entry point offset indicated within the linked objects.
    /// Produce a status message if there was no entry or if there was
    /// more than one entry.
    uint resolveEntryOffset() {
        this.addLinkStatus(Status.LinkResolveEntryOffset);
        uint entryOffset = 0;
        bool foundEntry = false;
        for(uint objectIndex = 0; objectIndex < this.objects.length; objectIndex++) {
            const object = this.objects[objectIndex];
            if(object.hasEntry) {
                this.addLinkStatus(Status.LinkFoundEntryOffset, object.filePath);
                if(foundEntry) {
                    this.addLinkStatus(Status.MultipleEntryPoints);
                    return 0;
                }
                auto section = this.getLinkSection(
                    objectIndex, object.entrySection
                );
                if(!section) {
                    this.addLinkStatus(Status.InvalidObjectEntry, object.filePath);
                    return 0;
                }
                entryOffset = object.entryOffset + section.offset;
                foundEntry = true;
                if(entryOffset < object.entryOffset) {
                    this.addLinkStatus(Status.InvalidObjectEntry, object.filePath);
                    return 0;
                }
            }
        }
        if(!foundEntry) {
            this.addLinkStatus(Status.NoEntryPoint);
            return 0;
        }
        return entryOffset;
    }
    
    /// Get the linker's enriched record of an object file section
    /// associated with the given object file index and section index
    /// within that object file
    auto getLinkSection(in uint object, in uint section) {
        if(object >= this.sectionMap.length ||
            section >= this.sectionMap[object].length
        ) {
            return Section.init;
        }
        return this.sectionMap[object][section];
    }
    
    /// Create a list of CapsuleLinkerSection instances based on the
    /// CapsuleSection instances belonging to the list of objects given
    /// to the linker.
    Section[] createSectionList() {
        if(this.objects.length > uint.max) {
            this.addLinkStatus(Status.TooManyObjects);
        }
        Section[] sections;
        for(size_t i = 0; i < this.objects.length && i < uint.max; i++) {
            assert(this.objects[i].sections.length <= uint.max);
            for(size_t j = 0; j < this.objects[i].sections.length; j++) {
                assert(j <= uint.max);
                auto objectSection = this.objects[i].sections[j];
                Section linkSection = {
                    object: cast(uint) i,
                    section: cast(uint) j,
                    type: objectSection.type,
                    alignment: objectSection.alignment,
                    priority: objectSection.priority,
                    length: objectSection.length,
                    bytes: objectSection.bytes,
                    offset: 0,
                };
                sections ~= linkSection;
                if(sections.length > uint.max) {
                    this.addLinkStatus(Status.TooManySections);
                    return sections;
                }
            }
        }
        assert(sections.length <= uint.max);
        this.sortSectionList(sections);
        return sections;
    }
    
    void sortSectionList(ref Section[] sections) {
        static assert(Section.Type.Text < Section.Type.ReadOnlyData);
        static assert(Section.Type.ReadOnlyData < Section.Type.Data);
        static assert(Section.Type.Data < Section.Type.BSS);
        // TODO: Might be nice to optimize for alignment values one day
        assert(sections.length <= uint.max);
        this.addLinkStatus(Status.LinkSortObjectSections);
        sections.sort!((a, b) => (
            a.type == b.type ? a.priority < b.priority : a.type < b.type
        ));
    }
    
    void resolveSectionOffsets() {
        // Compute byte offsets for each section
        this.addLinkStatus(Status.LinkResolveSectionOffsets);
        uint offset = 0;
        foreach(ref section; this.sections) {
            assert(section.type);
            const padding = (
                section.alignment - (offset % section.alignment)
            );
            section.offset = offset + (
                padding && padding < section.alignment ? padding : 0
            );
            const oldOffset = offset;
            offset = section.offset + section.length;
            if(offset < oldOffset) {
                this.addLinkStatus(Status.ProgramTooLarge);
            }
        }
    }
    
    /// Populate associative arrays with references to symbols,
    /// mapped by their name strings.
    SymbolMap createSymbolMap() {
        assert(this.objects.length <= uint.max);
        this.addLinkStatus(Status.LinkCreateSymbolMap);
        SymbolMap symbolMap;
        symbolMap.initialize(this.objects);
        for(uint objectIndex = 0; objectIndex < this.objects.length; objectIndex++) {
            auto object = this.objects[objectIndex];
            foreach(symbol; object.symbols) {
                const symbolName = object.getName(symbol.name);
                if(!symbolName) {
                    this.addLinkStatus(Status.InvalidObjectSymbol, object.filePath);
                    continue;
                }
                auto linkSection = this.getLinkSection(
                    objectIndex, symbol.section
                );
                if(!linkSection) {
                    this.addLinkStatus(
                        Status.InvalidObjectSymbol, symbolName, object.filePath
                    );
                    continue;
                }
                uint value = symbol.value;
                if(symbol.isAddress) {
                    value += linkSection.offset;
                    if(value < symbol.value) {
                        this.addLinkStatus(
                            Status.InvalidObjectSymbol, symbolName, object.filePath
                        );
                        break;
                    }
                }
                CapsuleLinkerSymbol mappedSymbol = {
                    type: symbol.type,
                    visibility: symbol.visibility,
                    name: symbolName,
                    length: symbol.length,
                    object: objectIndex,
                    section: symbol.section,
                    localValue: symbol.value,
                    value: value,
                };
                const symbolStatus = symbolMap.addSymbol(mappedSymbol);
                if(symbolStatus.exportCollision) {
                    this.addLinkStatus(Status.DuplicateExportedSymbolName, symbolName);
                }
                if(symbolStatus.globalCollision) {
                    this.addLinkStatus(
                        Status.DuplicateGlobalSymbolName, symbolName, object.filePath
                    );
                }
            }
        }
        return symbolMap;
    }
    
    Section[][] createLinkSectionMap() {
        Section[][] sectionMap = new Section[][this.objects.length];
        for(size_t i = 0; i < this.objects.length; i++) {
            sectionMap[i] = new Section[this.objects[i].sections.length];
            for(size_t j = 0; j < this.objects[i].sections.length; j++) {
                foreach(ref section; this.sections) {
                    if(section.object == i && section.section == j) {
                        sectionMap[i][j] = section;
                        break;
                    }
                }
            }
        }
        return sectionMap;
    }
    
    Reference[] createReferenceList() {
        assert(this.objects.length <= uint.max);
        Reference[] references;
        for(uint objectIndex = 0; objectIndex < this.objects.length; objectIndex++) {
            auto object = this.objects[objectIndex];
            foreach(reference; object.references) {
                const referenceName = object.getName(reference.name);
                if(!referenceName) {
                    this.addLinkStatus(Status.InvalidObjectReference, object.filePath);
                    continue;
                }
                else if(!this.getLinkSection(objectIndex, reference.section)) {
                    this.addLinkStatus(
                        Status.InvalidObjectReference, referenceName, object.filePath
                    );
                    continue;
                }
                Reference linkReference = {
                    object: objectIndex,
                    section: reference.section,
                    type: reference.type,
                    localType: reference.localType,
                    name: referenceName,
                    offset: reference.offset,
                    addend: reference.addend,
                };
                references ~= linkReference;
            }
        }
        return references;
    }
    
    Symbol getLinkDirectiveValue(
        in CapsuleAsmNumberLinkDirectiveType type, in Reference reference
    ) {
        alias Type = CapsuleAsmNumberLinkDirectiveType;
        Symbol symbol = {
            object: 0,
            section: 0,
            type: Symbol.Type.Label,
            visibility: Symbol.Visibility.Export,
            name: getEnumMemberAttribute!string(type),
        };
        if(type is Type.TextSegmentOffset) {
            symbol.value = this.textSegment.offset;
            symbol.length = this.textSegment.length;
        }
        else if(type is Type.ReadOnlyDataSegmentOffset) {
            symbol.value = this.readOnlyDataSegment.offset;
            symbol.length = this.readOnlyDataSegment.length;
        }
        else if(type is Type.DataSegmentOffset) {
            symbol.value = this.dataSegment.offset;
            symbol.length = this.dataSegment.length;
        }
        else if(type is Type.BSSSegmentOffset) {
            symbol.value = this.bssSegment.offset;
            symbol.length = this.bssSegment.length;
        }
        else {
            this.addReferenceStatus(
                Status.InvalidObjectReferenceUndeclaredSymbol, reference
            );
        }
        symbol.localValue = symbol.value;
        return symbol;
    }
    
    void resolveReferences() {
        this.addLinkStatus(Status.LinkResolveReferences);
        bool anyUnresolved = false;
        foreach(ref reference; this.references) {
            this.resolveReference(reference);
            anyUnresolved = anyUnresolved || !reference.resolved;
        }
        if(anyUnresolved) {
            this.addLinkStatus(Status.UnresolvedReference);
        }
    }
    
    void resolveReference(ref Reference reference) {
        alias LinkDirectiveType = CapsuleAsmNumberLinkDirectiveType;
        assert(reference.object < this.objects.length);
        assert(reference.section < this.objects[reference.object].sections.length);
        if(reference.resolved) {
            return;
        }
        auto object = this.objects[reference.object];
        auto section = this.getLinkSection(reference.object, reference.section);
        if(!section.isInitialized) {
            this.addReferenceStatus(
                Status.ReferenceInUninitializedSection, reference
            );
            return;
        }
        Symbol symbol = Symbol.init;
        uint pcOffset = reference.offset + section.offset;
        // Find the identified symbol for a local reference
        if(reference.localType !is LocalType.None) {
            symbol = this.symbolMap.getLocalSymbol(
                reference.object, reference.section, reference.offset,
                reference.name, reference.localType
            );
        }
        // References of type pcrel_near_lo look for a corresponding pcrel_hi
        // reference in the immediately previous word
        else if(reference.isNearLowHalfType) {
            symbol.type = Symbol.Type.Undefined;
            symbol.object = reference.object;
            symbol.section = reference.section;
            symbol.localValue = reference.offset - 4;
            symbol.value = reference.offset + section.offset - 4;
        }
        // Reference is to a linker-defined constant value
        else if(reference.name.length && reference.name[0] == '.' &&
            getEnumMemberWithAttribute!LinkDirectiveType(reference.name[1 .. $])
        ) {
            const type = getEnumMemberWithAttribute!LinkDirectiveType(
                reference.name[1 .. $]
            );
            symbol = this.getLinkDirectiveValue(type, reference);
        }
        // Find the identified symbol for a global reference
        else {
            symbol = this.symbolMap.getGlobalSymbol(
                reference.object, reference.name
            );
        }
        // Handle the case where no symbol could be found
        if(!symbol) {
            this.addReferenceStatus(
                Status.InvalidObjectReferenceUndeclaredSymbol, reference
            );
            return;
        }
        // Handle pcrel_lo and pcrel_near_lo references; the result depends
        // on the resolved value of a corresponding pcrel_hi reference
        reference.symbolValue = symbol.value;
        reference.symbolLength = symbol.length;
        if(reference.isPcRelativeLowHalf) {
            const hiRefIndex = findCapsuleObjectPcRelHighReference!((hiRef) => (
                hiRef.object == symbol.object &&
                hiRef.section == symbol.section
            ))(this.references, reference.type, reference.name, symbol.localValue);
            if(hiRefIndex.ok && !this.references[hiRefIndex.index].resolved) {
                this.resolveReference(this.references[hiRefIndex.index]);
            }
            if(!hiRefIndex.ok || !this.references[hiRefIndex.index].resolved) {
                const status = (reference.type is Reference.Type.PCRelativeAddressLowHalf ?
                    Status.ObjectReferenceUnmatchedPCRelLo :
                    Status.ObjectReferenceUnmatchedPCRelNearLo
                );
                this.addReferenceStatus(status, reference);
                return;
            }
            assert(
                symbol.value - hiRefIndex.offset ==
                section.offset + this.references[hiRefIndex.index].offset
            );
            pcOffset = section.offset + this.references[hiRefIndex.index].offset;
            reference.symbolValue = this.references[hiRefIndex.index].symbolValue;
            reference.symbolLength = this.references[hiRefIndex.index].symbolLength;
        }
        // Resolve and write the referenced value to the containing section
        const resolved = resolveCapsuleObjectReference(
            section.bytes, reference.type, reference.offset,
            pcOffset, reference.addend,
            reference.symbolValue, reference.symbolLength,
        );
        if(resolved.status !is Status.Ok) {
            this.addReferenceStatus(resolved.status, reference);
        }
        else {
            reference.resolved = true;
            this.addReferenceStatus(
                Status.LinkerResolveReferenceSuccess, reference
            );
        }
    }
}
