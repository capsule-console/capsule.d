module capsule.core.obj;

import capsule.core.encoding : CapsuleArchitecture, CapsuleHashType;
import capsule.core.encoding : CapsuleTextEncoding, CapsuleTimeEncoding;
import capsule.core.programsource : CapsuleProgramSource;

nothrow @safe @nogc public:

enum CapsuleObjectSectionType: ushort {
    @("none") None = 0x0000,
    @("bss") BSS = 0x2000,
    @("data") Data = 0x4000,
    @("rodata") ReadOnlyData = 0x6000,
    @("text") Text = 0x8000,
}

enum CapsuleObjectSymbolType: ushort {
    /// No symbol or missing symbol
    @("none") None = 0x0000,
    /// Symbol type is unknown or undefined
    @("undefined") Undefined = 0x0001,
    /// Symbol contains a constant value known at compilation time
    @("constant") Constant = 0x0002,
    /// Symbol is a label
    @("label") Label = 0x0003,
    /// Symbol is a label indicating an in-memory variable or constant
    @("variable") Variable = 0x0004,
    /// Symbol is a label indicating a function or procedure
    @("procedure") Procedure = 0x0005,
}

enum CapsuleObjectSymbolVisibility: ushort {
    /// Not visible
    @("none") None = 0x0000,
    /// Local symbols are visible only in the section where they were defined
    @("local") Local = 0x0001,
    /// Extern symbols are treated as undefined globals and must be
    /// resolved during linking
    @("extern") Extern = 0x0002,
    /// Global symbols are visible in every section of a module,
    /// not only the section in which they were defined
    @("global") Global = 0x0003,
    /// Export symbols behave like globals within a module, but are also
    /// visible to other modules via externs when linking
    @("export") Export = 0x0004,
}

