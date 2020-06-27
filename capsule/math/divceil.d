/**

This module implements a function for getting the quotient from an
integer division operation, rounded up.

*/

module capsule.math.divceil;

public:

/// Get the rounded-up quotient from an integer division operation.
T divceil(T)(in T dividend, in T divisor) pure nothrow @safe @nogc {
    assert(divisor != 0);
    const q = dividend / divisor;
    const r = dividend % divisor;
    return q + (r ? 1 : 0);
}

/// Test coverage for divceil
unittest {
    assert(divceil(0, 1) == 0);
    assert(divceil(0, 5000) == 0);
    assert(divceil(1, 1) == 1);
    assert(divceil(100, 1) == 100);
    assert(divceil(1, 2) == 1);
    assert(divceil(50, 2) == 25);
    assert(divceil(10, 4) == 3);
    assert(divceil(500, 30) == 17);
    assert(divceil(1000, 10) == 100);
    assert(divceil(1001, 10) == 101);
    assert(divceil(1002, 10) == 101);
    assert(divceil(1009, 10) == 101);
    assert(divceil(1010, 10) == 101);
    assert(divceil(1011, 10) == 102);
}
