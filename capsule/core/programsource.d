/**

This module implements functionality for dealing with a Capsule program's
source map, which is a data structure that can be included in a program
to describe what part of what source file was associated with some given
bytecode or other compiled data that ended up in the program.

*/

module capsule.core.programsource;

private:

import capsule.digest.crc : CRC32;
import capsule.io.file : FileLocation;

public:

/// Enumeration of recognized encodings that may be used when representing
/// a source file.
enum CapsuleProgramSourceEncoding: ushort {
    /// No encoding.
    @("none") None = 0,
    // Source was compressed using the Capsule LZ77 algorithm.
    @("clz77") CapsuleLZ77 = 1,
}

/// Represents a source code file that was used in compiling a
/// Capsule program.
struct CapsuleProgramSource {
    nothrow @safe @nogc:
    
    alias Encoding = CapsuleProgramSourceEncoding;
    alias Location = CapsuleProgramSourceLocation;
    alias Map = CapsuleProgramSourceMap;
    
    /// How the source content was encoded, or None if the content was
    /// not modified in any way.
    Encoding encoding = Encoding.None;
    /// Unused half word.
    ushort unused;
    /// Checksum of the source's name and content, for verifying integrity.
    uint checksum = 0;
    /// Name identifying the source, e.g. a normalized file path.
    string name = null;
    /// The encoded content of the source file.
    string content = null;
    
    /// Get a checksum given a source's name and content.
    static uint getChecksum(A, B)(in A[] name, in B[] content) {
        CRC32 crc;
        crc.put(name);
        crc.put("\0");
        crc.put(content);
        return crc.result;
    }
    
    /// Get the length of the source's encoded content in bytes.
    size_t length() const {
        return this.content.length;
    }
}

/// Associates a span of addresses in a compiled program with a
/// span of indices in one of its source files.
struct CapsuleProgramSourceLocation {
    nothrow @safe @nogc:
    
    /// Index identifying which source file this location refers to.
    uint source = 0;
    /// Location applies starting at this program memory address (inclusive).
    uint startAddress = 0;
    /// Location applies ending at this program memory address (exclusive).
    uint endAddress = 0;
    /// Location is associated with the source file content starting
    /// at this byte index (inclusive).
    uint contentStartIndex = 0;
    /// Location is associated with the source file content ending
    /// at this byte index (exclusive).
    uint contentEndIndex = 0;
    /// Indicates a line number in the source file that is associated
    /// with this location.
    uint contentLineNumber = 0;
    
    /// Get the length in bytes of program memory that this location
    /// applies to.
    uint dataLength() const {
        return this.endAddress - this.startAddress;
    }
    
    /// Get the length in bytes of the source file content that
    /// this location applies to.
    uint contentLength() const {
        return this.contentEndIndex - this.contentStartIndex;
    }
    
    /// Returns true if the location has a start address or an end
    /// address, i.e. if it is meaningful and valid.
    bool opCast(T: bool)() const {
        return this.startAddress > 0 || this.endAddress > 0;
    }
    
    /// Comparison used to order source locations by their starting
    /// address in program memory.
    int opCmp(in typeof(this) location) const {
        return this.startAddress - location.startAddress;
    }
}

/// Data structure that can be used to associate spans of addresses
/// in a compiled program's memory with spans in one or more source
/// code files.
struct CapsuleProgramSourceMap {
    nothrow @safe:
    
    alias Location = CapsuleProgramSourceLocation;
    alias Source = CapsuleProgramSource;
    
    /// The list of sources that have been mapped to memory addresses.
    Source[] sources;
    /// A list of correlations between spans of memory addresses and
    /// spans of text in one of the sources.
    Location[] locations;
    
    /// Get the source content string associated with a given address.
    string getContent(in uint address) @nogc const {
        return this.getContent(this.getLocation(address));
    }
    
    /// Get the source content string associated with a given source location.
    string getContent(in Location location) @nogc const {
        if(location.source >= this.sources.length ||
            location.contentStartIndex >= location.contentEndIndex
        ) {
            return null;
        }
        const source = this.sources[location.source];
        if(location.contentEndIndex > source.length) {
            return null;
        }
        return source.content[
            location.contentStartIndex .. location.contentEndIndex
        ];
    }
    
