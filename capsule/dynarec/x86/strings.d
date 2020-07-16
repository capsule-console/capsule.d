module capsule.dynarec.x86.strings;

private:

import capsule.dynarec.x86.instruction : X86Instruction;
import capsule.dynarec.x86.opcode : X86Opcode;
import capsule.dynarec.x86.opcode : X86OpcodeOperandTypeSize;
import capsule.dynarec.x86.register : X86Register, X86SegmentRegister;
import capsule.dynarec.x86.size : X86DataSize;

public pure nothrow @safe:

alias X86ToString = X86IntToString;
alias X86ToString = X86DataSizeToString;
alias X86ToString = X86RegisterToString;
alias X86ToString = X86SegmentRegisterToString;
alias X86ToString = X86OpcodeOperandTypeToString;
alias X86ToString = X86OpcodeToString;
alias X86ToString = X86InstructionMemoryAddressToString;
alias X86ToString = X86InstructionOperandToString;
alias X86ToString = X86InstructionToString;

/// Get a hexadecimal string representing a given integer value.
string X86IntToString(T)(in uint size, in T value) {
    static enum HexDigits = "0123456789abcdef";
    string hex = null;
    for(uint i = size; i > 0; i -= 4) {
        hex ~= HexDigits[(value >> (i - 4)) & 0xf];
    }
    return hex;
}

/// Get a string representation of a data size.
/// For example: "byte", "word", "dword", "qword"
string X86DataSizeToString(in X86DataSize size) @nogc {
    final switch(size) {
        case X86DataSize.None: return null;
        case X86DataSize.Byte: return "byte";
        case X86DataSize.Word: return "word";
        case X86DataSize.DWord: return "dword";
        case X86DataSize.QWord: return "qword";
    }
}

/// Get a string containing the name of a general-purpose register.
/// For example: "al", "ah", "ax", "eax", "rax", "ecx", "r10"
string X86RegisterToString(in X86Register register) @nogc {
    foreach(member; __traits(allMembers, X86Register)) {
        if(register == __traits(getMember, X86Register, member)) {
            return member;
        }
    }
    return null;
}

/// Get a string containing the name of a segment register.
/// For example: "cs", "ds", "ss", "es", "fs", "gs"
string X86SegmentRegisterToString(in X86SegmentRegister register) @nogc {
    foreach(member; __traits(allMembers, X86SegmentRegister)) {
        if(register == __traits(getMember, X86SegmentRegister, member)) {
            return member;
        }
    }
    return null;
}

/// Get a string representation of an opcode operand type.
/// For example: "r8", "r16", "r32", "r/m16", "imm32", "rel32"
string X86OpcodeOperandTypeToString(in X86Opcode.OperandType operandType) {
    assert(operandType < X86OpcodeOperandTypeStrings.length);
    return X86OpcodeOperandTypeStrings[cast(uint) operandType];
}

/// Get a string representation of an opcode entry.
/// For example: "add r32, r/m32", "xor eax, imm32"
string X86OpcodeToString(in X86Opcode opcode) {
    string text = "";
    foreach(operand; opcode.operands) {
        if(operand !is X86Opcode.OperandType.None) {
            if(text.length && text[$ - 1] != ':') text ~= ", ";
            text ~= X86OpcodeOperandTypeToString(operand);
        }
    }
    return opcode.name ~ " " ~ text;
}

