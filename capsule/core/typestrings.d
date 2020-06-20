/**

This module implements functionality related to creating or parsing
string representations of fundamental Capsule data types.

*/

module capsule.core.typestrings;

private:

import capsule.meta.enums : getEnumMemberAttribute;
import capsule.string.ascii : eitherCaseStringEquals;
import capsule.string.hex : CapsuleByteHexStrings, getByteHexString, getHexString;
import capsule.string.writeint : writeInt;

import capsule.core.types : CapsuleInstruction, CapsuleOpcode;

public:

const string CapsuleUnknownExceptionDescription = "Unknown exception";

/// Name srtings corresponding to register numbers.
const string[8] CapsuleRegisterNames = [
    "Z", "A", "B", "C", "R", "S", "X", "Y",
];

/// Brief descriptions corresponding to exception codes.
const string[16] CapsuleExceptionDescriptions = [
    "Missing exception",
    "Triple fault",
    "Double fault",
    "Invalid instruction",
    "Memory location is not executable",
    "Misaligned load",
    "Misaligned store",
    "Misaligned program counter",
    "Out of bounds load",
    "Out of bounds store",
    "Out of bounds program counter",
    "Store to read only memory",
    "Arithmetic overflow",
    "Division by zero",
    "Missing extension",
    "Extension error",
];

/// Get a string representation of an opcode
/// Opcodes without names are represented like `0x00`,
/// where the hexadecimal number is the opcode value.
string getCapsuleOpcodeName(in ubyte opcode) pure nothrow @safe @nogc {
    const name = getEnumMemberAttribute!string(cast(CapsuleOpcode) opcode);
    if(opcode > 0 && name.length > 0) {
        return name;
    }
    else {
        return CapsuleByteHexStrings[opcode];
    }
}

/// Get a string representation of an exception code.
/// Exception codes without names are represented like `0x00`,
/// where the hexadecimal number is the opcode value.
string getCapsuleExceptionName(in ubyte exception) pure nothrow @safe @nogc {
    const name = getEnumMemberAttribute!string(cast(CapsuleException) exception);
    if(exception > 0 && name.length > 0) {
        return name;
    }
    else {
        return CapsuleByteHexStrings[exception];
    }
}

/// Get the Capsule opcode matching a given name string.
/// Returns CapsuleOpcode.None when there was no match.
CapsuleOpcode getCapsuleOpcodeWithName(T)(
    in T[] name
) pure nothrow @safe @nogc {
    foreach(member; __traits(allMembers, CapsuleOpcode)) {
        static assert(member.length);
        enum type = __traits(getMember, CapsuleOpcode, member);
        const typeName = getEnumMemberAttribute!string(type);
        if(eitherCaseStringEquals(name, typeName)) {
            return type;
        }
    }
    return CapsuleOpcode.None;
}

/// Get a string representation of a register.
/// Triggers an assertion error for an invalid register number.
string getCapsuleRegisterName(in ubyte register) pure nothrow @safe @nogc {
    assert(register < 8);
    return CapsuleRegisterNames[register & 0x7];
}

/// Get a string containing a brief description of an exception code.
/// Unknown exception codes are identified as such.
string getCapsuleExceptionDescription(
    in ubyte exception
) pure nothrow @safe @nogc {
    if(exception < CapsuleExceptionDescriptions.length) {
        return CapsuleExceptionDescriptions[exception];
    }
    else {
        return CapsuleUnknownExceptionDescription;
    }
}

/// Given a single-character register name (e.g. 'A', 'Z', 'r', 's')
/// get the register index associated with that name.
int getCapsuleRegisterIndex(in char name) pure nothrow @safe @nogc {
    switch(name) {
        case 'z': goto case;
        case 'Z': return 0;
        case 'a': goto case;
        case 'A': return 1;
        case 'b': goto case;
        case 'B': return 2;
        case 'c': goto case;
        case 'C': return 3;
        case 'r': goto case;
        case 'R': return 4;
        case 's': goto case;
        case 'S': return 5;
        case 'x': goto case;
        case 'X': return 6;
        case 'y': goto case;
        case 'Y': return 7;
        default: return -1;
    }
}
