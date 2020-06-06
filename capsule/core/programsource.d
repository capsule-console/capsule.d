module capsule.core.programsource;

import capsule.core.crc : CRC32;
import capsule.core.file : FileLocation;

public:

enum CapsuleProgramSourceEncoding: ushort {
    @("none") None = 0,
    @("clz77") CapsuleLZ77 = 1,
}

struct CapsuleProgramSource {
    alias Encoding = CapsuleProgramSourceEncoding;
    alias Location = CapsuleProgramSourceLocation;
    alias Map = CapsuleProgramSourceMap;
    
    Encoding encoding = Encoding.None;
    ushort unused;
    uint checksum = 0;
    string name = null;
    string content = null;
    
    static uint getChecksum(A, B)(in A[] name, in B[] content) {
        CRC32 crc;
        crc.put(name);
        crc.put("\0");
        crc.put(content);
        return crc.result;
    }
    
    size_t length() const {
        return this.content.length;
    }
}

struct CapsuleProgramSourceLocation {
    uint source = 0;
    uint startAddress = 0;
    uint endAddress = 0;
    uint contentStartIndex = 0;
    uint contentEndIndex = 0;
    uint contentLineNumber = 0;
    
    uint dataLength() const {
        return this.endAddress - this.startAddress;
    }
    
    uint contentLength() const {
        return this.contentEndIndex - this.contentStartIndex;
    }
    
    bool opCast(T: bool)() const {
        return this.startAddress || this.endAddress;
    }
}

struct CapsuleProgramSourceMap {
    alias Location = CapsuleProgramSourceLocation;
    alias Source = CapsuleProgramSource;
    
    Source[] sources;
    Location[] locations;
    
    string getContent(in uint address) const {
        return this.getContent(this.getLocation(address));
    }
    
    string getContent(in Location location) const {
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
    
    Location getLocation(in uint address) const {
        if(!this.locations.length) {
            return Location.init;
        }
        uint low = 0;
        uint high = cast(uint) this.locations.length;
        version(assert) uint i = 0;
        while(true) {
            const uint mid = low + ((high - low) / 2);
            const location = this.locations[mid];
            if(address >= location.startAddress && address < location.endAddress) {
                return location;
            }
            else if(low + 1 >= high) {
                return Location.init;
            }
            else if(location.startAddress > address) {
                high = mid;
            }
            else if(location.endAddress < address) {
                low = mid + 1;
            }
            version(assert) {
                if(i++ >= this.locations.length) assert(false);
            }
        }
    }
    
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
    
    //void sort() {
    //    sort!((a, b) => (a.startAddress < b.startAddress))(this.locations);
    //}
}