/// Get a string representation of a memory address operand.
/// For example: "byte ptr [ecx + edi]", "dword ptr [rip + 0x11223344]"
string X86InstructionMemoryAddressToString(
    in X86DataSize size, in X86Instruction.MemoryAddressData memoryAddress
) {
    alias MemoryMode = X86Instruction.MemoryAddressData.Mode;
    const string sizeString = X86DataSizeToString(size);
    static string signedDisplacementToString(in uint size, in int displacement) {
        const sign = displacement < 0;
        const absDisplacement = (sign ? -displacement : displacement);
        return (sign ? " - " : " + ") ~ (
            "0x" ~ X86IntToString(32, absDisplacement)
        );
    }
    if(memoryAddress.mode is MemoryMode.base || (
        memoryAddress.displacement == 0 && (
            memoryAddress.mode is MemoryMode.base_disp8 ||
            memoryAddress.mode is MemoryMode.base_disp32
        )
    )) {
        return (sizeString ~ " ptr [" ~ 
            X86RegisterToString(memoryAddress.base) ~
        "]");
    }
    else if(memoryAddress.mode is MemoryMode.base_index || (
        memoryAddress.displacement == 0 && (
            memoryAddress.mode is MemoryMode.base_index_disp8 ||
            memoryAddress.mode is MemoryMode.base_index_disp32
        )
    )) {
        return (sizeString ~ " ptr [" ~
            X86RegisterToString(memoryAddress.base) ~ " + " ~
            X86RegisterToString(memoryAddress.index) ~ (
                memoryAddress.scale == 0 ? "" :
                " * " ~ X86IntToString(4, memoryAddress.getScaleValue)
            ) ~
        "]");
    }
    else if(memoryAddress.mode is MemoryMode.disp32) {
        return (sizeString ~ " ptr [" ~
            "0x" ~ X86IntToString(32, memoryAddress.displacement) ~ 
        "]");
    }
    else if(memoryAddress.mode is MemoryMode.base_disp32) {
        return (sizeString ~ " ptr [" ~
            X86RegisterToString(memoryAddress.base) ~
            signedDisplacementToString(32, memoryAddress.displacement) ~
        "]");
    }
    else if(memoryAddress.mode is MemoryMode.index_disp32) {
        return (sizeString ~ " ptr [" ~
            X86RegisterToString(memoryAddress.index) ~ (
                memoryAddress.scale == 0 ? "" :
                " * " ~ X86IntToString(4, memoryAddress.getScaleValue)
            ) ~ (
                memoryAddress.displacement == 0 ? "" :
                signedDisplacementToString(32, memoryAddress.displacement)
            ) ~
        "]");
    }
    else if(memoryAddress.mode is MemoryMode.base_index_disp32) {
        return (sizeString ~ " ptr [" ~
            X86RegisterToString(memoryAddress.base) ~ " + " ~
            X86RegisterToString(memoryAddress.index) ~ (
                memoryAddress.scale == 0 ? "" :
                " * " ~ X86IntToString(4, memoryAddress.getScaleValue)
            ) ~
            signedDisplacementToString(32, memoryAddress.displacement) ~
        "]");
    }
    else if(memoryAddress.mode is MemoryMode.base_disp8) {
        return (sizeString ~ " ptr [" ~
            X86RegisterToString(memoryAddress.base) ~
            signedDisplacementToString(8, memoryAddress.displacement) ~
        "]");
    }
    else if(memoryAddress.mode is MemoryMode.base_index_disp8) {
        return (sizeString ~ " ptr [" ~
            X86RegisterToString(memoryAddress.base) ~ " + " ~
            X86RegisterToString(memoryAddress.index) ~ (
                memoryAddress.scale == 0 ? "" :
                " * " ~ X86IntToString(4, memoryAddress.getScaleValue)
            ) ~
            signedDisplacementToString(8, memoryAddress.displacement) ~
        "]");
    }
    else if(memoryAddress.mode is MemoryMode.rip_disp32) {
        return (sizeString ~ " ptr [rip" ~
            signedDisplacementToString(32, memoryAddress.displacement) ~
        "]");
    }
    else {
        return null;
    }
}

/// Get a string representation of an operand that can be passed
/// as an argument to an instruction.
/// For example: "eax", "cs", "0x11223344", "dword ptr [esi]"
string X86InstructionOperandToString(in X86Instruction.Operand operand) {
    alias Operand = X86Instruction.Operand;
    if(operand.type is Operand.Type.Register) {
        return X86RegisterToString(operand.register);
    }
    else if(operand.type is Operand.Type.SegmentRegister) {
        return X86SegmentRegisterToString(operand.segmentRegister);
    }
    else if(operand.type is Operand.Type.Immediate) {
        return "0x" ~ X86IntToString(operand.size, operand.immediate);
    }
    else if(operand.type is Operand.Type.Relative) {
        return ". + 0x" ~ X86IntToString(operand.size, operand.immediate);
    }
    else if(operand.type is Operand.Type.MemoryAddress) {
        return X86InstructionMemoryAddressToString(
            operand.size, operand.memoryAddress
        );
    }
    else {
        return null;
    }
}