enum CapsuleObjectReferenceType: ushort {
    /// No reference or missing reference
    @("none") None = 0x00,
    /// Expect an 8-bit absolute value
    @("byte") AbsoluteByte = 0x20,
    /// Expect a 16-bit absolute value
    @("half") AbsoluteHalfWord = 0x21,
    /// Expect a 32-bit absolute value
    @("word") AbsoluteWord = 0x22,
    /// Expect a 32-bit absolute value; fill the low 16 bits
    @("lo") AbsoluteWordLowHalf = 0x23,
    /// Expect a 32-bit absolute value; fill the high 16 bits
    /// Accounts for signedness of the low half by adding 1 if the 15th
    /// least significant bit of the low half was set.
    @("hi") AbsoluteWordHighHalf = 0x24,
    /// Expect a 32-bit absolute value; fill the high 16 bits
    /// Always contains the exact high 16 bits of the value
    @("solo_hi") AbsoluteWordSoloHighHalf = 0x25,
    /// Expect an 8-bit symbol definition length value
    @("length_byte") LengthByte = 0x40,
    /// Expect a 16-bit symbol definition length value
    @("length_half") LengthHalfWord = 0x41,
    /// Expect a 32-bit symbol definition length value
    @("length_word") LengthWord = 0x42,
    /// Expect a 32-bit length value; fill the low 16 bits
    @("length_lo") LengthWordLowHalf = 0x43,
    /// Expect a 32-bit length value; fill the high 16 bits
    /// Accounts for signedness of the low half by adding 1 if the 15th
    /// least significant bit of the low half was set.
    @("length_hi") LengthWordHighHalf = 0x44,
    /// Expect a 32-bit length value; fill the high 16 bits
    /// Always contains the exact high 16 bits of the value
    @("length_solo_hi") LengthWordSoloHighHalf = 0x45,
    /// Expect a signed 16-bit relative address offset as an immediate value
    @("pcrel_half") PCRelativeAddressHalf = 0xa1,
    /// Expect a signed 32-bit relative address offset and space to
    /// fit the entire word.
    @("pcrel_word") PCRelativeAddressWord = 0xa2,
    /// Expect a signed 32-bit relative address offset; fill the low 16 bits
    /// Pairs with the nearest prior pcrel_hi reference to the symbol with
    /// the same name.
    @("pcrel_near_lo") PCRelativeAddressNearLowHalf = 0xa3,
    /// Expect a signed 32-bit relative address offset; fill the high 16 bits
    /// Accounts for signedness of the low half by adding 1 if the 15th
    /// least significant bit of the low half was set.
    @("pcrel_hi") PCRelativeAddressHighHalf = 0xa4,
    /// Expect a signed 32-bit relative address offset; fill the high 16 bits
    /// Always contains the exact high 16 bits of the value.
    @("pcrel_solo_hi") PCRelativeAddressSoloHighHalf = 0xa5,
    /// Expect a signed 32-bit relative address offset; fill the low 16 bits
    /// The reference should be to a label describing the location of a
    /// corresponding pcrel_hi reference.
    @("pcrel_lo") PCRelativeAddressLowHalf = 0xa6,
    /// Expect a signed 16-bit relative address offset as an immediate value.
    /// Relative to the sum of the symbol address and its length.
    @("end_pcrel_half") EndPCRelativeAddressHalf = 0xc1,
    /// Expect a signed 32-bit relative address offset and space to
    /// fit the entire word.
    /// Relative to the sum of the symbol address and its length.
    @("end_pcrel_word") EndPCRelativeAddressWord = 0xc2,
    /// Expect a signed 32-bit relative address offset; fill the low 16 bits
    /// Pairs with the nearest prior end_pcrel_hi reference to the symbol with
    /// the same name.
    /// Relative to the sum of the symbol address and its length.
    @("end_pcrel_near_lo") EndPCRelativeAddressNearLowHalf = 0xc3,
    /// Expect a signed 32-bit relative address offset; fill the high 16 bits
    /// Accounts for signedness of the low half by adding 1 if the 15th
    /// least significant bit of the low half was set.
    /// Relative to the sum of the symbol address and its length.
    @("end_pcrel_hi") EndPCRelativeAddressHighHalf = 0xc4,
    /// Expect a signed 32-bit relative address offset; fill the high 16 bits
    /// Always contains the exact high 16 bits of the value
    /// Relative to the sum of the symbol address and its length.
    @("end_pcrel_solo_hi") EndPCRelativeAddressSoloHighHalf = 0xc5,
    /// Expect a signed 32-bit relative address offset; fill the low 16 bits
    /// The reference should be to a label describing the location of a
    /// corresponding pcrel_hi reference.
    /// Relative to the sum of the symbol address and its length.
    @("end_pcrel_lo") EndPCRelativeAddressLowHalf = 0xc6,
}

enum CapsuleObjectReferenceLocalType: char {
    None = '\0',
    Backward = 'b',
    Forward = 'f',
}

struct CapsuleObject {
    nothrow @safe @nogc:
    
    alias Architecture = CapsuleArchitecture;
    alias HashType = CapsuleHashType;
    alias Reference = CapsuleObjectReference;
    alias Section = CapsuleObjectSection;
    alias Source = CapsuleProgramSource;
    alias Symbol = CapsuleObjectSymbol;
    alias TextEncoding = CapsuleTextEncoding;
    alias TimeEncoding = CapsuleTimeEncoding;
    
    static enum uint NoName = uint.max;
    
    /// Represents the file path from which an object file was loaded.
    /// This field is managed by tools, e.g. the linker. It isn't saved
    /// in object files.
    string filePath;
    
    /// Compilation target, i.e. Capsule with the standard ABI
    Architecture architecture = Architecture.Capsule;
    /// Indicate the text encoding used for the object's string data
    TextEncoding textEncoding = TextEncoding.None;
    /// Indicate the format or encoding of the object's timestamp
    TimeEncoding timeEncoding = TimeEncoding.None;
    /// Object timestamp as a signed number of seconds since Unix epoch
    long timestamp = 0;
    /// String identifying the file or other source that the object
    /// was compiled from
    string sourceUri = null;
    /// Indicate the algorithm used to generate the object's source hash
    HashType sourceHashType = HashType.None;
    /// ISO CRC64 of the source from which the object was compiled
    ulong sourceHash = 0;
    /// Indicates whether an entry point was defined for this object
    bool hasEntry = false;
    /// Section where an entry point was specified
    uint entrySection = 0;
    /// Offset in section where the entry point is located
    uint entryOffset = 0;
    /// Freeform comment string
    string comment = null;
    /// List of symbol name strings
    string[] names;
    /// List of declared symbols
    Symbol[] symbols;
    /// List of references that will need to be resolved by a linker
    Reference[] references;
    /// List of sections
    Section[] sections;
    
