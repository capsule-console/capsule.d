module capsule.core.program;

import capsule.core.crc : CRC32;
import capsule.core.encoding : CapsuleArchitecture;
import capsule.core.encoding : CapsuleTextEncoding, CapsuleTimeEncoding;
import capsule.core.obj : CapsuleObject;
import capsule.core.programsource : CapsuleProgramSource;

nothrow @safe @nogc public:

/// Enumeration of capsule memory segment types.
/// Here's why the segments are ordered in this way:
/// BSS
/// .bss and .data take up the lowest addresses so that it's more feasible
/// to optimize loads and stores to what is presumably frequently-accessed
/// memory, since loads and stores can be done in fewer instructions if the
/// address fits into a half word.
/// DATA
/// .data comes after .bss so that all of the initialized segments - namely
/// .data, .rodata, and .text - can all be contiguous in memory. It's a small
/// optimization but may help keep things simple and future-proof.
/// READ-ONLY DATA
/// .rodata comes before other segments for the same reason that .bss and
/// .data are in the lowest addresses - to optimize loads, at least for
/// programs where .rodata is still addressable via a half word. It comes
/// after .bss and .data because of the presumption that read-and-write
/// memory is likely to be addressed more often than read-only memory.
/// Keeping the read-only segments contiguous (.rodata and .text) may also
/// help to keep things simple and future-proof.
/// TEXT
/// .text is the last of the initialized segments for the reason that
/// jumps and branches are all expected to use relative addressing, and
/// meaning it's not very relevant where in the address space the .text
/// segment is located.
/// STACK
/// .stack comes late in the address space because, practically speaking,
/// loads and stores will almost always if not unfailingly be relative to a
/// stack pointer stored in a register, making absolute addressing unimportant.
/// HEAP
/// .heap comes late in the address space for a similar reason as the .stack;
/// loads and stores will usually if not always be relative to a pointer to
/// a location in the heap, stored in a register or elsewhere. The primary
/// reason for the .heap to be the last segment, though, and for it to not
/// share a segment with the .stack, is to leave the option open to expand
/// the heap into higher addresses if a program requests more heap memory
/// during runtime, or to shrink the heap down to a lower maximum address if
/// a program relinquishes heap memory during runtime.
enum CapsuleProgramSegmentType: uint {
    @("none") None = cast(uint) CapsuleObject.Section.Type.None,
    @("bss") BSS = cast(uint) CapsuleObject.Section.Type.BSS,
    @("data") Data = cast(uint) CapsuleObject.Section.Type.Data,
    @("rodata") ReadOnlyData = cast(uint) CapsuleObject.Section.Type.ReadOnlyData,
    @("text") Text = cast(uint) CapsuleObject.Section.Type.Text,
    @("stack") Stack,
    @("heap") Heap,
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
    
    alias Type = CapsuleProgramSegmentType;
    
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
            (this.type !is Type.None && this.type <= Type.Heap) &&
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
            case Type.BSS: return false;
            case Type.Data: return true;
            case Type.ReadOnlyData: return true;
            case Type.Text: return true;
            case Type.Stack: return false;
            case Type.Heap: return false;
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
    
    /// Information about the program's bss segment.
    CapsuleProgramSegment bssSegment;
    /// Information about the program's data segment.
    CapsuleProgramSegment dataSegment;
    /// Information about the program's rodata segment.
    CapsuleProgramSegment readOnlyDataSegment;
    /// Information about the program's text segment.
    CapsuleProgramSegment textSegment;
    /// Information about the program's stack segment.
    CapsuleProgramSegment stackSegment;
    /// Information about the program's heap segment.
    CapsuleProgramSegment heapSegment;
    
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
            this.entryOffset < this.length &&
            // Total memory length is valid?
            this.length <= int.max &&
            // Each segment individually is valid?
            this.bssSegment.ok && this.dataSegment.ok &&
            this.readOnlyDataSegment.ok && this.textSegment.ok &&
            this.stackSegment.ok && this.heapSegment.ok &&
            // Segments have the correct type information?
            this.bssSegment.type is Segment.Type.BSS &&
            this.dataSegment.type is Segment.Type.Data &&
            this.readOnlyDataSegment.type is Segment.Type.ReadOnlyData &&
            this.textSegment.type is Segment.Type.Text &&
            this.stackSegment.type is Segment.Type.Stack &&
            this.heapSegment.type is Segment.Type.Heap &&
            // Segment offsets and lengths put them in the correct order?
            this.dataSegment.offset >= this.bssSegment.end &&
            this.readOnlyDataSegment.offset >= this.dataSegment.end &&
            this.textSegment.offset >= this.readOnlyDataSegment.end &&
            this.stackSegment.offset >= this.textSegment.end &&
            this.heapSegment.offset >= this.stackSegment.end &&
            // Lists of things are of acceptable lengths?
            this.names.length <= uint.max &&
            this.symbols.length <= uint.max &&
            // Source map must be valid, if there is one
            this.sourceMap.locationListIsSorted()
        );
    }
    
    /// Get the total length in bytes of the program's memory.
    uint length() const {
        return this.heapSegment.offset + this.heapSegment.length;
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
        if(this.bssSegment.containsAddress(address)) return this.bssSegment;
        else if(this.dataSegment.containsAddress(address)) return this.dataSegment;
        else if(this.readOnlyDataSegment.containsAddress(address)) return this.readOnlyDataSegment;
        else if(this.textSegment.containsAddress(address)) return this.textSegment;
        else if(this.stackSegment.containsAddress(address)) return this.stackSegment;
        else if(this.heapSegment.containsAddress(address)) return this.heapSegment;
        else return Segment.init;
    }
    
    auto getSegmentWithType(in Segment.Type type) const {
        switch(type) {
            case Segment.Type.BSS: return this.bssSegment;
            case Segment.Type.Data: return this.dataSegment;
            case Segment.Type.ReadOnlyData: return this.readOnlyDataSegment;
            case Segment.Type.Text: return this.textSegment;
            case Segment.Type.Stack: return this.stackSegment;
            case Segment.Type.Heap: return this.heapSegment;
            default: return Segment.init;
        }
    }
}
