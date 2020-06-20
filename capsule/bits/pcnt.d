/**

This module implements a population count function (pcnt), also called
a "count set bits" function. This is also equivalent to calculating the
Hamming weight of a binary number.

https://en.wikichip.org/wiki/population_count

https://en.wikipedia.org/wiki/Hamming_weight

*/

module capsule.bits.pcnt;

public:

/// Count set bits, AKA population count.
/// http://cs-fundamentals.com/tech-interview/c/c-program-to-count-number-of-ones-in-unsigned-integer.php
uint pcnt(in uint value) pure nothrow @safe @nogc {
    uint x = cast(uint) value;
    x = x - ((x >> 1) & 0x55555555);
    x = (x & 0x33333333) + ((x >> 2) & 0x33333333);
    x = (x + (x >> 4)) & 0x0F0F0F0F;
    x = x + (x >> 8);
    x = x + (x >> 16);
    return x & 0x0000003F;
}

/// Tests for pcnt (count set bits/population count)
unittest {
    assert(pcnt(0xFFFFFFFF) == 32);
    assert(pcnt(0x7FFFFFFF) == 31);
    assert(pcnt(0xFF7FFFFF) == 31);
    assert(pcnt(0xFFF7FFFF) == 31);
    assert(pcnt(0xFFFFFFF7) == 31);
    assert(pcnt(0x7FFF7FFF) == 30);
    assert(pcnt(0x3FFFFFFF) == 30);
    assert(pcnt(0x7FFF7F7F) == 29);
    assert(pcnt(0x3F7FFFFF) == 29);
    assert(pcnt(0xFFFFF1FF) == 29);
    assert(pcnt(0xFFFFF0FF) == 28);
    assert(pcnt(0xFFFFFFF0) == 28);
    assert(pcnt(0x7FFFFFF0) == 27);
    assert(pcnt(0xFFF3F3F3) == 26);
    assert(pcnt(0x0000FFFF) == 16);
    assert(pcnt(0x00FF00FF) == 16);
    assert(pcnt(0x00000020) == 1);
    assert(pcnt(0x04000000) == 1);
    assert(pcnt(0x00008000) == 1);
    assert(pcnt(0x10000000) == 1);
    assert(pcnt(0x00100000) == 1);
    assert(pcnt(0x00000100) == 1);
    assert(pcnt(0x00000001) == 1);
    assert(pcnt(0x00000000) == 0);
}
