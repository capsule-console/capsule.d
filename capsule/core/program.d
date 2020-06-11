module capsule.core.program;

import capsule.core.crc : CRC32;
import capsule.core.encoding : CapsuleArchitecture;
import capsule.core.encoding : CapsuleTextEncoding, CapsuleTimeEncoding;
import capsule.core.obj : CapsuleObject;
import capsule.core.programsource : CapsuleProgramSource;

nothrow @safe @nogc public:

struct CapsuleProgramSegmentProperties {
    alias Type = CapsuleObject.Section.Type;
    
    /// Represent properties of a missing or absent segment.
    static enum None = typeof(this)(Type.None, false, false, false);
    /// Represent the properties of a text segment.
    static enum Text = typeof(this)(Type.Text, true, false, true);
    /// Represent the properties of a rodata segment.
    static enum ReadOnlyData = typeof(this)(Type.ReadOnlyData, true, false, false);
    /// Represent the properties of a data segment.
    static enum Data = typeof(this)(Type.Data, true, true, false);
    /// Represent the properties of a bss segment.
    static enum BSS = typeof(this)(Type.BSS, false, true, false);
    
    /// Type of the segment whose properties are being represented.
    Type type;
    /// Whether data in this segment is initialized or uninitialized.
    bool initialized;
    /// Whether writes to this segment are normally allowed.
    bool write;
    /// Whether execution of instructions in this segment is normally allowed.
    bool execute;
    
    static typeof(this) get(in Type type) {
        switch(type) {
            case Type.Text: return typeof(this).Text;
            case Type.ReadOnlyData: return typeof(this).ReadOnlyData;
            case Type.Data: return typeof(this).Data;
            case Type.BSS: return typeof(this).BSS;
            default: return typeof(this).None;
        }
    }
}

struct CapsuleProgramSymbol {
    alias Type = CapsuleObject.Symbol.Type;
    
    static enum uint NoName = uint.max;
    
    Type type = Type.None;
    ushort unused = 0;
    uint name = NoName;
    uint length = 0;
    uint value = 0;
    
    bool opCast(T: bool)() const {
        return this.type !is Type.None;
    }
    
    bool isAddress() const {
        return CapsuleObject.Symbol.isAddressType(this.type);
    }
}

/// TODO
enum CapsuleProgramAssetType: uint {
    None = 0,
    PlainText,
    RichText,
    Image,
    Video,
    Audio,
}

/// TODO
struct CapsuleLocale {
    string name;
    string title;
}

/// TODO: Programs can identify certain locations in either compiled
/// program data or in asset-specific program file sections as game assets,
/// for example cover art or manuals or localized text
struct CapsuleProgramAsset {
    alias Type = CapsuleProgramAssetType;
    
    Type type;
    uint length;
    uint locale;
    union {
        uint assetContentIndex;
        uint segmentOffset;
    }
}

/// Represents a memory segment in a capsule program.
/// The same type can be used to represent an initialized or
/// an uninitialized segment.
struct CapsuleProgramSegment {
    nothrow @safe @nogc:
    
    alias Type = CapsuleObject.Section.Type;
    
    /// The type of segment, e.g. bss, data, text
    Type type;
    /// The offset of this section in memory
    uint offset = 0;
    /// The length of this section.
    /// Should be the same as bytes.length for initialized segments.
    uint length = 0;
    /// CRC32 checksum to verify the integrity of an initialized segment's
    /// content.
    uint checksum = 0;
    /// Array of bytes making up the segment.
    /// Array should be empty for uninitialized segments.
    ubyte[] bytes = null;
    
    /// Check whether the segment is valid.
    bool ok() const {
        return (
            // Must have a known segment type
            (this.type !is Type.None && this.type <= Type.BSS) &&
            // Initialized sections must have consistent lengths
            (!this.isInitialized || this.length == this.bytes.length) &&
            // Segment must lie entirely within addressable memory
            (this.offset < int.max) &&
            (int.max - this.offset >= this.length) &&
            // Checksum must be consistent with segment data
            (this.checksum == CRC32.get(this.bytes))
        );
    }
    
    /// Get the ending memory address for this segment.
    uint end() const {
        return this.offset + this.length;
    }
    
    /// Check whether a memory address falls within this segment.
    bool containsAddress(in uint address) const {
        return address >= this.offset && address < this.length;
    }
    
    /// Check whether a segment type contains initialized or uninitialized data.
    static bool typeIsInitialized(in Type type) {
        switch(type) {
            case Type.None: return false;
            case Type.Text: return true;
            case Type.ReadOnlyData: return true;
            case Type.Data: return true;
            case Type.BSS: return false;
            default: return false;
        }
    }
    
