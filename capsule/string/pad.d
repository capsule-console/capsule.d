/**

This module provides functionality for padding the start or end of
a string.

*/

module capsule.string.pad;

public:

/// Pad the start of a string with a given element until its length
/// is at least padLength.
auto padLeft(T)(in T[] text, in T padWith, in uint padLength) nothrow @safe {
    if(text.length >= padLength) {
        return text;
    }
    const padCount = padLength - text.length;
    T[] padded = new T[padLength];
    padded[padCount .. $] = text;
    for(uint i = 0; i < padCount; i++) {
        padded[i] = padWith;
    }
    return padded;
}

/// Pad the end of a string with a given element until its length
/// is at least padLength.
auto padRight(T)(in T[] text, in T padWith, in uint padLength) nothrow @safe {
    if(text.length >= padLength) {
        return text;
    }
    const padCount = padLength - text.length;
    T[] padded = new T[padLength];
    padded[0 .. text.length] = text;
    for(uint i = 0; i < padCount; i++) {
        padded[text.length + i] = padWith;
    }
    return padded;
}

/// Tests for padLeft
unittest {
    assert("".padLeft('-', 0) == "");
    assert("".padLeft('-', 4) == "----");
    assert("x".padLeft('-', 0) == "x");
    assert("hi".padLeft('-', 0) == "hi");
    assert("hi".padLeft('-', 4) == "--hi");
    assert("hi".padLeft('-', 8) == "------hi");
    assert("okay".padLeft('-', 4) == "okay");
    assert("hello".padLeft('-', 4) == "hello");
    assert("hello".padLeft('-', 8) == "---hello");
    assert("123".padLeft(' ', 8) == "     123");
    assert("123".padLeft('0', 8) == "00000123");
}

/// Tests for padRight
unittest {
    assert("".padRight('-', 0) == "");
    assert("".padRight('-', 4) == "----");
    assert("x".padRight('-', 0) == "x");
    assert("hi".padRight('-', 0) == "hi");
    assert("hi".padRight('-', 4) == "hi--");
    assert("hi".padRight('-', 8) == "hi------");
    assert("okay".padRight('-', 4) == "okay");
    assert("hello".padRight('-', 4) == "hello");
    assert("hello".padRight('-', 8) == "hello---");
    assert("123".padRight(' ', 8) == "123     ");
    assert("123".padRight('0', 8) == "12300000");
}