/// Get a string representation of one of an instruction's actual operands.
/// For example: "eax", "cs", "0x11223344", "dword ptr [esi]"
string X86InstructionOperandToString(
    in X86Instruction instruction, in X86Opcode.OperandType operandType
) {
    alias OperandType = X86Opcode.OperandType;
    alias RMOperandType = X86Instruction.RMOperandType;
    final switch(operandType) {
        case OperandType.None: return null;
        case OperandType.al: return "al";
        case OperandType.ax: return "ax";
        case OperandType.eax: return "eax";
        case OperandType.rax: return "rax";
        case OperandType.cl: return "cl";
        case OperandType.cs: return "cs";
        case OperandType.ss: return "ss";
        case OperandType.ds: return "ds";
        case OperandType.es: return "es";
        case OperandType.fs: return "fs";
        case OperandType.gs: return "gs";
        case OperandType.lit1: return "1";
        case OperandType.sreg:
            return X86SegmentRegisterToString(instruction.segmentRegister);
        case OperandType.r8: goto case;
        case OperandType.r16: goto case;
        case OperandType.r32: goto case;
        case OperandType.r64:
            return X86RegisterToString(instruction.register);
        case OperandType.rm8: goto case;
        case OperandType.rm16: goto case;
        case OperandType.rm32: goto case;
        case OperandType.rm64: goto case;
        case OperandType.rm_r8: goto case;
        case OperandType.rm_r16: goto case;
        case OperandType.rm_r32: goto case;
        case OperandType.rm_r64: goto case;
        case OperandType.m16_16: goto case;
        case OperandType.m16_32: goto case;
        case OperandType.m16_64:
            if(instruction.rmOperandType is RMOperandType.Register) {
                return X86RegisterToString(instruction.rmRegister);
            }
            else if(instruction.rmOperandType is RMOperandType.MemoryAddress) {
                return X86InstructionMemoryAddressToString(
                    instruction.getRMSize, instruction.rmMemoryAddress
                );
            }
            else {
                return null;
            }
        case OperandType.moffs8: goto case;
        case OperandType.moffs16: goto case;
        case OperandType.moffs32: goto case;
        case OperandType.moffs64:
            return (
                X86SegmentRegisterToString(instruction.segmentRegister) ~
                ":[0x" ~X86IntToString(32, instruction.farSegmentImmediate) ~ "]"
            );
        case OperandType.imm8: goto case;
        case OperandType.imm16: goto case;
        case OperandType.imm32: goto case;
        case OperandType.imm64: goto case;
        case OperandType.far16: goto case;
        case OperandType.far32: goto case;
        case OperandType.far64:
            return "0x" ~ X86IntToString(
                X86OpcodeOperandTypeSize(operandType), instruction.immediate
            );
        case OperandType.rel8: goto case;
        case OperandType.rel16: goto case;
        case OperandType.rel32: goto case;
        case OperandType.rel64:
            return ". + 0x" ~ X86IntToString(
                X86OpcodeOperandTypeSize(operandType), instruction.immediate
            );
        case OperandType.farseg16:
            if(instruction.rmOperandType is RMOperandType.FarSegmentImmediate) {
                return "0x" ~ X86IntToString(16, instruction.farSegmentImmediate);
            }
            else {
                return null;
            }
    }
}

/// Get a string representation of an instruction.
/// For example: "add ax, 0x1234", "mov eax, [ecx]"
string X86InstructionToString(in X86Instruction instruction) {
    alias OperandType = X86Opcode.OperandType;
    alias Status = X86Instruction.Status;
    final switch(instruction.status) {
        case Status.Ok: break;
        case Status.Invalid: return "invalid";
        case Status.OperandError: return "wrong operands";
        case Status.ModeError: return "mode error";
    }
    if(instruction.opcode is null) {
        return null;
    }
    string text = "";
    foreach(operand; instruction.opcode.operands) {
        const operandString = X86InstructionOperandToString(
            instruction, operand
        );
        if(operandString.length) {
            if(text.length) text ~= ", ";
            text ~= operandString;
        }
    }
    return instruction.opcode.name ~ (text.length ? " " ~ text : "");
}

/// A list of strings to represent a type of expected operands for an opcode.
shared immutable X86OpcodeOperandTypeStrings = [
    null,
    "al",
    "ax",
    "eax",
    "rax",
    "cl",
    "cs",
    "ss",
    "ds",
    "es",
    "fs",
    "gs",
    "1",
    "Sreg",
    "r8",
    "r16",
    "r32",
    "r64",
    "r/m8",
    "r/m16",
    "r/m32",
    "r/m64",
    "r8",
    "r16",
    "r32",
    "r64",
    "m16:16",
    "m16:32",
    "m16:64",
    "moffs8",
    "moffs16",
    "moffs32",
    "moffs64",
    "imm8",
    "imm16",
    "imm32",
    "imm64",
    "rel8",
    "rel16",
    "rel32",
    "rel64",
    "16",
    "32",
    "64",
    "ptr16:",
];
