/**

This module contains test coverage for x86 code generation.

Reference: https://defuse.ca/online-x86-assembler.htm

*/

module capsule.dynarec.x86.tests;

private:

import capsule.dynarec.x86.instruction : X86Instruction, X86InstructionBuffer;
import capsule.dynarec.x86.instruction : X86SIBScale;
import capsule.dynarec.x86.operand : X86Operand;
import capsule.dynarec.x86.register : X86Register, X86SegmentRegister;

private alias op_imm8 = X86Operand.Immediate8;
private alias op_imm16 = X86Operand.Immediate16;
private alias op_imm32 = X86Operand.Immediate32;
private alias op_imm64 = X86Operand.Immediate64;

private alias op_mem = X86Operand.Indirect;
private alias op_mem_idx = X86Operand.IndirectIndex;

private alias instr = X86Instruction;

private alias scale_1 = X86SIBScale.One;
private alias scale_2 = X86SIBScale.Two;
private alias scale_4 = X86SIBScale.Four;
private alias scale_8 = X86SIBScale.Eight;

static foreach(name; __traits(allMembers, X86Register)) {
    mixin(`private enum r_` ~ name ~ ` = X86Register.` ~ name ~ `;`);
    mixin(`private enum op_` ~ name ~ ` = (
        X86Operand.Register(X86Register.` ~ name ~ `)
    );`);
}

static foreach(name; __traits(allMembers, X86SegmentRegister)) {
    mixin(`private enum r_` ~ name ~ ` = X86SegmentRegister.` ~ name ~ `;`);
    mixin(`private enum op_` ~ name ~ ` = (
        X86Operand.SegmentRegister(X86SegmentRegister.` ~ name ~ `)
    );`);
}

public:

void debugX86Instruction(in X86Instruction instruction) {
    import capsule.io.stdio : stdio;
    import capsule.string.hex : getByteHexString;
    if(!instruction.ok) {
        stdio.writeln("Invalid instruction.");
        return;
    }
    if(instruction.hasLockByte) {
        const lockByte = instruction.getLockByte;
        stdio.writeln(getByteHexString(lockByte), " (LOCK prefix)");
    }
    // TODO: Prefix group 2 (segments, etc)
    if(instruction.hasAddressSizePrefixByte) {
        const addrByte = instruction.getAddressSizePrefixByte;
        stdio.writeln(getByteHexString(addrByte), " (Addr size prefix)");
    }
    if(instruction.hasOperandSizePrefixByte) {
        const operandByte = instruction.getOperandSizePrefixByte;
        stdio.writeln(getByteHexString(operandByte), " (Operand size prefix)");
    }
    if(instruction.hasREXByte) {
        const rexByte = instruction.getREXByte;
        stdio.writeln(getByteHexString(rexByte), " (REX prefix)");
    }
    if(cast(ushort) instruction.opcodeEscape > ubyte.max) {
        const escByte = cast(byte) (cast(short) instruction.opcodeEscape >> 8);
        stdio.writeln(getByteHexString(escByte), " (Opcode escape byte)");
    }
    if(instruction.opcodeEscape) {
        const escByte = cast(byte) instruction.opcodeEscape;
        stdio.writeln(getByteHexString(escByte), " (Opcode escape byte)");
    }
    if(true) {
        stdio.writeln(getByteHexString(cast(byte) instruction.opcode), " (Opcode)");
    }
    if(instruction.hasModRMByte) {
        const modrmByte = instruction.getModRMByte;
        stdio.writeln(getByteHexString(modrmByte), " (ModR/M byte)");
    }
    if(instruction.hasSIBByte) {
        const sibByte = instruction.getSIBByte;
        stdio.writeln(getByteHexString(sibByte), " (SIB byte)");
    }
    if(instruction.hasImmediate) {
        for(uint i = 0; i < instruction.immediateSize; i += 8) {
            const immByte = cast(byte) (instruction.immediate >> i);
            stdio.writeln(getByteHexString(immByte), " (Immediate)");
        }
    }
    if(instruction.hasDisplacement) {
        for(uint i = 0; i < instruction.displacementSize; i += 8) {
            const dispByte = cast(byte) (instruction.displacement >> i);
            stdio.writeln(getByteHexString(dispByte), " (Displacement)");
        }
    }
}