    /// Check whether the segment contains initialized or uninitialized data.
    bool isInitialized() const {
        return typeof(this).typeIsInitialized(this.type);
    }
}

struct CapsuleProgram {
    alias Architecture = CapsuleArchitecture;
    alias Segment = CapsuleProgramSegment;
    alias Source = CapsuleProgramSource;
    alias Symbol = CapsuleProgramSymbol;
    alias TextEncoding = CapsuleTextEncoding;
    alias TimeEncoding = CapsuleTimeEncoding;
    
    ///
    Architecture architecture = Architecture.Capsule;
    ///
    TextEncoding textEncoding = TextEncoding.None;
    ///
    TimeEncoding timeEncoding = TimeEncoding.None;
    /// Offset of the program execution entry point
    uint entryOffset = 0;
    /// A non-localized canonical title to fall back on for this program
    string title = null;
    /// A string describing the author, copyright, and/or any other
    /// related credit for the creation of the program
    string credit = null;
    ///
    string comment = null;
    /// Timestamp as a signed number of seconds since Unix epoch
    long timestamp = 0;
    
    /// Information about the program's text segment.
    CapsuleProgramSegment textSegment;
    /// Information about the program's rodata segment.
    CapsuleProgramSegment readOnlyDataSegment;
    /// Information about the program's data segment.
    CapsuleProgramSegment dataSegment;
    /// Information about the program's bss segment.
    CapsuleProgramSegment bssSegment;
    
    ///
    string[] names = null;
    ///
    Symbol[] symbols = null;
    
    ///
    Source.Map sourceMap;
    
    /// Check that the program is valid and can in fact be run
    bool ok() const {
        return (
            // Entry point offset is valid?
            this.entryOk &&
            // Total memory length is valid?
            this.lengthOk &&
            // Each segment individually is valid and has the correct type?
            this.textSegmentOk &&
            this.readOnlyDataSegmentOk &&
            this.dataSegmentOk &&
            this.bssSegmentOk &&
            // Segment offsets and lengths put them in the correct order?
            this.segmentOrderOk &&
            // Lists of things are of acceptable lengths?
            this.namesOk &&
            this.symbolsOk &&
            // Source map must be valid, if there is one
            this.sourceMapOk
        );
    }
    
    bool entryOk() const {
        return this.entryOffset < this.length;
    }
    
    bool lengthOk() const {
        return this.length <= int.max;
    }
    
    bool textSegmentOk() const {
        return this.textSegment.ok && (
            this.textSegment.type is Segment.Type.Text
        );
    }
    
    bool readOnlyDataSegmentOk() const {
        return this.readOnlyDataSegment.ok && (
            this.readOnlyDataSegment.type is Segment.Type.ReadOnlyData
        );
    }
    
    bool dataSegmentOk() const {
        return this.dataSegment.ok && (
            this.dataSegment.type is Segment.Type.Data
        );
    }
    
    bool bssSegmentOk() const {
        return this.bssSegment.ok && (
            this.bssSegment.type is Segment.Type.BSS
        );
    }
    
    bool segmentOrderOk() const {
        return (
            this.readOnlyDataSegment.offset >= this.textSegment.end &&
            this.dataSegment.offset >= this.readOnlyDataSegment.end &&
            this.bssSegment.offset >= this.dataSegment.end
        );
    }
    
    bool namesOk() const {
        return this.names.length <= uint.max;
    }
    
    bool symbolsOk() const {
        return this.symbols.length <= uint.max;
    }
    
    bool sourceMapOk() const {
        return this.sourceMap.locationListIsSorted();
    }
    
    /// Get the total length in bytes of the program's memory.
    uint length() const {
        return this.bssSegment.end;
    }
    
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
    
    auto getContainingSegment(in uint address) const {
        if(this.textSegment.containsAddress(address)) return this.textSegment;
        else if(this.readOnlyDataSegment.containsAddress(address)) return this.readOnlyDataSegment;
        else if(this.dataSegment.containsAddress(address)) return this.dataSegment;
        else if(this.bssSegment.containsAddress(address)) return this.bssSegment;
        else return Segment.init;
    }
    
    auto getSegmentWithType(in Segment.Type type) const {
        switch(type) {
            case Segment.Type.Text: return this.textSegment;
            case Segment.Type.ReadOnlyData: return this.readOnlyDataSegment;
            case Segment.Type.Data: return this.dataSegment;
            case Segment.Type.BSS: return this.bssSegment;
            default: return Segment.init;
        }
    }
}