    /// Get a source location containing the given address, i.e. where its
    /// startAddress is equal to or less than the input address and its
    /// endAddress is greater than the input address.
    Location getLocation(in uint address) @nogc const {
        if(!this.locations.length) {
            return Location.init;
        }
        version(assert) uint i = 0;
        uint low = 0;
        uint high = cast(uint) this.locations.length;
        while(true) {
            const uint mid = low + ((high - low) / 2);
            const location = this.locations[mid];
            if(address >= location.startAddress && address < location.endAddress) {
                return location;
            }
            else if(mid == low) {
                return Location.init;
            }
            else if(location.startAddress > address) {
                high = mid;
            }
            else if(location.startAddress < address) {
                low = mid + 1;
            }
            else {
                return Location.init;
            }
            version(assert) {
                assert(i++ < this.locations.length);
            }
        }
    }
    
    /// Add a new source location to the map.
    auto add(in FileLocation fileLocation, in uint address, in uint length) {
        uint sourceIndex = 0;
        for(; sourceIndex < this.sources.length; sourceIndex++) {
            if(this.sources[sourceIndex].name == fileLocation.file.path) {
                break;
            }
        }
        assert(sourceIndex < this.sources.length);
        const Location location = {
            source: sourceIndex,
            startAddress: address,
            endAddress: address + length,
            contentStartIndex: cast(uint) fileLocation.startIndex,
            contentEndIndex: cast(uint) fileLocation.endIndex,
            contentLineNumber: cast(uint) fileLocation.lineNumber,
        };
        this.locations ~= location;
        return location;
    }
    
    /// Check if the source locations list is sorted in ascending order
    /// of start address, as it is expected to be in order for the
    /// getLocation method's binary search implementation to work.
    bool locationListIsSorted() @nogc const {
        for(size_t i = 1; i < this.locations.length; i++) {
            if(this.locations[i] < this.locations[i - 1]) {
                return false;
            }
        }
        return true;
    }
}

/// Test coverage for CapsuleProgramSourceMap and related types
unittest {
    alias Source = CapsuleProgramSource;
    Source source0 = {
        name: "Source 0",
        content: "abcdefghijklmnopqrstuvwxyz",
    };
    Source source1 = {
        name: "Source 1",
        content: "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
    };
    Source.Location loc0 = {
        source: 0,
        startAddress: 0,
        endAddress: 4,
        contentStartIndex: 0,
        contentEndIndex: 2,
        contentLineNumber: 1,
    };
    Source.Location loc1 = {
        source: 0,
        startAddress: 4,
        endAddress: 16,
        contentStartIndex: 2,
        contentEndIndex: 4,
        contentLineNumber: 1,
    };
    Source.Location loc2 = {
        source: 1,
        startAddress: 32,
        endAddress: 40,
        contentStartIndex: 0,
        contentEndIndex: 4,
        contentLineNumber: 1,
    };
    Source.Location loc3 = {
        source: 1,
        startAddress: 40,
        endAddress: 64,
        contentStartIndex: 4,
        contentEndIndex: 8,
        contentLineNumber: 1,
    };
    Source.Map map = Source.Map(
        [source0, source1],
        [loc0, loc1, loc2, loc3]
    );
    assert(map.locationListIsSorted);
    assert(map.getLocation(0) == loc0);
    assert(map.getLocation(1) == loc0);
    assert(map.getLocation(2) == loc0);
    assert(map.getLocation(3) == loc0);
    assert(map.getLocation(4) == loc1);
    assert(map.getLocation(11) == loc1);
    assert(map.getLocation(15) == loc1);
    assert(!map.getLocation(16));
    assert(!map.getLocation(22));
    assert(!map.getLocation(31));
    assert(map.getLocation(32) == loc2);
    assert(map.getLocation(36) == loc2);
    assert(map.getLocation(39) == loc2);
    assert(map.getLocation(40) == loc3);
    assert(map.getLocation(48) == loc3);
    assert(map.getLocation(50) == loc3);
    assert(map.getLocation(63) == loc3);
    assert(!map.getLocation(64));
    assert(!map.getLocation(128));
    assert(!map.getLocation(int.max));
}
