/**

This module defines opcodes used by the x86 recompilation module.

*/

module capsule.dynarec.x86.opcodes;

private:

import capsule.dynarec.x86.instruction : X86Instruction;

private alias LockPrefix = X86Instruction.LockPrefix;

public:

/// TODO:
/// https://www.felixcloutier.com/x86/call (call procedure)
/// https://www.felixcloutier.com/x86/cmovcc (conditional move)
/// https://www.felixcloutier.com/x86/cmp (compare two operands)
/// https://www.felixcloutier.com/x86/cpuid (CPU identification)
/// https://www.felixcloutier.com/x86/div (unsigned divide)
/// https://www.felixcloutier.com/x86/idiv (signed divide)
/// https://www.felixcloutier.com/x86/imul (signed multiply)
/// https://www.felixcloutier.com/x86/jmp (jump)
/// https://www.felixcloutier.com/x86/jcc (jump if condition is met)
/// https://www.felixcloutier.com/x86/mul (unsigned multiply)
/// https://www.felixcloutier.com/x86/setcc (set byte on condition)
/// https://www.felixcloutier.com/x86/stc (set carry flag)
/// https://www.felixcloutier.com/x86/xchg (exchange register/memory)
/// https://www.felixcloutier.com/x86/movbe (move after swapping bytes)

/// DONE:
/// https://www.felixcloutier.com/x86/movsx:movsxd (move with sign extension)
/// https://www.felixcloutier.com/x86/movzx (move with zero extension)
/// https://www.felixcloutier.com/x86/nop (no operation)
/// https://www.felixcloutier.com/x86/dec (decrement by 1)
/// https://www.felixcloutier.com/x86/inc (increment by 1)

/// No operation (one byte)
static enum X86Nop1 = X86Instruction.Opcode(0x90);
/// No operation (multiple bytes)
static enum X86NopRx = X86Instruction.Opcode(0x0f1f);

/// Increment an 8-bit register by 1
static enum X86IncR8 = X86Instruction.Opcode(0xfe, 0x0);
/// Increment a 16, 32, or 64-bit register by 1
static enum X86IncRx = X86Instruction.Opcode(0xff, 0x0);
/// Increment a 16 or 32-bit register by 1; not allowed in long mode
static enum X86IncORx = X86Instruction.Opcode(0x40);

/// Decrement an 8-bit register by 1
static enum X86DecR8 = X86Instruction.Opcode(0xfe, 0x1);
/// Decrement a 16, 32, or 64-bit register by 1
static enum X86DecRx = X86Instruction.Opcode(0xff, 0x1);
/// Decrement a 16 or 32-bit register by 1; not allowed in long mode
static enum X86DecORx = X86Instruction.Opcode(0x48);

/// Bitwise (one's complement) negate an 8-bit register
static enum X86NotR8 = X86Instruction.Opcode(0xf6, 0x2);
/// Bitwise (one's complement) negate a 16, 32, or 64-bit register
static enum X86NotRx = X86Instruction.Opcode(0xf7, 0x2);

/// Arithmetic (two's complement) negate an 8-bit register
static enum X86NegR8 = X86Instruction.Opcode(0xf6, 0x3);
/// Arithmetic (two's complement) negate a 16, 32, or 64-bit register
static enum X86NegRx = X86Instruction.Opcode(0xf7, 0x3);

/// Move and zero-extend; move 8-bit operand to 16, 32, or 64-bit register
static enum X86MovzxR8 = X86Instruction.Opcode(0x0fb6);
/// Move and zero-extend; move 16-bit operand to 32 or 64-bit register
static enum X86MovzxR16 = X86Instruction.Opcode(0x0fb7);

/// Move and sign-extend; move 8-bit operand to 16, 32, or 64-bit register
static enum X86MovsxR8 = X86Instruction.Opcode(0x0fbe);
/// Move and sign-extend; move 16-bit operand to 32 or 64-bit register
static enum X86MovsxR16 = X86Instruction.Opcode(0x0fbf);

/// Move and sign-extend; move 16 or 32-bit operand to 16, 32, 64-bit register
/// Use for cases other than 32-bit operand to 64-bit register are discouraged
static enum X86MovsxdRx = X86Instruction.Opcode(0x63);