    ///
    Source[] sources;
    ///
    Source.Location[][] sectionSourceLocations;
    
    /// Given a name index, get the corresponding name string.
    /// Returns null if the index was out of bounds.
    string getName(in uint nameIndex) const {
        return nameIndex < this.names.length ? this.names[nameIndex] : null;
    }
    
    /// Find the first index of a given name string.
    /// Returns the length of the names list if the string wasn't
    /// found in the list.
    size_t getNameIndex(in string name) const {
        for(size_t i = 0; i < this.names.length; i++) {
            if(name == this.names[i]) {
                return cast(size_t) i;
            }
        }
        return this.names.length;
    }
    
    /// Get the index of the first symbol with a matching
    /// section index and name index.
    size_t getSymbolIndex(in uint section, in uint name) const {
        size_t globalSymbol = this.symbols.length;
        for(size_t i = 0; i < this.symbols.length; i++) {
            if(this.symbols[i].name == name) {
                const isLocal = (
                    this.symbols[i].visibility is Symbol.Visibility.Local
                );
                if(isLocal && this.symbols[i].section == section) {
                    return cast(size_t) i;
                }
                else if(!isLocal) {
                    globalSymbol = cast(size_t) i;
                }
            }
        }
        return globalSymbol;
    }
}

/// Records a declared symbol
struct CapsuleObjectSymbol {
    nothrow @safe @nogc:
    
    alias Type = CapsuleObjectSymbolType;
    alias Visibility = CapsuleObjectSymbolVisibility;
    
    static enum uint NoName = uint.max;
    
    /// Section in which the symbol was defined
    uint section;
    
    /// Type of symbol definition
    Type type = Type.None;
    /// Symbol scope/visibility (extern, local, global, or export?)
    Visibility visibility = Visibility.None;
    /// Symbol name index
    uint name = NoName;
    /// Indicates the length in bytes of a symbol's declaration, when relevant.
    /// For example 2 for a half word in memory, or potentially much longer
    /// where a symbol indicates a function, symbol offset being the location
    /// of the function's entry point and length indicating how many bytes
    /// until the end of the function's implementation.
    uint length = 0;
    /// Meaning of this field depends on the symbol type
    /// For addresses: Byte offset in the section where the symbol was defined
    /// For constants: The value of a symbolic constant
    uint value = 0;
    
    static bool isAddressType(in CapsuleObjectSymbolType type) {
        with(CapsuleObjectSymbolType) switch(type) {
            case None: return false;
            case Undefined: return false;
            case Constant: return false;
            case Label: return true;
            case Variable: return true;
            case Procedure: return true;
            default: return false;
        }
    }
    
    static bool isDefinedType(in CapsuleObjectSymbolType type) {
        with(CapsuleObjectSymbolType) switch(type) {
            case None: return false;
            case Undefined: return false;
            case Constant: return true;
            case Label: return true;
            case Variable: return true;
            case Procedure: return true;
            default: return false;
        }
    }
    
    bool isAddress() const {
        return typeof(this).isAddressType(this.type);
    }
    
    bool isDefined() const {
        return typeof(this).isDefinedType(this.type);
    }
}

/// Used to mark places where a symbol is referenced.
/// Basically the same thing as a "relocation" in some other object formats.
struct CapsuleObjectReference {
    nothrow @safe @nogc:
    
    alias LocalType = CapsuleObjectReferenceLocalType;
    alias Type = CapsuleObjectReferenceType;
    
    static enum uint NoName = uint.max;
    
    /// Index of section where the reference occurs
    uint section;
    
