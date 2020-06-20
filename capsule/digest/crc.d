/**

This module provides functions for computing the CRC, or cyclic
redudancy check, of some data. A CRC is commonly used as a
checksum for ensuring data integrity.

The module implements both CRC-32 and CRC-64 checksums.

https://en.wikipedia.org/wiki/Cyclic_redundancy_check

*/

module capsule.digest.crc;

public:

enum ulong CRC32Polynomial = 0xedb88320;
enum ulong CRC64ISOPolynomial = 0xd800000000000000;
enum ulong CRC64EMCAPolynomial = 0xc96c5795d7870f42;

alias CRC32 = CRC!(uint, CRC32Polynomial);

alias CRC64 = CRC64EMCA;

alias CRC64ISO = CRC!(ulong, CRC64ISOPolynomial);

alias CRC64EMCA = CRC!(ulong, CRC64EMCAPolynomial);

auto makeCRCTables(T)(in T poly) nothrow pure @safe @nogc {
    T[256][8] tables;
    for(size_t i = 0; i < 256; i++) {
        T crc = cast(T) i;
        for(size_t j = 0; j < 8; j++) {
            crc = (crc >> 1) ^ (-int(crc & 1) & poly);
        }
        tables[0][i] = crc;
    }
    for(size_t i = 0; i < 256; i++) {
        tables[1][i] = (tables[0][i] >> 8) ^ tables[0][tables[0][i] & 0xff];
        tables[2][i] = (tables[1][i] >> 8) ^ tables[0][tables[1][i] & 0xff];
        tables[3][i] = (tables[2][i] >> 8) ^ tables[0][tables[2][i] & 0xff];
        tables[4][i] = (tables[3][i] >> 8) ^ tables[0][tables[3][i] & 0xff];
        tables[5][i] = (tables[4][i] >> 8) ^ tables[0][tables[4][i] & 0xff];
        tables[6][i] = (tables[5][i] >> 8) ^ tables[0][tables[5][i] & 0xff];
        tables[7][i] = (tables[6][i] >> 8) ^ tables[0][tables[6][i] & 0xff];
    }
    return tables;
}

/// https://en.wikipedia.org/wiki/Cyclic_redundancy_check
/// https://golang.org/src/hash/crc64/crc64.go
/// https://github.com/dlang/phobos/blob/master/std/digest/crc.d
// https://github.com/zhoulihe/crc8/blob/master/CRC8-16-32-64/CRC16-32-64/crc64.h
/// https://emn178.github.io/online-tools/crc32_checksum.html
/// https://crc64.online/
struct CRC(T, ulong poly) {
    nothrow pure @safe @nogc:
    
    static assert(is(T == uint) || is(T == ulong), "Wrong CRC data type.");
    
    static const Tables = makeCRCTables(cast(T) poly);
    
    T state = T.max;
    
    static T get(C)(in C[] data) {
        typeof(this) crc;
        crc.put(data);
        return crc.result;
    }
    
    void reset() {
        this.state = 0;
    }
    
    T result() {
        return ~this.state;
    }
    
    void put(C)(in C[] data) {
        const ubyte[] bytes = cast(const ubyte[]) data;
        size_t offset = 0;
        while(offset + 8 < bytes.length) {
            uint one = (
                (cast(uint) bytes[offset + 0]) |
                (cast(uint) bytes[offset + 2] << 16) |
                (cast(uint) bytes[offset + 1] << 8) |
                (cast(uint) bytes[offset + 3] << 24)
            );
            uint two = (
                (cast(uint) bytes[offset + 4]) |
                (cast(uint) bytes[offset + 6] << 16) |
                (cast(uint) bytes[offset + 5] << 8) |
                (cast(uint) bytes[offset + 7] << 24)
            );
            static if(T.sizeof == 4) {
                one ^= this.state;
            }
            else static if(T.sizeof == 8) {
                one ^= cast(uint) this.state;
                two ^= cast(uint) (this.state >> 32);
            }
            else {
                static assert(false);
            }
            this.state = (
                Tables[0][(two >> 24)] ^
                Tables[1][(two >> 16) & 0xff] ^
                Tables[2][(two >> 8) & 0xff] ^
                Tables[3][(two & 0xFF)] ^
                Tables[4][(one >> 24)] ^
                Tables[5][(one >> 16) & 0xff] ^
                Tables[6][(one >> 8) & 0xff] ^
                Tables[7][(one & 0xFF)]
            );
            offset += 8;
        }
        while(offset < bytes.length) {
            const ch = cast(ubyte) bytes[offset];
            this.state = (this.state >> 8) ^ Tables[0][cast(ubyte) this.state ^ ch];
            offset++;
        }
    }
}

/// Test coverage for CRC functions
unittest {
    assert(CRC32.get("") == 0);
    assert(CRC32.get("argh") == 0x9c7ee74e);
    assert(CRC64ISO.get("argh") == 0x3821adc420000000);
    assert(CRC64EMCA.get("argh") == 0xa49e6f48fa3fb9e4);
    assert(CRC32.get("hello world") == 0x0d4a1185);
    assert(CRC64ISO.get("hello world") == 0xb9cf3f572ad9ac3e);
    assert(CRC64EMCA.get("hello world") == 0x53037ecdef2352da);
    assert(CRC32.get("hello again world") == 0x89fe337a);
    assert(CRC64ISO.get("hello again world") == 0x4118ee41ffbc0728);
    assert(CRC64EMCA.get("hello again world") == 0xe6fbd69c0b5b25de);
}
