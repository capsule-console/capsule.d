/**

This module defines types related to the registers recognized in
Capsule bytecode instructions.

*/

module capsule.core.register;

private:

import capsule.algorithm.indexof : indexOf;

public:

alias CapsuleRegisterNames = CapsuleRegisterCanonicalNames;

/// List of canonical register names. (Z, A, B, C, R, S, X, Y)
shared immutable string[8] CapsuleRegisterCanonicalNames = [
    "Z", "A", "B", "C", "R", "S", "X", "Y",
];

/// List of lower-cased canonical register names. (z, a, b, c, r, s, x, y)
shared immutable string[8] CapsuleRegisterLowerCanonicalNames = [
    "z", "a", "b", "c", "r", "s", "x", "y",
];

/// List of upper-case numbered register names. (R0, ..., R7)
shared immutable string[8] CapsuleRegisterUpperNumericNames = [
    "R0", "R1", "R2", "R3", "R4", "R5", "R6", "R7",
];

/// List of lower-case numbered register names. (r0, ..., r7)
shared immutable string[8] CapsuleRegisterLowerNumericNames = [
    "r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7",
];

/// Enumeration of Capsule registers
enum CapsuleRegister: ubyte {
    /// Hard-wired zero
    Z = 0x0,
    /// Accumulator or function return value by convention
    A = 0x1,
    /// Stack frame pointer by convention
    B = 0x2,
    /// Counter or function argument by convention
    C = 0x3,
    /// Return address by convention
    R = 0x4,
    /// Stack pointer by convention
    S = 0x5,
    /// Temporary register by convention
    X = 0x6,
    /// Temporary register by convention
    Y = 0x7,
}

enum CapsuleRegisterParameter: int {
    None = -1,
    Destination = 0, /// rd
    FirstSource = 1, /// rs1
    SecondSource = 2, /// rs2
}

/// Get a the canonical name string associated with a given register index.
/// The canonical name strings are: Z, A, B, C, R, S, X, Y.
string getCapsuleRegisterName(in ubyte register) pure nothrow @safe @nogc {
    assert(register < CapsuleRegisterCanonicalNames.length);
    return CapsuleRegisterCanonicalNames[register & 0x7];
}

/// Parse a register name string. Returns the index of the associated
/// register, or -1 if the name did not identify any valid register.
int getCapsuleRegisterWithName(in string name) pure nothrow @safe @nogc {
    if(!name.length || name.length > 2) {
        return -1;
    }
    else if(name.length == 1) {
        if(name[0] >= 'a' && name[0] <= 'z') {
            return cast(int) indexOf(CapsuleRegisterLowerCanonicalNames, name);
        }
        else {
            return cast(int) indexOf(CapsuleRegisterCanonicalNames, name);
        }
    }
    else {
        assert(name.length == 2);
        if(name[0] == 'r') {
            return cast(int) indexOf(CapsuleRegisterLowerNumericNames, name);
        }
        else if(name[0] == 'R') {
            return cast(int) indexOf(CapsuleRegisterUpperNumericNames, name);
        }
        else {
            return -1;
        }
    }
}
