/**

This module provides a function for determining whether an
integer value represents an exact power of two (isPow2).

*/

module capsule.math.ispow2;

public:

/// Determine whether an integer is a power of two.
bool isPow2(T)(in T value) pure nothrow @safe @nogc {
    return (value & value - 1) ? 0 : 1;
}

/// Tests for isPow2
unittest {
    assert(isPow2(0x0));
    assert(isPow2(0x1));
    assert(isPow2(0x2));
    assert(isPow2(0x4));
    assert(isPow2(0x8));
    assert(isPow2(0x10));
    assert(isPow2(0x100));
    assert(isPow2(0x8000));
    assert(isPow2(0x80000000));
    assert(!isPow2(0x3));
    assert(!isPow2(0x5));
    assert(!isPow2(0xffff));
    assert(!isPow2(0x12345));
    assert(!isPow2(0xffffffff));
}
