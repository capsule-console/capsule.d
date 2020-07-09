/**

This module defines types and functions related to Capsule exceptions
and exception codes.

*/

module capsule.core.exception;

private:

import capsule.meta.enums : getEnumMemberAttribute;

public:

/// Description to provide for unknown exception codes.    
shared immutable string CapsuleUnknownExceptionDescription = "Unknown exception";

/// Table of exception code description strings.
shared immutable string[16] CapsuleExceptionDescriptions = [
    "No exception",
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

/// Enumeration of Capsule exception codes
enum CapsuleExceptionCode: ubyte {
    @("none") None = 0x00, /// No exception or missing exception
    @("triple") TripleFault = 0x01, /// Triple fault
    @("double") DoubleFault = 0x02, /// Double fault
    @("instr") InvalidInstruction = 0x03, /// Invalid instruction
    @("pcexec") PCNotExecutable = 0x04, /// Program counter not in executable memory
    @("lalign") LoadMisaligned = 0x05, /// Misaligned load
    @("salign") StoreMisaligned = 0x06, /// Misaligned store
    @("pcalign") PCMisaligned = 0x07, /// Misaligned program counter
    @("lbounds") LoadOutOfBounds = 0x08, /// Out-of-bounds load
    @("sbounds") StoreOutOfBounds = 0x09, /// Out-of-bounds store
    @("pcbounds") PCOutOfBounds = 0x0a, /// Out-of-bounds program counter
    @("sro") StoreToReadOnly = 0x0b, /// Store to read-only memory address
    @("ovf") ArithmeticOverflow = 0x0c, /// Arithmetic overflow or underflow
    @("divz") DivideByZero = 0x0d, /// Arithmetic divide by zero
    @("extmiss") ExtensionMissing = 0x0e, /// Unknown or unsupported extension
    @("exterr") ExtensionError = 0x0f, /// Error occured during extension call
}

/// Get the name string associated with an exception code.
/// Returns null for unnamed or unrecognized exception codes.
string getCapsuleExceptionName(in ubyte exception) pure nothrow @safe @nogc {
    return getEnumMemberAttribute!string(cast(CapsuleExceptionCode) exception);
}

/// Get the description string associated with an exception code.
/// Returns a special "unknown" description text for exception codes
/// without any other description available.
string getCapsuleExceptionDescription(in ubyte exception) pure nothrow @safe @nogc {
    if(exception < CapsuleExceptionDescriptions.length) {
        return CapsuleExceptionDescriptions[exception];
    }
    else {
        return CapsuleUnknownExceptionDescription;
    }
}
