module capsule.core.typestrings;

import capsule.string.ascii : eitherCaseStringEquals;
import capsule.meta.enums : getEnumMemberAttribute;
import capsule.string.hex : CapsuleByteHexStrings, getByteHexString, getHexString;
import capsule.core.types : CapsuleInstruction, CapsuleOpcode;
import capsule.string.writeint : writeInt;

public pure nothrow @safe:

const string CapsuleUnknownExceptionDescription = "Unknown exception";

/// Names corresponding to register numbers
const string[8] CapsuleRegisterNames = [
    "Z", "A", "B", "C", "R", "S", "X", "Y",
];

/// Names corresponding to exception codes
const string[16] CapsuleExceptionNames = [
    "enone",
    "etriple",
    "edouble",
    "einstr",
    "ebreak",
    "elmis",
    "esmis",
    "epcmis",
    "elbounds",
    "esbounds",
    "epcbounds",
    "esro",
    "eovf",
    "edivz",
    "eextmiss",
    "eexterr",
];

/// Brief descriptions corresponding to exception codes
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
/// Opcodes without names are represented like `0x00`
/// where the hexadecimal number is the opcode value.
string getCapsuleOpcodeName(in ubyte opcode) @nogc {
    const name = getEnumMemberAttribute!string(cast(CapsuleOpcode) opcode);
    if(opcode > 0 && name.length > 0) {
        return name;
    }
    else {
        return CapsuleByteHexStrings[opcode];
    }
}

CapsuleOpcode getCapsuleOpcodeWithName(T)(in T[] name) {
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
string getCapsuleRegisterName(in ubyte register) @nogc {
    assert(register < 8);
    return CapsuleRegisterNames[register & 0x7];
}

/// Get a string representation of an exception code.
/// Exception codes without names are represented like `0x00`
/// where the hexadecimal number is the opcode value.
string getCapsuleExceptionName(in ubyte exception) @nogc {
    if(exception < CapsuleExceptionNames.length) {
        return CapsuleExceptionNames[exception];
    }
    else {
        return CapsuleByteHexStrings[exception];
    }
}

/// Get a string containing a brief description of an exception code.
/// Unknown exception codes are identified as such.
string getCapsuleExceptionDescription(in ubyte exception) @nogc {
    if(exception < CapsuleExceptionDescriptions.length) {
        return CapsuleExceptionDescriptions[exception];
    }
    else {
        return CapsuleUnknownExceptionDescription;
    }
}

int getCapsuleRegisterIndex(in char name) @nogc {
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