private version(unittest) {
    import capsule.io.stdio : stdio;
    import capsule.meta.enums : getEnumMemberName;
    import capsule.string.hex : getHexString;
    
    void test(
        in string assembly,
        in X86Instruction instruction,
        in ubyte[] expected,
    ) {
        X86InstructionBuffer!15 buffer;
        buffer.pushInstruction(instruction);
        stdio.writeln("; ", assembly);
        stdio.writeln("Expected: ", getHexString(expected));
        stdio.writeln("Actual:   ", getHexString(buffer.getBytes()), "\n");
        if(buffer.getBytes() != cast(const byte[]) expected) {
            debugX86Instruction(instruction);
            assert(false, "Encoding error: " ~ assembly);
        }
    }
}

/// add
unittest {
    test("add eax, edx",
        instr.Add(op_eax, op_edx),
        [0x01, 0xd0],
    );
    test("add eax, 0x1234567",
        instr.Add(op_eax, op_imm32(0x1234567)),
        [0x05, 0x67, 0x45, 0x23, 0x01],
    );
    test("add eax, [edx]",
        instr.Add(op_eax, op_mem(r_edx)),
        [0x67, 0x03, 0x02],
    );
    test("add [eax], dx",
        instr.Add(op_mem(r_eax), op_dx),
        [0x67, 0x66, 0x01, 0x10],
    );
    test("add rax, [rdx]",
        instr.Add(op_rax, op_mem(r_rdx)),
        [0x48, 0x03, 0x02],
    );
    test("add [eax * 2 + 0x0], ecx",
        instr.Add(op_mem_idx(r_eax, scale_2, 0), op_ecx),
        [0x67, 0x01, 0x0c, 0x45, 0x00, 0x00, 0x00, 0x00],
    );
    test("add [edx * 4 + 0xabcdef], r15d",
        instr.Add(op_mem_idx(r_edx, scale_4, 0xabcdef), op_r15d),
        [0x67, 0x44, 0x01, 0x3C, 0x95, 0xEF, 0xCD, 0xAB, 0x00],
    );
    test("add edi, [ecx + 0x4321]",
        instr.Add(op_edi, op_mem(r_ecx, 0x4321)),
        [0x67, 0x03, 0xB9, 0x21, 0x43, 0x00, 0x00],
    );
    test("add edi, [r8d + 0x4321]",
        instr.Add(op_edi, op_mem(r_r8d, 0x4321)),
        [0x67, 0x41, 0x03, 0xB8, 0x21, 0x43, 0x00, 0x00],
    );
    test("add eax, [ebp + esi * 2]",
        instr.Add(op_eax, op_mem(r_ebp, r_esi, scale_2, 0)),
        [0x67, 0x03, 0x44, 0x75, 0x00],
    );
    test("add r13d, [eax + r8d * 4 + 0x98765432]",
        instr.Add(op_r13d, op_mem(r_eax, r_r8d, scale_4, 0x98765432)),
        [0x67, 0x46, 0x03, 0xAC, 0x80, 0x32, 0x54, 0x76, 0x98],
    );
}

/// and
unittest {
    test("and r14, [rax]",
        instr.And(op_r14, op_mem(r_rax)),
        [0x4C, 0x23, 0x30],
    );
}

/// bsf
unittest {
    test("bsf ax, bp",
        instr.Bsf(op_ax, op_bp),
        [0x66, 0x0F, 0xBC, 0xC5],
    );
}

/// bsr
unittest {
    test("bsr ecx, esp",
        instr.Bsr(op_ecx, op_esp),
        [0x0F, 0xBD, 0xCC],
    );
    test("bsr bx, [ecx]",
        instr.Bsr(op_bx, op_mem(r_ecx)),
        [0x67, 0x66, 0x0F, 0xBD, 0x19],
    );
    test("bsr eax, [ebp + esi * 2]",
        instr.Bsr(op_eax, op_mem(r_ebp, r_esi, scale_2, 0)),
        [0x67, 0x0F, 0xBD, 0x44, 0x75, 0x00],
    );
}

/// bswap
unittest {
    test("bswap eax",
        instr.Bswap(op_eax),
        [0x0F, 0xC8],
    );
    test("bswap ecx",
        instr.Bswap(op_ecx),
        [0x0F, 0xC9],
    );
    test("bswap rbx",
        instr.Bswap(op_rbx),
        [0x48, 0x0F, 0xCB],
    );
    test("bswap r12",
        instr.Bswap(op_r12),
        [0x49, 0x0F, 0xCC],
    );
}