/// Add two registers (8 bits), indirection is source
static enum X86AddR8 = X86Instruction.Opcode(0x00);
/// Add two registers (16, 32, or 64 bits), indirection is source
static enum X86AddRx = X86Instruction.Opcode(0x01);
/// Add two registers (8 bits), indirection is destination
static enum X86AddRM8 = X86Instruction.Opcode(0x02);
/// Add two registers (16, 32, or 64 bits), indirection is destination
static enum X86AddRMx = X86Instruction.Opcode(0x03);
/// Add an 8-bit immediate to AL (8 bits)
static enum X86AddAL = X86Instruction.Opcode(0x04);
/// Add an immediate to AX (16 bits), EAX (32 bits), or RAX (64 bits)
static enum X86AddAX = X86Instruction.Opcode(0x05);
/// Add an 8-bit immediate to an 8-bit register
static enum X86AddR8I8 = X86Instruction.Opcode(0x80, 0x0);
/// Add an immediate to a register (16, 32, or 64 bits)
static enum X86AddRIx = X86Instruction.Opcode(0x81, 0x0);
/// Add an 8-bit immediate to a register (16, 32, or 64 bits)
static enum X86AddRxI8 = X86Instruction.Opcode(0x83, 0x0);

/// Bitwise OR two registers (8 bits), indirection is source
static enum X86OrR8 = X86Instruction.Opcode(0x08);
/// Bitwise OR two registers (16, 32, or 64 bits), indirection is source
static enum X86OrRx = X86Instruction.Opcode(0x09);
/// Bitwise OR two registers (8 bits), indirection is destination
static enum X86OrRM8 = X86Instruction.Opcode(0x0a);
/// Bitwise OR two registers (16, 32, or 64 bits), indirection is destination
static enum X86OrRMx = X86Instruction.Opcode(0x0b);
/// Bitwise OR an 8-bit immediate to AL (8 bits)
static enum X86OrAL = X86Instruction.Opcode(0x0c);
/// Bitwise OR an immediate to AX (16 bits), EAX (32 bits), or RAX (64 bits)
static enum X86OrAX = X86Instruction.Opcode(0x0d);
/// Bitwise OR an 8-bit immediate to an 8-bit register
static enum X86OrR8I8 = X86Instruction.Opcode(0x80, 0x1);
/// Bitwise OR an immediate to a register (16, 32, or 64 bits)
static enum X86OrRIx = X86Instruction.Opcode(0x81, 0x1);
/// Bitwise OR an 8-bit immediate to a register (16, 32, or 64 bits)
static enum X86OrRxI8 = X86Instruction.Opcode(0x83, 0x1);

/// Add CF and two registers (8 bits), indirection is source
static enum X86AdcR8 = X86Instruction.Opcode(0x10);
/// Add CF and two registers (16, 32, or 64 bits), indirection is source
static enum X86AdcRx = X86Instruction.Opcode(0x11);
/// Add CF and two registers (8 bits), indirection is destination
static enum X86AdcRM8 = X86Instruction.Opcode(0x12);
/// Add CF and two registers (16, 32, or 64 bits), indirection is destination
static enum X86AdcRMx = X86Instruction.Opcode(0x13);
/// Add CF and an 8-bit immediate to AL (8 bits)
static enum X86AdcAL = X86Instruction.Opcode(0x14);
/// Add CF and an immediate to AX (16 bits), EAX (32 bits), or RAX (64 bits)
static enum X86AdcAX = X86Instruction.Opcode(0x15);
/// Add CF and an 8-bit immediate to an 8-bit register
static enum X86AdcR8I8 = X86Instruction.Opcode(0x80, 0x2);
/// Add CF and an immediate to a register (16, 32, or 64 bits)
static enum X86AdcRIx = X86Instruction.Opcode(0x81, 0x2);
/// Add CF and an 8-bit immediate to a register (16, 32, or 64 bits)
static enum X86AdcRxI8 = X86Instruction.Opcode(0x83, 0x2);

