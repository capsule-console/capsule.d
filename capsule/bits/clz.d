/**

This module implements a count leading zeroes function (clz).

https://en.wikipedia.org/wiki/Find_first_set

*/

module capsule.bits.clz;

public:

/// Count leading zeroes
uint clz(in uint value) pure nothrow @safe @nogc {
    if(value == 0) {
        return 32;
    }
    uint i = 0;
    uint x = value;
    if((x & 0xFFFF0000) == 0) {
        i += 16;
        x <<= 16;
    }
    if((x & 0xFF000000) == 0) {
        i += 8;
        x <<= 8;
    }
    if((x & 0xF0000000) == 0) {
        i += 4;
        x <<= 4;
    }
    if((x & 0xC0000000) == 0) {
        i += 2;
        x <<= 2;
    }
    if((x & 0x80000000) == 0) {
        i += 1;
    }
    return i;
}

/// Tests for clz (count leading zeroes)
unittest {
    assert(clz(0x00000000) == 32);
    assert(clz(0x00000001) == 31);
    assert(clz(0x000007FF) == 21);
    assert(clz(0x00000FFF) == 20);
    assert(clz(0x00008000) == 16);
    assert(clz(0x00038000) == 14);
    assert(clz(0x03FFFFFF) == 6);
    assert(clz(0x10000000) == 3);
    assert(clz(0x30000000) == 2);
    assert(clz(0x75555555) == 1);
    assert(clz(0x80000000) == 0);
    assert(clz(0xFFFFFFFF) == 0);
}
