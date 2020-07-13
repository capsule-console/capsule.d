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
import capsule.dynarec.x86.size : X86AddressSize;

private alias op_imm8 = X86Operand.Immediate8;
private alias op_imm16 = X86Operand.Immediate16;
private alias op_imm32 = X86Operand.Immediate32;
private alias op_imm64 = X86Operand.Immediate64;

private alias ptr8 = X86AddressSize.Byte;
private alias ptr16 = X86AddressSize.Word;
private alias ptr32 = X86AddressSize.DWord;
private alias ptr64 = X86AddressSize.QWord;

private alias op_imm64 = X86Operand.Immediate64;
private alias op_mem = X86Operand.Indirect;
private alias op_mem_idx = X86Operand.IndirectIndex;

private alias instr = X86Instruction;

private alias scale_1 = X86SIBScale.One;
private alias scale_2 = X86SIBScale.Two;
private alias scale_4 = X86SIBScale.Four;
private alias scale_8 = X86SIBScale.Eight;

private X86Operand seg_ovr(
    in X86Operand operand, in X86SegmentRegister register
) {
    return operand.SegmentOverride(register);
}

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
    if(instruction.hasSegmentOverridePrefixByte) {
        const segmentByte = instruction.getSegmentOverridePrefixByte;
        stdio.writeln(getByteHexString(segmentByte), " (Segment override prefix)");
    }
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
    if(instruction.hasDisplacement) {
        for(uint i = 0; i < instruction.displacementSize; i += 8) {
            const dispByte = cast(byte) (instruction.displacement >> i);
            stdio.writeln(getByteHexString(dispByte), " (Displacement)");
        }
    }
    if(instruction.hasImmediate) {
        for(uint i = 0; i < instruction.immediateSize; i += 8) {
            const immByte = cast(byte) (instruction.immediate >> i);
            stdio.writeln(getByteHexString(immByte), " (Immediate)");
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

/// adc
unittest {
    test("adc al, bh",
        instr.Adc(op_al, op_bh),
        [0x10, 0xf8],
    );
    test("adc ax, r14w",
        instr.Adc(op_ax, op_r14w),
        [0x66, 0x44, 0x11, 0xF0],
    );
    test("adc eax, edi",
        instr.Adc(op_eax, op_edi),
        [0x11, 0xf8],
    );
    test("adc bx, word ptr [eax + 0x40]",
        instr.Adc(op_bx, op_mem(ptr16, r_eax, 0x40)),
        [0x67, 0x66, 0x13, 0x58, 0x40],
    );
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
        instr.Add(op_eax, op_mem(ptr32, r_edx)),
        [0x67, 0x03, 0x02],
    );
    test("add [eax], dx",
        instr.Add(op_mem(ptr16, r_eax), op_dx),
        [0x67, 0x66, 0x01, 0x10],
    );
    test("add rax, [rdx]",
        instr.Add(op_rax, op_mem(ptr64, r_rdx)),
        [0x48, 0x03, 0x02],
    );
    test("add [eax * 2 + 0x0], ecx",
        instr.Add(op_mem_idx(ptr32, r_eax, scale_2, 0), op_ecx),
        [0x67, 0x01, 0x0c, 0x45, 0x00, 0x00, 0x00, 0x00],
    );
    test("add [edx * 4 + 0xabcdef], r15d",
        instr.Add(op_mem_idx(ptr32, r_edx, scale_4, 0xabcdef), op_r15d),
        [0x67, 0x44, 0x01, 0x3C, 0x95, 0xEF, 0xCD, 0xAB, 0x00],
    );
    test("add edi, [ecx + 0x4321]",
        instr.Add(op_edi, op_mem(ptr32, r_ecx, 0x4321)),
        [0x67, 0x03, 0xB9, 0x21, 0x43, 0x00, 0x00],
    );
    test("add edi, [r8d + 0x4321]",
        instr.Add(op_edi, op_mem(ptr32, r_r8d, 0x4321)),
        [0x67, 0x41, 0x03, 0xB8, 0x21, 0x43, 0x00, 0x00],
    );
    test("add eax, [ebp + esi * 2]",
        instr.Add(op_eax, op_mem(ptr32, r_ebp, r_esi, scale_2, 0)),
        [0x67, 0x03, 0x44, 0x75, 0x00],
    );
    test("add r13d, [eax + r8d * 4 + 0x98765432]",
        instr.Add(op_r13d, op_mem(ptr32, r_eax, r_r8d, scale_4, 0x98765432)),
        [0x67, 0x46, 0x03, 0xAC, 0x80, 0x32, 0x54, 0x76, 0x98],
    );
    test("add byte ptr [ecx], 0x10",
        instr.Add(op_mem(ptr8, r_ecx), op_imm8(0x10)),
        [0x67, 0x80, 0x01, 0x10],
    );
    test("add word ptr [r14 + 0x1234], 0x89ab",
        instr.Add(op_mem(ptr16, r_r14, 0x1234), op_imm16(cast(short) 0x89ab)),
        [0x66, 0x41, 0x81, 0x86, 0x34, 0x12, 0x00, 0x00, 0xAB, 0x89],
    );
    test("add word ptr [ecx + eax * 8], 0x4080",
        instr.Add(op_mem(ptr16, r_ecx, r_eax, scale_8), op_imm16(0x4080)),
        [0x67, 0x66, 0x81, 0x04, 0xC1, 0x80, 0x40],
    );
    test("add dword ptr [ebp + edi * 2], 0x451289ab",
        instr.Add(op_mem(ptr32, r_ebp, r_edi, scale_2, 0), op_imm32(0x451289ab)),
        [0x67, 0x81, 0x44, 0x7D, 0x00, 0xAB, 0x89, 0x12, 0x45],
    );
    test("add dword ptr [ecx + esi + 0x50607080], 0x9876fedc",
        instr.Add(op_mem(ptr32, r_ecx, r_esi, scale_1, 0x50607080), op_imm32(0x9876fedc)),
        [0x67, 0x81, 0x84, 0x31, 0x80, 0x70, 0x60, 0x50, 0xDC, 0xFE, 0x76, 0x98],
    );
    // TODO: qword ptr
    test("fs add [edi + ebx * 2 + 0x32], eax",
        instr.Add(op_mem(ptr32, r_edi, r_ebx, scale_2, 0x32).seg_ovr(r_fs), op_eax),
        [0x64, 0x67, 0x01, 0x44, 0x5F, 0x32],
    );
}

/// and
unittest {
    test("and al, bl",
        instr.And(op_al, op_bl),
        [0x20, 0xD8],
    );
    test("and r14, [rax]",
        instr.And(op_r14, op_mem(ptr64, r_rax)),
        [0x4C, 0x23, 0x30],
    );
    test("and rsi, 0x1234abcd",
        instr.And(op_rsi, op_imm32(0x1234abcd)),
        [0x48, 0x81, 0xE6, 0xCD, 0xAB, 0x34, 0x12],
    );
}

/// bsf
unittest {
    test("bsf ax, bp",
        instr.Bsf(op_ax, op_bp),
        [0x66, 0x0F, 0xBC, 0xC5],
    );
    test("bsf edx, eax",
        instr.Bsf(op_edx, op_eax),
        [0x0F, 0xBC, 0xD0],
    );
}

/// bsr
unittest {
    test("bsr ecx, esp",
        instr.Bsr(op_ecx, op_esp),
        [0x0F, 0xBD, 0xCC],
    );
    test("bsr bx, [ecx]",
        instr.Bsr(op_bx, op_mem(ptr16, r_ecx)),
        [0x67, 0x66, 0x0F, 0xBD, 0x19],
    );
    test("bsr eax, [ebp + esi * 2]",
        instr.Bsr(op_eax, op_mem(ptr32, r_ebp, r_esi, scale_2, 0)),
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

/// cmp
unittest {
    test("cmp al, r9b",
        instr.Cmp(op_al, op_r9b),
        [0x44, 0x38, 0xc8],
    );
    test("cmp ch, bl",
        instr.Cmp(op_ch, op_bl),
        [0x38, 0xdd],
    );
    test("cmp r10w, cx",
        instr.Cmp(op_r10w, op_cx),
        [0x66, 0x41, 0x39, 0xca],
    );
    test("cmp eax, esi",
        instr.Cmp(op_eax, op_esi),
        [0x39, 0xf0],
    );
    test("cmp bx, word ptr [esi + 0x40]",
        instr.Cmp(op_bx, op_mem(ptr16, r_esi, 0x40)),
        [0x67, 0x66, 0x3b, 0x5e, 0x40],
    );
}

/// dec
unittest {
    test("dec bl",
        instr.Dec(op_bl),
        [0xFE, 0xCB],
    );
    test("dec r8w",
        instr.Dec(op_r8w),
        [0x66, 0x41, 0xFF, 0xC8],
    );
    test("dec ecx",
        instr.Dec(op_ecx),
        [0xFF, 0xC9],
    );
    test("dec rax",
        instr.Dec(op_rax),
        [0x48, 0xFF, 0xC8],
    );
    test("dec byte ptr [eax]",
        instr.Dec(op_mem(ptr8, r_eax)),
        [0x67, 0xFE, 0x08],
    );
    test("dec word ptr [rbp + 0xaba1010]",
        instr.Dec(op_mem(ptr16, r_rbp, 0xaba1010)),
        [0x66, 0xFF, 0x8D, 0x10, 0x10, 0xBA, 0x0A],
    );
}

/// inc
unittest {
    test("inc cl",
        instr.Inc(op_cl),
        [0xFE, 0xC1],
    );
    test("inc ax",
        instr.Inc(op_ax),
        [0x66, 0xFF, 0xC0],
    );
    test("inc r10d",
        instr.Inc(op_r10d),
        [0x41, 0xFF, 0xC2],
    );
    test("inc rbp",
        instr.Inc(op_rbp),
        [0x48, 0xFF, 0xC5],
    );
    test("inc byte ptr [eax]",
        instr.Inc(op_mem(ptr8, r_eax)),
        [0x67, 0xFE, 0x00],
    );
    test("inc dword ptr [rsp + 0x512256]",
        instr.Inc(op_mem(ptr32, r_rsp, 0x512256)),
        [0xFF, 0x84, 0x24, 0x56, 0x22, 0x51, 0x00],
    );
}

/// mov
unittest {
    test("mov bl, dl",
        instr.Mov(op_bl, op_dl),
        [0x88, 0xD3],
    );
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
    test("mov si, ss",
        instr.Mov(op_si, op_ss),
        [0x66, 0x8C, 0xD6],
    );
    test("mov eax, cs",
        instr.Mov(op_eax, op_cs),
        [0x8C, 0xC8],
    );
    test("mov rbp, es",
        instr.Mov(op_rbp, op_es),
        [0x48, 0x8C, 0xC5],
    );
    test("mov ss, cx",
        instr.Mov(op_ss, op_cx),
        [0x8E, 0xD1],
    );
    test("mov ds, r8w",
        instr.Mov(op_ds, op_r8w),
        [0x41, 0x8E, 0xD8],
    );
    test("mov ds, eax",
        instr.Mov(op_ds, op_eax),
        [0x8E, 0xD8],
    );
    test("mov gs, r12d",
        instr.Mov(op_gs, op_r12d),
        [0x41, 0x8E, 0xEC],
    );
    test("mov fs, r10",
        instr.Mov(op_fs, op_r10),
        [0x49, 0x8E, 0xE2],
    );
    test("mov al, 0x00",
        instr.Mov(op_al, op_imm8(0x00)),
        [0xb0, 0x00],
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
    test("mov byte ptr [esi], 0xff",
        instr.Mov(op_mem(ptr8, r_esi), op_imm8(cast(byte) 0xff)),
        [0x67, 0xC6, 0x06, 0xFF],
    );
    test("mov dword ptr [ebp], 0x4512",
        instr.Mov(op_mem(ptr32, r_ebp), op_imm32(0x4512)),
        [0x67, 0xC7, 0x45, 0x00, 0x12, 0x45, 0x00, 0x00],
    );
    test("mov dword ptr [ecx + 0x1290], 0xff008090",
        instr.Mov(op_mem(ptr32, r_ecx, 0x1290), op_imm32(0xff008090)),
        [0x67, 0xC7, 0x81, 0x90, 0x12, 0x00, 0x00, 0x90, 0x80, 0x00, 0xFF],
    );
    test("cs mov [0x1234], eax",
        instr.Mov(op_mem(ptr32, 0x1234).seg_ovr(r_cs), op_eax),
        [0x2E, 0x89, 0x04, 0x25, 0x34, 0x12, 0x00, 0x00],
    );
    test("ds mov [edi + esi * 4], ecx",
        instr.Mov(op_mem(ptr32, r_edi, r_esi, scale_4, 0).seg_ovr(r_ds), op_ecx),
        [0x3E, 0x67, 0x89, 0x0C, 0xB7],
    );
    test("ds mov eax, [r11d]",
        instr.Mov(op_eax, op_mem(ptr32, r_r11d).seg_ovr(r_ds)),
        [0x3E, 0x67, 0x41, 0x8B, 0x03],
    );
    test("gs mov eax, [ebp + esi * 2]",
        instr.Mov(op_eax, op_mem(ptr32, r_ebp, r_esi, scale_2, 0).seg_ovr(r_gs)),
        [0x65, 0x67, 0x8B, 0x44, 0x75, 0x00],
    );
}

/// movsx
unittest {
    test("movsx edx, bh",
        instr.Movsx(op_edx, op_bh),
        [0x0F, 0xBE, 0xD7],
    );
    test("movsx rsi, dl",
        instr.Movsx(op_rsi, op_dl),
        [0x48, 0x0F, 0xBE, 0xF2],
    );
    test("movsx r12, al",
        instr.Movsx(op_r12, op_al),
        [0x4C, 0x0F, 0xBE, 0xE0],
    );
    test("movsx ecx, bx",
        instr.Movsx(op_ecx, op_bx),
        [0x0F, 0xBF, 0xCB],
    );
    test("movsx r14, sp",
        instr.Movsx(op_r14, op_sp),
        [0x4C, 0x0F, 0xBF, 0xF4],
    );
    test("movsx ebx, byte ptr [ebp]",
        instr.Movsx(op_ebx, op_mem(ptr8, r_ebp)),
        [0x67, 0x0F, 0xBE, 0x5D, 0x00],
    );
    test("movsx eax, word ptr [ebp + edi * 4]",
        instr.Movsx(op_eax, op_mem(ptr16, r_ebp, r_edi, scale_4, 0)),
        [0x67, 0x0F, 0xBF, 0x44, 0xBD, 0x00],
    );
}

/// movzx
unittest {
    test("movzx ebx, ch",
        instr.Movzx(op_ebx, op_ch),
        [0x0F, 0xB6, 0xDD],
    );
    test("movzx rsi, dl",
        instr.Movzx(op_rsi, op_dl),
        [0x48, 0x0F, 0xB6, 0xF2],
    );
    test("movzx r8, bl",
        instr.Movzx(op_r8, op_bl),
        [0x4C, 0x0F, 0xB6, 0xC3],
    );
    test("movzx ecx, bx",
        instr.Movzx(op_ecx, op_bx),
        [0x0F, 0xB7, 0xCB],
    );
    test("movzx r9, bp",
        instr.Movzx(op_r9, op_bp),
        [0x4C, 0x0F, 0xB7, 0xCD],
    );
    test("movzx ax, byte ptr [0x65432101]",
        instr.Movzx(op_ax, op_mem(ptr8, 0x65432101)),
        [0x66, 0x0F, 0xB6, 0x04, 0x25, 0x01, 0x21, 0x43, 0x65],
    );
    test("movzx ebp, byte ptr [eax * 8]",
        instr.Movzx(op_ebp, op_mem_idx(ptr8, r_eax, scale_8, 0)),
        [0x67, 0x0F, 0xB6, 0x2C, 0xC5, 0x00, 0x00, 0x00, 0x00],
    );
    test("movzx r8, word ptr [ebp + esi * 2 + 0x5678abcd]",
        instr.Movzx(op_r8, op_mem(ptr16, r_ebp, r_esi, scale_2, 0x5678abcd)),
        [0x67, 0x4C, 0x0F, 0xB7, 0x84, 0x75, 0xCD, 0xAB, 0x78, 0x56],
    );
}

/// neg
unittest {
    test("neg cl",
        instr.Neg(op_cl),
        [0xF6, 0xD9],
    );
    test("neg r9b",
        instr.Neg(op_r9b),
        [0x41, 0xF6, 0xD9],
    );
    test("neg r14d",
        instr.Neg(op_r14d),
        [0x41, 0xF7, 0xDE],
    );
    test("neg byte ptr [ebp]",
        instr.Neg(op_mem(ptr8, r_ebp)),
        [0x67, 0xF6, 0x5D, 0x00],
    );
    test("neg word ptr [ecx]",
        instr.Neg(op_mem(ptr16, r_ecx)),
        [0x67, 0x66, 0xF7, 0x19],
    );
    test("neg dword ptr [eax]",
        instr.Neg(op_mem(ptr32, r_eax)),
        [0x67, 0xF7, 0x18],
    );
}

/// nop
unittest {
    test("nop",
        instr.Nop(1),
        [0x90],
    );
    test("nop # 2 bytes",
        instr.Nop(2),
        [0x66, 0x90],
    );
    test("nop dword ptr [rax] # 3 bytes",
        instr.Nop(3),
        [0x0f, 0x1f, 0x00],
    );
    test("nop dword ptr [rax + 0] # 4 bytes",
        instr.Nop(4),
        [0x0f, 0x1f, 0x40, 0x00],
    );
    test("nop dword ptr [rax + rax * 1 + 0] # 5 bytes",
        instr.Nop(5),
        [0x0f, 0x1f, 0x44, 0x00, 0x00],
    );
    test("nop dword ptr [rax + rax * 1 + 0] # 6 bytes",
        instr.Nop(6),
        [0x66, 0x0f, 0x1f, 0x44, 0x00, 0x00],
    );
    test("nop dword ptr [rax + 0] # 7 bytes",
        instr.Nop(7),
        [0x0f, 0x1f, 0x80, 0x00, 0x00, 0x00, 0x00],
    );
    test("nop dword ptr [rax + rax * 1 + 0] # 8 bytes",
        instr.Nop(8),
        [0x0f, 0x1f, 0x84, 0x00, 0x00, 0x00, 0x00, 0x00],
    );
    test("nop dword ptr [rax + rax * 1 + 0] # 9 bytes",
        instr.Nop(9),
        [0x66, 0x0f, 0x1f, 0x84, 0x00, 0x00, 0x00, 0x00, 0x00],
    );
}

/// not
unittest {
    test("not r8b",
        instr.Not(op_r8b),
        [0x41, 0xF6, 0xD0],
    );
    test("not ecx",
        instr.Not(op_ecx),
        [0xF7, 0xD1],
    );
    test("not byte ptr [eax]",
        instr.Not(op_mem(ptr8, r_eax)),
        [0x67, 0xF6, 0x10],
    );
    test("not qword ptr [r10 + r11 * 4 + 0x50607080]",
        instr.Not(op_mem(ptr64, r_r10, r_r11, scale_4, 0x50607080)),
        [0x4B, 0xF7, 0x94, 0x9A, 0x80, 0x70, 0x60, 0x50],
    );
}

/// or
unittest {
    test("or al, bl",
        instr.Or(op_al, op_bl),
        [0x08, 0xD8],
    );
    test("or rdx, rbp",
        instr.Or(op_rdx, op_rbp),
        [0x48, 0x09, 0xEA],
    );
    test("or word ptr [ecx + eax * 8], 0x4080",
        instr.Or(op_mem(ptr16, r_ecx, r_eax, scale_8), op_imm16(0x4080)),
        [0x67, 0x66, 0x81, 0x0C, 0xC1, 0x80, 0x40],
    );
}

/// popcnt
unittest {
    test("popcnt r9, r11",
        instr.Popcnt(op_r9, op_r11),
        [0xF3, 0x4D, 0x0F, 0xB8, 0xCB],
    );
    test("popcnt esp, [rax + rcx]",
        instr.Popcnt(op_esp, op_mem(ptr32, r_rax, r_rcx, scale_1, 0)),
        [0xF3, 0x0F, 0xB8, 0x24, 0x08],
    );
}

/// sar
unittest {
    test("sar rsi, cl",
        instr.Sar(op_rsi, op_cl),
        [0x48, 0xD3, 0xFE],
    );
    test("sar al, 1",
        instr.Sar(op_al, op_imm8(1)),
        [0xD0, 0xF8],
    );
    test("sar edx, 8",
        instr.Sar(op_edx, op_imm8(8)),
        [0xC1, 0xFA, 0x08],
    );
    test("sar dword ptr [ebp + ecx], 3",
        instr.Sar(op_mem(ptr32, r_ebp, r_ecx, scale_1, 0), op_imm8(3)),
        [0x67, 0xC1, 0x7C, 0x0D, 0x00, 0x03],
    );
}

/// shl
unittest {
    test("shl r8b, cl",
        instr.Shl(op_r8b, op_cl),
        [0x41, 0xD2, 0xE0],
    );
    test("shl bx, cl",
        instr.Shl(op_bx, op_cl),
        [0x66, 0xD3, 0xE3],
    );
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
    test("shl dword ptr [ebx], cl",
        instr.Shl(op_mem(ptr32, r_ebx), op_cl),
        [0x67, 0xD3, 0x23],
    );
    test("shl byte ptr [eax + 0xe543210f], 10",
        instr.Shl(op_mem(ptr8, r_eax, 0xe543210f), op_imm8(10)),
        [0x67, 0xC0, 0xA0, 0x0F, 0x21, 0x43, 0xE5, 0x0A],
    );
}

/// shr
unittest {
    test("shr r15, cl",
        instr.Shr(op_r15, op_cl),
        [0x49, 0xD3, 0xEF],
    );
    test("shr dx, 1",
        instr.Shr(op_dx, op_imm8(1)),
        [0x66, 0xD1, 0xEA],
    );
    test("shr bl, 12",
        instr.Shr(op_bl, op_imm8(12)),
        [0xC0, 0xEB, 0x0C],
    );
    test("shr byte ptr [ecx], 30",
        instr.Shr(op_mem(ptr8, r_ecx), op_imm8(30)),
        [0x67, 0xC0, 0x29, 0x1E],
    );
}

/// sub
unittest {
    test("sub r8b, bl",
        instr.Sub(op_r8b, op_bl),
        [0x41, 0x28, 0xD8],
    );
    test("sub eax, r10d",
        instr.Sub(op_eax, op_r10d),
        [0x44, 0x29, 0xD0],
    );
    test("sub eax, r8d",
        instr.Sub(op_eax, op_r8d),
        [0x44, 0x29, 0xC0],
    );
    test("sub r8d, eax",
        instr.Sub(op_r8d, op_eax),
        [0x41, 0x29, 0xC0],
    );
    test("sub rax, 0x56789",
        instr.Sub(op_rax, op_imm32(0x56789)),
        [0x48, 0x2D, 0x89, 0x67, 0x05, 0x00],
    );
    test("sub dword ptr [ecx], eax",
        instr.Sub(op_mem(ptr32, r_ecx), op_eax),
        [0x67, 0x29, 0x01],
    );
}

/// sbb
unittest {
    test("sbb al, r9b",
        instr.Sbb(op_al, op_r9b),
        [0x44, 0x18, 0xc8],
    );
    test("sbb ch, bl",
        instr.Sbb(op_ch, op_bl),
        [0x18, 0xdd],
    );
    test("sbb r10w, cx",
        instr.Sbb(op_r10w, op_cx),
        [0x66, 0x41, 0x19, 0xca],
    );
    test("sbb eax, esi",
        instr.Sbb(op_eax, op_esi),
        [0x19, 0xf0],
    );
    test("sbb al, 0x33",
        instr.Sbb(op_al, op_imm8(0x33)),
        [0x1c, 0x33],
    );
    test("sbb ax, 0x2124",
        instr.Sbb(op_ax, op_imm16(0x2124)),
        [0x66, 0x1d, 0x24, 0x21],
    );
    test("sbb rax, 0x12340123",
        instr.Sbb(op_rax, op_imm32(0x12340123)),
        [0x48, 0x1d, 0x23, 0x01, 0x34, 0x12],
    );
    test("sbb bx, word ptr [esi + 0x40]",
        instr.Sbb(op_bx, op_mem(ptr16, r_esi, 0x40)),
        [0x67, 0x66, 0x1b, 0x5e, 0x40],
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
        instr.Xor(op_ebp, op_mem(ptr32, r_r8d, r_r9d, scale_1, 0)),
        [0x67, 0x43, 0x33, 0x2C, 0x08],
    );
}