/// Subtract CF and two registers (8 bits), indirection is source
static enum X86SbbR8 = X86Instruction.Opcode(0x18);
/// Subtract CF and two registers (16, 32, or 64 bits), indirection is source
static enum X86SbbRx = X86Instruction.Opcode(0x19);
/// Subtract CF and two registers (8 bits), indirection is destination
static enum X86SbbRM8 = X86Instruction.Opcode(0x1a);
/// Subtract CF and two registers (16, 32, or 64 bits), indirection is destination
static enum X86SbbRMx = X86Instruction.Opcode(0x1b);
/// Subtract CF and an 8-bit immediate from AL (8 bits)
static enum X86SbbAL = X86Instruction.Opcode(0x1c);
/// Subtract CF and an immediate from AX (16 bits), EAX (32 bits), or RAX (64 bits)
static enum X86SbbAX = X86Instruction.Opcode(0x1d);
/// Subtract CF and an 8-bit immediate from an 8-bit register
static enum X86SbbR8I8 = X86Instruction.Opcode(0x80, 0x3);
/// Subtract CF and an immediate from a register (16, 32, or 64 bits)
static enum X86SbbRIx = X86Instruction.Opcode(0x81, 0x3);
/// Subtract CF and an 8-bit immediate from a register (16, 32, or 64 bits)
static enum X86SbbRxI8 = X86Instruction.Opcode(0x83, 0x3);

/// Bitwise AND two registers (8 bits), indirection is source
static enum X86AndR8 = X86Instruction.Opcode(0x20);
/// Bitwise AND two registers (16, 32, or 64 bits), indirection is source
static enum X86AndRx = X86Instruction.Opcode(0x21);
/// Bitwise AND two registers (8 bits), indirection is destination
static enum X86AndRM8 = X86Instruction.Opcode(0x22);
/// Bitwise AND two registers (16, 32, or 64 bits), indirection is destination
static enum X86AndRMx = X86Instruction.Opcode(0x23);
/// Bitwise AND an 8-bit immediate to AL (8 bits)
static enum X86AndAL = X86Instruction.Opcode(0x24);
/// Bitwise AND an immediate to AX (16 bits), EAX (32 bits), or RAX (64 bits)
static enum X86AndAX = X86Instruction.Opcode(0x25);
/// Bitwise AND an 8-bit immediate to an 8-bit register
static enum X86AndR8I8 = X86Instruction.Opcode(0x80, 0x4);
/// Bitwise AND an immediate to a register (16, 32, or 64 bits)
static enum X86AndRIx = X86Instruction.Opcode(0x81, 0x4);
/// Bitwise AND an 8-bit immediate to a register (16, 32, or 64 bits)
static enum X86AndRxI8 = X86Instruction.Opcode(0x83, 0x4);

/// Subtract two registers (8 bits), indirection is source
static enum X86SubR8 = X86Instruction.Opcode(0x28);
/// Subtract two registers (16, 32, or 64 bits), indirection is source
static enum X86SubRx = X86Instruction.Opcode(0x29);
/// Subtract two registers (8 bits), indirection is destination
static enum X86SubRM8 = X86Instruction.Opcode(0x2a);
/// Subtract two registers (16, 32, or 64 bits), indirection is destination
static enum X86SubRMx = X86Instruction.Opcode(0x2b);
/// Subtract an 8-bit immediate from AL (8 bits)
static enum X86SubAL = X86Instruction.Opcode(0x2c);
/// Subtract an immediate from AX (16 bits), EAX (32 bits), or RAX (64 bits)
static enum X86SubAX = X86Instruction.Opcode(0x2d);
/// Subtract an 8-bit immediate from an 8-bit register
static enum X86SubR8I8 = X86Instruction.Opcode(0x80, 0x5);
/// Subtract an immediate from a register (16, 32, or 64 bits)
static enum X86SubRIx = X86Instruction.Opcode(0x81, 0x5);
/// Subtract an 8-bit immediate from a register (16, 32, or 64 bits)
static enum X86SubRxI8 = X86Instruction.Opcode(0x83, 0x5);

