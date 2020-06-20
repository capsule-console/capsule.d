/**

This module implements a count trailing zeroes function (ctz).

https://en.wikipedia.org/wiki/Find_first_set

*/

module capsule.bits.ctz;

public:

/// Count trailing zeroes
uint ctz(in uint value) pure nothrow @safe @nogc {
    if(value == 0) {
        return 32;
    }
    uint i = 0;
    uint x = value;
    if((x & 0x0000FFFF) == 0) {
        i += 16;
        x >>= 16;
    }
    if((x & 0x000000FF) == 0) {
        i += 8;
        x >>= 8;
    }
    if((x & 0x0000000F) == 0) {
        i += 4;
        x >>= 4;
    }
    if((x & 0x00000003) == 0) {
        i += 2;
        x >>= 2;
    }
    if((x & 0x00000001) == 0) {
        i += 1;
    }
    return i;
}

/// Tests for ctz (count trailing zeroes)
unittest {
    assert(ctz(0x00000000) == 32);
    assert(ctz(0x80000000) == 31);
    assert(ctz(0x11100000) == 20);
    assert(ctz(0x00010000) == 16);
    assert(ctz(0x0003C000) == 14);
    assert(ctz(0xFFFFF000) == 12);
    assert(ctz(0xFFFFF800) == 11);
    assert(ctz(0xFFFFFC00) == 10);
    assert(ctz(0xFFFFFE00) == 9);
    assert(ctz(0x00000008) == 3);
    assert(ctz(0x00000002) == 1);
    assert(ctz(0x00000001) == 0);
    assert(ctz(0xFFFFFFFF) == 0);
}
