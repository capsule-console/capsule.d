/**

This module implements min and max functions for getting the
lesser or greater of two values.

*/

module capsule.math.minmax;

public pure nothrow @safe @nogc:

/// Get the maximum of two values.
int min(T)(in T x, in T y) {
    return x < y ? x : y;
}

/// Get the minimum of two values.
int max(T)(in T x, in T y) {
    return x > y ? x : y;
}

/// Test coverage for min and max
unittest {
    assert(min(0, 1) == 0);
    assert(min(1, 0) == 0);
    assert(max(0, 1) == 1);
    assert(max(1, 0) == 1);
}