/// Bitwise XOR two registers (8 bits), indirection is source
static enum X86XorR8 = X86Instruction.Opcode(0x30);
/// Bitwise XOR two registers (16, 32, or 64 bits), indirection is source
static enum X86XorRx = X86Instruction.Opcode(0x31);
/// Bitwise XOR two registers (8 bits), indirection is destination
static enum X86XorRM8 = X86Instruction.Opcode(0x32);
/// Bitwise XOR two registers (16, 32, or 64 bits), indirection is destination
static enum X86XorRMx = X86Instruction.Opcode(0x33);
/// Bitwise XOR an 8-bit immediate to AL (8 bits)
static enum X86XorAL = X86Instruction.Opcode(0x34);
/// Bitwise XOR an immediate to AX (16 bits), EAX (32 bits), or RAX (64 bits)
static enum X86XorAX = X86Instruction.Opcode(0x35);
/// Bitwise XOR an 8-bit immediate to an 8-bit register
static enum X86XorR8I8 = X86Instruction.Opcode(0x80, 0x6);
/// Bitwise XOR an immediate to a register (16, 32, or 64 bits)
static enum X86XorRIx = X86Instruction.Opcode(0x81, 0x6);
/// Bitwise XOR an 8-bit immediate to a register (16, 32, or 64 bits)
static enum X86XorRxI8 = X86Instruction.Opcode(0x83, 0x6);

/// Compare two registers (8 bits), indirection is source
static enum X86CmpR8 = X86Instruction.Opcode(0x38);
/// Compare two registers (16, 32, or 64 bits), indirection is source
static enum X86CmpRx = X86Instruction.Opcode(0x39);
/// Compare two registers (8 bits), indirection is destination
static enum X86CmpRM8 = X86Instruction.Opcode(0x3a);
/// Compare two registers (16, 32, or 64 bits), indirection is destination
static enum X86CmpRMx = X86Instruction.Opcode(0x3b);
/// Compare an 8-bit immediate to AL (8 bits)
static enum X86CmpAL = X86Instruction.Opcode(0x3c);
/// Compare an immediate to AX (16 bits), EAX (32 bits), or RAX (64 bits)
static enum X86CmpAX = X86Instruction.Opcode(0x3d);
/// Compare an 8-bit immediate to an 8-bit register
static enum X86CmpR8I8 = X86Instruction.Opcode(0x80, 0x7);
/// Compare an immediate to a register (16, 32, or 64 bits)
static enum X86CmpRIx = X86Instruction.Opcode(0x81, 0x7);
/// Compare an 8-bit immediate to a register (16, 32, or 64 bits)
static enum X86CmpRxI8 = X86Instruction.Opcode(0x83, 0x7);

/// Move registers (8 bits), indirection is source
static enum X86MovR8 = X86Instruction.Opcode(0x88);
/// Move registers (16, 32, or 64 bits), indirection is source
static enum X86MovRx = X86Instruction.Opcode(0x89);
/// Move registers (8 bits), indirection is destination
static enum X86MovRM8 = X86Instruction.Opcode(0x8a);
/// Move registers (16, 32, or 64 bits), indirection is destination
static enum X86MovRMx = X86Instruction.Opcode(0x8b);
/// Move a segment register to a 16, 32, or 64 bit GP register
static enum X86MovRxS = X86Instruction.Opcode(0x8c);
/// Move a 16, 32, or 64 bit GP register to a segment register
static enum X86MovSRx = X86Instruction.Opcode(0x8e);
/// Move byte at (seg:offset) to AL.
/// Support seems sketchy? Use X86MovR8 with a segment override prefix instead.
static enum X86MovStoAL = X86Instruction.Opcode(0xa0);
/// Move value at (seg:offset) to AX (16 bits), EAX (32 bits), or RAX (64 bits).
/// Support seems sketchy? Use X86MovRx with a segment override prefix instead.
static enum X86MovStoAX = X86Instruction.Opcode(0xa1);
/// Move AL to (seg:offset).
/// Support seems sketchy? Use X86MovRM8 with a segment override prefix instead.
static enum X86MovALtoS = X86Instruction.Opcode(0xa0);
/// Move AX (16 bits), EAX (32 bits), or RAX (64 bits) to (seg:offset).
/// Support seems sketchy? Use X86MovRMx with a segment override prefix instead.
static enum X86MovAXtoS = X86Instruction.Opcode(0xa1);
/// Move 8-bit immediate to an 8-bit register (r)
static enum X86MovR8I8 = X86Instruction.Opcode(0xb0);
/// Move immediate to a register (r: 16, 32, or 64 bits), 64-bit imm for 64-bit reg
static enum X86MovRIq = X86Instruction.Opcode(0xb8);
/// Move 8-bit immediate to an 8-bit register (r/m)
static enum X86MovRM8I8 = X86Instruction.Opcode(0xc6, 0x0);
/// Move immediate to a register (r/m: 16, 32, or 64 bits), 32-bit imm for 64-bit reg
static enum X86MovRMIx = X86Instruction.Opcode(0xc7, 0x0);