    /// Type of reference
    Type type = Type.None;
    /// Is this a local reference and, if so, is it a forward 'f'
    /// or backward 'b' reference?
    LocalType localType = LocalType.None;
    /// Unused byte
    ubyte unused = 0;
    /// Index of referenced symbol name in the names table
    uint name = NoName;
    /// Byte offset in section
    uint offset = 0;
    /// Add to the value being referenced
    int addend = 0;
    
    /// Determine whether a reference type is a PC-relative type.
    static bool isPcRelativeType(in Type type) {
        switch(type) {
            case Type.PCRelativeAddressHalf: goto case;
            case Type.PCRelativeAddressWord: goto case;
            case Type.PCRelativeAddressNearLowHalf: goto case;
            case Type.PCRelativeAddressHighHalf: goto case;
            case Type.PCRelativeAddressSoloHighHalf: goto case;
            case Type.PCRelativeAddressLowHalf: return true;
            case Type.EndPCRelativeAddressHalf: goto case;
            case Type.EndPCRelativeAddressWord: goto case;
            case Type.EndPCRelativeAddressNearLowHalf: goto case;
            case Type.EndPCRelativeAddressHighHalf: goto case;
            case Type.EndPCRelativeAddressSoloHighHalf: goto case;
            case Type.EndPCRelativeAddressLowHalf: return true;
            default: return 0;
        }
    }
    
    /// Determine whether a reference type is the low half of
    /// a PC-relative type.
    static bool isPcRelativeLowHalfType(in Type type) {
        switch(type) {
            case Type.PCRelativeAddressNearLowHalf: goto case;
            case Type.PCRelativeAddressLowHalf: goto case;
            case Type.EndPCRelativeAddressNearLowHalf: goto case;
            case Type.EndPCRelativeAddressLowHalf: return true;
            default: return 0;
        }
    }
    
    /// True when the reference type is pcrel_near_lo or end_pcrel_near_lo,
    /// i.e. a reference type that is the low half of the closest preceding
    /// corresponding high half type. (For that see `getHighHalfType`.)
    static bool isNearLowHalfType(in Type type) {
        switch(type) {
            case Type.PCRelativeAddressNearLowHalf: goto case;
            case Type.EndPCRelativeAddressNearLowHalf: return true;
            default: return 0;
        }
    }
    
    /// Get the corresponding high half reference type for a given low
    /// half reference type, or CapsuleObject.Reference.Type.None if the
    /// given type wasn't a low half type or otherwise had no corresponding
    /// high half type.
    static Type getHighHalfType(in Type type) {
        switch(type) {
            case Type.PCRelativeAddressNearLowHalf:
                return Type.PCRelativeAddressHighHalf;
            case Type.PCRelativeAddressLowHalf:
                return Type.PCRelativeAddressHighHalf;
            case Type.EndPCRelativeAddressNearLowHalf:
                return Type.EndPCRelativeAddressHighHalf;
            case Type.EndPCRelativeAddressLowHalf:
                return Type.EndPCRelativeAddressHighHalf;
            default:
                return Type.None;
        }
    }
    
    /// This value is added to the reference's offset to determine
    /// what bytes will be overwritten in resolving the reference.
    static uint typeOffset(in Type type) {
        switch(type) {
            case Type.PCRelativeAddressHalf: return 2;
            case Type.PCRelativeAddressLowHalf: return 2;
            case Type.PCRelativeAddressHighHalf: return 2;
            case Type.PCRelativeAddressSoloHighHalf: return 2;
            case Type.PCRelativeAddressNearLowHalf: return 2;
            case Type.EndPCRelativeAddressHalf: return 2;
            case Type.EndPCRelativeAddressLowHalf: return 2;
            case Type.EndPCRelativeAddressHighHalf: return 2;
            case Type.EndPCRelativeAddressSoloHighHalf: return 2;
            case Type.EndPCRelativeAddressNearLowHalf: return 2;
            default: return 0;
        }
    }
    
