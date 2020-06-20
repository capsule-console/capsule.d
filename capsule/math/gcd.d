/**

This module implements a function for computing the greatest
common denominator of two integers (gcd) or the least common
mulitple (lcm).

https://en.wikipedia.org/wiki/Greatest_common_divisor

https://en.wikipedia.org/wiki/Least_common_multiple

*/

module capsule.math.gcd;

public:

/// Get the greatest common divisor of two values.
uint gcd(in uint x, in uint y) pure nothrow @safe @nogc {
    uint a = x;
    uint b = y;
    while(b != 0) {
        uint t = b;
        b = a % b;
        a = t;
    }
    return a;
}

/// Get the least common multiple of two values.
uint lcm(in uint x, in uint y) pure nothrow @safe @nogc {
    return (x * y) / gcd(x, y);
}

/// Tests for gcd and lcm
unittest {
    assert(gcd(8, 4) == 4);
    assert(gcd(7, 11) == 1);
    assert(gcd(9, 6) == 3);
    assert(lcm(5, 10) == 10);
    assert(lcm(15, 10) == 30);
}