/// Arithmetic bit shift right an 8-bit register, once
static enum X86SarR81 = X86Instruction.Opcode(0xd0, 0x7);
/// Arithmetic bit shift right a 16, 32, or 64 bit register, once
static enum X86SarRx1 = X86Instruction.Opcode(0xd1, 0x7);
/// Arithmetic bit shift right an 8-bit register, CL times
static enum X86SarR8CL = X86Instruction.Opcode(0xd2, 0x7);
/// Arithmetic bit shift right a 16, 32, or 64 bit register, CL times
static enum X86SarRxCL = X86Instruction.Opcode(0xd3, 0x7);

/// Arithmetic bit shift right an 8-bit register, imm8 times
static enum X86SarR8I8 = X86Instruction.Opcode(0xc0, 0x7);
/// Arithmetic bit shift right a 16, 32, or 64 bit register, imm8 times
static enum X86SarRxI8 = X86Instruction.Opcode(0xc1, 0x7);

/// Logical bit shift left an 8-bit register, once
static enum X86ShlR81 = X86Instruction.Opcode(0xd0, 0x4);
/// Logical bit shift left a 16, 32, or 64 bit register, once
static enum X86ShlRx1 = X86Instruction.Opcode(0xd1, 0x4);
/// Logical bit shift left an 8-bit register, CL times
static enum X86ShlR8CL = X86Instruction.Opcode(0xd2, 0x4);
/// Logical bit shift left a 16, 32, or 64 bit register, CL times
static enum X86ShlRxCL = X86Instruction.Opcode(0xd3, 0x4);

/// Logical bit shift left an 8-bit register, imm8 times
static enum X86ShlR8I8 = X86Instruction.Opcode(0xc0, 0x4);
/// Logical bit shift left a 16, 32, or 64 bit register, imm8 times
static enum X86ShlRxI8 = X86Instruction.Opcode(0xc1, 0x4);

/// Logical bit shift right an 8-bit register, once
static enum X86ShrR81 = X86Instruction.Opcode(0xd0, 0x5);
/// Logical bit shift right a 16, 32, or 64 bit register, once
static enum X86ShrRx1 = X86Instruction.Opcode(0xd1, 0x5);
/// Logical bit shift right an 8-bit register, CL times
static enum X86ShrR8CL = X86Instruction.Opcode(0xd2, 0x5);
/// Logical bit shift right a 16, 32, or 64 bit register, CL times
static enum X86ShrRxCL = X86Instruction.Opcode(0xd3, 0x5);

/// Logical bit shift right an 8-bit register, imm8 times
static enum X86ShrR8I8 = X86Instruction.Opcode(0xc0, 0x5);
/// Logical bit shift right a 16, 32, or 64 bit register, imm8 times
static enum X86ShrRxI8 = X86Instruction.Opcode(0xc1, 0x5);

/// Bit scan forward for a 16, 32, or 64 bit register
static enum X86BsfRx = X86Instruction.Opcode(0x0fbc);

/// Bit scan reverse for a 16, 32, or 64 bit register
static enum X86BsrRx = X86Instruction.Opcode(0x0fbd);

/// Count the number of trailing zero bits in a 16, 32, or 64 bit register
static enum X86TzcntRx = X86Instruction.Opcode(0x0fbc).Prefix(LockPrefix.RepeatNZ);

/// Count set bits (population count) in a 16, 32, or 64 bit register
static enum X86PopcntRx = X86Instruction.Opcode(0x0fb8).Prefix(LockPrefix.RepeatNZ);

/// Byte swap, for a 16 or 32 bit register
static enum X86BswapRe = X86Instruction.Opcode(0x0fc8);