    /// This is the number of bytes, starting at the reference's recorded
    /// offset plus the type's own offset, that will be overwritten in
    /// resolving the reference.
    static uint typeLength(in Type type) {
        switch(type) {
            case Type.None: return 0;
            case Type.AbsoluteByte: return 1;
            case Type.AbsoluteHalfWord: return 2;
            case Type.AbsoluteWord: return 4;
            case Type.AbsoluteWordLowHalf: return 2;
            case Type.AbsoluteWordHighHalf: return 2;
            case Type.AbsoluteWordSoloHighHalf: return 2;
            case Type.LengthByte: return 1;
            case Type.LengthHalfWord: return 2;
            case Type.LengthWord: return 4;
            case Type.LengthWordLowHalf: return 2;
            case Type.LengthWordHighHalf: return 2;
            case Type.LengthWordSoloHighHalf: return 2;
            case Type.PCRelativeAddressHalf: return 2;
            case Type.PCRelativeAddressWord: return 4;
            case Type.PCRelativeAddressNearLowHalf: return 2;
            case Type.PCRelativeAddressHighHalf: return 2;
            case Type.PCRelativeAddressSoloHighHalf: return 2;
            case Type.PCRelativeAddressLowHalf: return 2;
            case Type.EndPCRelativeAddressHalf: return 2;
            case Type.EndPCRelativeAddressWord: return 4;
            case Type.EndPCRelativeAddressNearLowHalf: return 2;
            case Type.EndPCRelativeAddressHighHalf: return 2;
            case Type.EndPCRelativeAddressSoloHighHalf: return 2;
            case Type.EndPCRelativeAddressLowHalf: return 2;
            default: return 0;
        }
    }
    
    /// Determine whether this reference is PC-relative.
    bool isPcRelative() const {
        return typeof(this).isPcRelativeType(this.type);
    }
    
    /// Determine whether this reference represents the low half
    /// of a PC-relative offset.
    bool isPcRelativeLowHalf() const {
        return typeof(this).isPcRelativeLowHalfType(this.type);
    }
    
    /// Determine whether this reference is the low half of a
    /// reference and should have a corresponding high half someplace.
    bool isNearLowHalfType() const {
        return typeof(this).isNearLowHalfType(this.type);
    }
    
    /// Get the high half reference type corresponding to this reference's
    /// low half type, or CapsuleObject.Reference.Type.None if this
    /// reference type has no corresponding high half type.
    Type getHighHalfType() const {
        return typeof(this).getHighHalfType(this.type);
    }
    
    /// Get a value added to the reference's own offset indicating a
    /// position where bytes are modified in resolving the reference.
    uint typeOffset() const {
        return typeof(this).typeOffset(this.type);
    }
    
    /// Get the number of bytes starting from the sum of the reference's
    /// offset or address and its `typeOffset` that are affected by
    /// resolving a reference.
    uint typeLength() const {
        return typeof(this).typeLength(this.type);
    }
}

/// Represents an object file section, e.g. `.text` or `.data`
struct CapsuleObjectSection {
    nothrow @safe @nogc:
    
    alias Type = CapsuleObjectSectionType;
    
    static enum uint NoName = uint.max;
    
    /// Indicates section type
    Type type;
    /// Unused half word
    ushort unused = 0;
    /// Index of section name in the names table
    uint name = NoName;
    /// Align on a boundary of this many bytes
    uint alignment = 4;
    /// The lesser the number, the higher the linker prioritizes
    /// putting this section closer to the beginning of the segment.
    int priority = 0;
    /// 32-bit CRC checksum to detect corruption of section data
    uint checksum = 0;
    /// The length of the section
    /// For sections in initialized segments, this should be the
    /// same as the bytes array length
    /// Sections in uninitialized segments can have a non-zero
    /// length assigned to them but should not have any byte data
    uint length = 0;
    /// Bytecode or other data
    ubyte[] bytes = null;
    
    bool opCast(T: bool)() const {
        return this.type !is Type.None;
    }
    
    bool isInitialized() const {
        return typeof(this).typeIsInitialized(this.type);
    }
    
    static bool typeIsInitialized(in Type type) {
        switch(type) {
            case Type.None: return false;
            case Type.BSS: return false;
            case Type.Data: return true;
            case Type.ReadOnlyData: return true;
            case Type.Text: return true;
            default: return false;
        }
    }
}