/// mov
unittest {
    test("mov cx, di",
        instr.Mov(op_cx, op_di),
        [0x66, 0x89, 0xF9],
    );
    test("mov ebx, esi",
        instr.Mov(op_ebx, op_esi),
        [0x89, 0xF3],
    );
    test("mov rax, rcx",
        instr.Mov(op_rax, op_rcx),
        [0x48, 0x89, 0xC8],
    );
    test("mov bl, 0x40",
        instr.Mov(op_bl, op_imm8(0x40)),
        [0xB3, 0x40],
    );
    test("mov di, 0x1234",
        instr.Mov(op_di, op_imm16(0x1234)),
        [0x66, 0xBF, 0x34, 0x12],
    );
    test("mov r14d, 0x78901234",
        instr.Mov(op_r14d, op_imm32(0x78901234)),
        [0x41, 0xBE, 0x34, 0x12, 0x90, 0x78],
    );
    test("mov rax, 0x1234abcd",
        instr.Mov(op_rax, op_imm32(0x1234abcd)),
        [0x48, 0xC7, 0xC0, 0xCD, 0xAB, 0x34, 0x12],
    );
    test("mov r14, 0x78901234",
        instr.Mov(op_r14, op_imm32(0x78901234)),
        [0x49, 0xC7, 0xC6, 0x34, 0x12, 0x90, 0x78],
    );
    test("mov rbp, 0x018923ab45cd67ef",
        instr.Mov(op_rbp, op_imm64(0x018923ab45cd67ef)),
        [0x48, 0xBD, 0xEF, 0x67, 0xCD, 0x45, 0xAB, 0x23, 0x89, 0x01],
    );
}

/// neg
unittest {
    test("neg r14d",
        instr.Neg(op_r14d),
        [0x41, 0xF7, 0xDE],
    );
}

/// not
unittest {
    test("not ecx",
        instr.Not(op_ecx),
        [0xF7, 0xD1],
    );
}

/// or
unittest {
    test("or rdx, rbp",
        instr.Or(op_rdx, op_rbp),
        [0x48, 0x09, 0xEA],
    );
}

/// popcnt
unittest {
    test("popcnt r9, r11",
        instr.Popcnt(op_r9, op_r11),
        [0xF3, 0x4D, 0x0F, 0xB8, 0xCB],
    );
    test("popcnt esp, [rax + rcx]",
        instr.Popcnt(op_esp, op_mem(r_rax, r_rcx, scale_1, 0)),
        [0xF3, 0x0F, 0xB8, 0x24, 0x08],
    );
}

/// sar
unittest {
    test("sar al, 1",
        instr.Sar(op_al, op_imm8(1)),
        [0xD0, 0xF8],
    );
    test("sar edx, 8",
        instr.Sar(op_edx, op_imm8(8)),
        [0xC1, 0xFA, 0x08],
    );
}

/// shl
unittest {
    test("shl eax, cl",
        instr.Shl(op_eax, op_cl),
        [0xD3, 0xE0],
    );
    test("shl ecx, cl",
        instr.ShlCL(op_ecx),
        [0xD3, 0xE1],
    );
    test("shl r9d, 1",
        instr.Shl1(op_r9d),
        [0x41, 0xD1, 0xE1],
    );
}

/// shr
unittest {
    test("shr dx, 1",
        instr.Shr(op_dx, op_imm8(1)),
        [0x66, 0xD1, 0xEA],
    );
}

/// sub
unittest {
    test("sub rax, 0x56789",
        instr.Sub(op_rax, op_imm32(0x56789)),
        [0x48, 0x2D, 0x89, 0x67, 0x05, 0x00],
    );
}

/// tzcnt
unittest {
    test("tzcnt rax, rbx",
        instr.Tzcnt(op_rax, op_rbx),
        [0xF3, 0x48, 0x0F, 0xBC, 0xC3],
    );
}

/// xor
unittest {
    test("xor r14d, 0xf0f0",
        instr.Xor(op_r14d, op_imm32(0xf0f0)),
        [0x41, 0x81, 0xF6, 0xF0, 0xF0, 0x00, 0x00],
    );
    test("xor ebp, [r8d + r9d]",
        instr.Xor(op_ebp, op_mem(r_r8d, r_r9d, scale_1, 0)),
        [0x67, 0x43, 0x33, 0x2C, 0x08],
    );
}
