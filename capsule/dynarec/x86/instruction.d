/**

This module defines abstractions and other tools that are useful for
dealing with x86 and x86-64 machine code.

https://en.wikipedia.org/wiki/X86-64

https://wiki.osdev.org/X86-64_Instruction_Encoding

*/

module capsule.dynarec.x86.instruction;

private:

import capsule.dynarec.x86.operand : X86Operand, getX86AddressMode32Mod;
import capsule.dynarec.x86.register : X86Register, getX86RegisterId;
import capsule.dynarec.x86.register : isX86ExtendedRegister, X86SegmentRegister;
import capsule.dynarec.x86.size : X86ImmediateSize, X86DisplacementSize;

import capsule.dynarec.x86.opcodes;

public:

enum X86LockPrefix: ubyte {
    None = 0,
    Lock = 0xf0,
    RepeatZ = 0xf2,
    RepeatNZ = 0xf3,
}

/// TODO
enum X86SegmentOverridePrefix: ubyte {
    None = 0,
    CSSegmentOverride = 0x2e,
    SSSegmentOverride = 0x36,
    DSSegmentOverride = 0x3e,
    ESSegmentOverride = 0x26,
    FSSegmentOverride = 0x64,
    GSSegmentOverride = 0x65,
    BranchNotTaken = 0x2e,
    BranchTaken = 0x3e,
}

X86SegmentOverridePrefix getX86SegmentPrefixForRegister(
    in X86SegmentRegister register
) pure nothrow @safe @nogc {
    alias Prefix = X86SegmentOverridePrefix;
    alias Register = X86SegmentRegister;
    final switch(register) {
        case Register.es: return Prefix.ESSegmentOverride;
        case Register.cs: return Prefix.CSSegmentOverride;
        case Register.ss: return Prefix.SSSegmentOverride;
        case Register.ds: return Prefix.DSSegmentOverride;
        case Register.fs: return Prefix.FSSegmentOverride;
        case Register.gs: return Prefix.GSSegmentOverride;
    }
}

/// Represents an instruction's ModR/M byte.
struct X86ModRM {
    byte mod;
    union {
        byte reg;
        /// Opcode bits 3-5 in the ModR/M byte (unavailable for register-register)
        byte opcode;
    }
    byte rm;
    
    static typeof(this) Opcode(in byte opcode) pure nothrow @safe @nogc {
        X86ModRM modrm;
        modrm.opcode = opcode;
        return modrm;
    }
    
    bool opCast(T: bool)() pure const nothrow @safe @nogc {
        return this.mod != 0 || this.reg != 0 || this.rm != 0;
    }
    
    byte getByte() pure const nothrow @safe @nogc {
        return cast(byte) (
            ((this.mod & 0x3) << 6) |
            ((this.reg & 0x7) << 3) |
            (this.rm & 0x7)
        );
    }
}

/// Represents an instruction's REX prefix byte.
struct X86REX {
    bool w;
    bool r;
    bool x;
    bool b;
    
    bool opCast(T: bool)() pure const nothrow @safe @nogc {
        return this.w || this.r || this.x || this.b;
    }
    
    byte getByte() pure const nothrow @safe @nogc {
        const rex = cast(byte) (
            (cast(int) this.b) |
            ((cast(int) this.x) << 1) |
            ((cast(int) this.r) << 2) |
            ((cast(int) this.w) << 3)
        );
        return rex ? 0x40 | rex : 0;
    }
}

enum X86SIBScale: byte {
    One = 0,
    Two = 1,
    Four = 2,
    Eight = 3,
}

/// Represents an instruction's SIB (scale-index-base) byte.
struct X86SIB {
    alias Register = X86Register;
    alias Scale = X86SIBScale;
    
    Scale scale;
    Register index;
    Register base;
    
    byte getByte() pure const nothrow @safe @nogc {
        return cast(byte) (
            (((cast(byte) this.scale) & 0x3) << 6) |
            ((getX86RegisterId(this.index) & 0x7) << 3) |
            (getX86RegisterId(this.base) & 0x7)
        );
    }
}

/// TODO: Give these appropriate names
enum X86InstructionOpcodeEscape: ushort {
    None = 0,
    A = 0x0f,
    B = 0x0f38,
    C = 0x0f3a,
}

enum X86InstructionStatus: ubyte {
    /// Opcode is valid
    Ok = 0,
    /// Instruction would be valid, but it hasn't been implemented (yet)
    Unimplemented,
    /// Instruction wasn't valid.
    Invalid,
    ///
    SizeMismatch,
}

/// Helper used to distinguish between expected operands for instructions
/// that have two operands, one of them an immediate value.
enum X86InstructionBinaryOpImmediateType: ubyte {
    /// Expect the immediate to be 8 bits
    Byte,
    /// Expect the dst and src operands to be the same size
    SameSize,
    /// Expect the dst and src operands to be the same size,
    /// unless dst is 64 bits, then expect the src immediate to be
    /// 32 bits.
    SameSizeMax32,
}

enum X86InstructionBinaryOpRMType: ubyte {
    /// Expect r/m to be an 8-bit register or memory address
    Byte,
    /// Expect r/m to be a 16-bit register or memory address
    Word,
    /// Expect r/m to be a 32-bit register or memory address
    DWord,
    /// Expect the r and r/m operands to be the same size
    SameSize,
}

struct X86Instruction {
    alias BinaryOpImmediateType = X86InstructionBinaryOpImmediateType;
    alias BinaryOpRMType = X86InstructionBinaryOpRMType;
    alias DisplacementSize = X86DisplacementSize;
    alias ImmediateSize = X86ImmediateSize;
    alias ModRM = X86ModRM;
    alias OpcodeEscape = X86InstructionOpcodeEscape;
    alias Operand = X86Operand;
    alias LockPrefix = X86LockPrefix;
    alias Register = X86Register;
    alias REX = X86REX;
    alias SegmentOverridePrefix = X86SegmentOverridePrefix;
    alias SIB = X86SIB;
    alias Status = X86InstructionStatus;
    
    static enum ubyte OperandSizePrefix = 0x66;
    static enum ubyte AddressSizePrefix = 0x67;
    
    static enum typeof(this) Invalid = {status: Status.Invalid};
    static enum typeof(this) SizeMismatch = {status: Status.SizeMismatch};
    
    /// Create an instruction that represents an opcode.
    static typeof(this) Opcode(in int opcode) {
        X86Instruction instruction;
        instruction.opcode = cast(ubyte) opcode;
        if(opcode >> 8 == 0x0f) {
            instruction.opcodeEscape = OpcodeEscape.A;
        }
        else if(opcode >> 8 == 0x0f38) {
            instruction.opcodeEscape = OpcodeEscape.B;
        }
        else if(opcode >> 8 == 0x0f3a) {
            instruction.opcodeEscape = OpcodeEscape.C;
        }
        else if(opcode >> 8) {
            assert(false, "Unknown opcode prefix.");
        }
        return instruction;
    }
    
    /// Create an instruction that represents an opcode.
    /// Providing the "modrm" argument indicates what the opcode
    /// bits of the ModR/M byte must be set to.
    static typeof(this) Opcode(in int opcode, in byte modrm) {
        X86Instruction instruction = typeof(this).Opcode(opcode);
        instruction.modrm.opcode = modrm;
        instruction.forceModRMByte = true;
        return instruction;
    }
    
    typeof(this) Prefix(in LockPrefix lock) const {
        X86Instruction instruction = this;
        instruction.lockPrefix = lock;
        return instruction;
    }
    
    /// Opcode status
    Status status = Status.Ok;
    /// Opcode byte, not including escapes
    ubyte opcode;
    ///
    OpcodeEscape opcodeEscape;
    /// Information for a ModR/M byte
    ModRM modrm;
    /// Force instruction encoder to output a ModR/M byte, even if it's zero
    bool forceModRMByte = false;
    /// Information for a SIB byte
    SIB sib;
    /// Flags for a REX prefix
    REX rex;
    ///
    SegmentOverridePrefix segmentOverridePrefix = SegmentOverridePrefix.None;
    /// Include an 0x66 operand size override prefix?
    bool operandSizePrefix = false;
    /// Include an 0x67 address size override prefix?
    bool addressSizePrefix = false;
    ///
    LockPrefix lockPrefix = LockPrefix.None;
    ///
    long immediate = 0;
    ///
    ImmediateSize immediateSize = ImmediateSize.None;
    ///
    int displacement = 0;
    ///
    DisplacementSize displacementSize = DisplacementSize.None;
    
    /// Returns true if this opcode is not in an error state.
    bool ok() const {
        return this.status is Status.Ok;
    }
    
    bool hasLockByte() pure const nothrow @safe @nogc {
        return this.lockPrefix !is LockPrefix.None;
    }
    
    byte getLockByte() pure const nothrow @safe @nogc {
        assert(this.hasLockByte);
        return cast(byte) this.lockPrefix;
    }
    
    bool hasSegmentOverridePrefixByte() pure const nothrow @safe @nogc {
        return this.segmentOverridePrefix !is SegmentOverridePrefix.None;
    }
    
    byte getSegmentOverridePrefixByte() pure const nothrow @safe @nogc {
        assert(this.hasSegmentOverridePrefixByte);
        return cast(byte) this.segmentOverridePrefix;
    }
    
    bool hasAddressSizePrefixByte() pure const nothrow @safe @nogc {
        return this.addressSizePrefix;
    }
    
    byte getAddressSizePrefixByte() pure const nothrow @safe @nogc {
        assert(this.hasAddressSizePrefixByte);
        return cast(byte) typeof(this).AddressSizePrefix;
    }
    
    bool hasOperandSizePrefixByte() pure const nothrow @safe @nogc {
        return this.operandSizePrefix;
    }
    
    byte getOperandSizePrefixByte() pure const nothrow @safe @nogc {
        assert(this.hasOperandSizePrefixByte);
        return cast(byte) typeof(this).OperandSizePrefix;
    }
    
    bool hasREXByte() pure const nothrow @safe @nogc {
        return cast(bool) this.rex;
    }
    
    byte getREXByte() pure const nothrow @safe @nogc {
        assert(this.hasREXByte);
        return this.rex.getByte();
    }
    
    bool hasModRMByte() pure const nothrow @safe @nogc {
        return cast(bool) this.modrm || this.forceModRMByte;
    }
    
    byte getModRMByte() pure const nothrow @safe @nogc {
        assert(this.hasModRMByte);
        return this.modrm.getByte();
    }
    
    bool hasSIBByte() pure const nothrow @safe @nogc {
        return this.modrm.rm == 0x4 && this.modrm.mod != 0x3;
    }
    
    byte getSIBByte() pure const nothrow @safe @nogc {
        assert(this.hasSIBByte);
        return this.sib.getByte();
    }
    
    bool hasImmediate() pure const nothrow @safe @nogc {
        return this.immediateSize !is ImmediateSize.None;
    }
    
    bool hasDisplacement() pure const nothrow @safe @nogc {
        return this.displacementSize !is DisplacementSize.None;
    }
    
    void setImmediate(in Operand operand) {
        assert(operand.isImmediate && operand.immediateSize);
        this.immediate = operand.immediate;
        this.immediateSize = operand.immediateSize;
    }
    
    void setRegisterB(in Register register) {
        this.rex.b = isX86ExtendedRegister(register);
        this.modrm.rm = getX86RegisterId(register) & 0x7;
    }
    
    void setRegisterR(in Register register) {
        this.rex.r = isX86ExtendedRegister(register);
        this.modrm.reg = getX86RegisterId(register) & 0x7;
    }
    
    ///
    void setOperandSize(in uint bits) {
        this.rex.w = (bits == 64);
        this.operandSizePrefix = (bits == 16);
    }
    
    void setIndirection(in Operand operand) {
        assert(operand.isValidIndirect);
        this.displacement = operand.displacement;
        this.displacementSize = operand.displacementSize;
        this.modrm.mod = operand.getAddressModeMod();
        // TODO: Account for modes other than long mode
        // https://wiki.osdev.org/X86-64_Instruction_Encoding#Operand-size_and_address-size_override_prefix
        if(operand.baseRegisterSize == 32 || operand.indexRegisterSize == 32) {
            this.addressSizePrefix = true;
        }
        if(operand.hasSegmentOverride) {
            this.segmentOverridePrefix = (
                getX86SegmentPrefixForRegister(operand.segmentRegister)
            );
        }
        if(operand.hasBaseRegister) {
            this.sib.base = operand.base;
            this.rex.b = operand.baseIsExtendedRegister;
            this.rex.x = operand.indexIsExtendedRegister;
            this.modrm.rm = cast(byte) (operand.base & 0x7);
        }
        else {
            this.sib.base = Register.rbp;
            this.rex.b = operand.indexIsExtendedRegister;
        }
        if(operand.hasIndexRegister) {
            this.sib.scale = operand.scale;
            this.sib.index = operand.index;
            this.modrm.rm = 0x4;
        }
        else {
            this.sib.index = Register.rsp;
        }
        if(operand.addressMode is Operand.AddressMode.rip_disp32) {
            // TODO: Only in long mode
            assert(this.modrm.mod == 0);
            this.modrm.rm = 0x4;
        }
        else if(operand.addressMode is Operand.AddressMode.disp32) {
            // TODO: Not in long mode
            assert(this.modrm.mod == 0);
            this.modrm.rm = 0x4;
        }
    }
    
    static bool OpBinaryCheckImmediateType(
        in BinaryOpImmediateType immediateType,
        in Operand rm, in Operand immediate
    ) {
        assert(immediate.isImmediate);
        assert(rm.isRegister || rm.isIndirect);
        const rmSize = rm.isRegister ? rm.registerSize : rm.addressSize;
        final switch(immediateType) {
            case BinaryOpImmediateType.Byte:
                return immediate.immediateSize == 8;
            case BinaryOpImmediateType.SameSize:
                return immediate.immediateSize == rmSize;
            case BinaryOpImmediateType.SameSizeMax32:
                const size = (rmSize == 64 ? 32 : rmSize);
                return immediate.immediateSize == size;
        }
    }
    
    static bool OpBinaryCheckRMType(
        in BinaryOpRMType rmType, in Operand rm, in Operand reg
    ) {
        assert(reg.isRegister);
        assert(rm.isRegister || rm.isIndirect);
        const rmSize = rm.isRegister ? rm.registerSize : rm.addressSize;
        final switch(rmType) {
            case BinaryOpRMType.Byte:
                return rmSize == 8;
            case BinaryOpRMType.Word:
                return rmSize == 16;
            case BinaryOpRMType.DWord:
                return rmSize == 32;
            case BinaryOpRMType.SameSize:
                return rmSize == reg.registerSize;
        }
    }
    
    /// Implement a binary operation like: op register, register
    /// dst is encoded as ModR/M reg and src as ModR/M r/m
    static typeof(this) OpBinaryRM(
        in BinaryOpRMType rmType,
        in X86Instruction OperandR8, in X86Instruction OperandRx,
        in Operand dst, in Operand src
    ) {
        assert(dst.isRegister && src.isRegister);
        if(!OpBinaryCheckRMType(rmType, dst, src)) return SizeMismatch;
        X86Instruction instruction;
        instruction = dst.registerSize == 8 ? OperandR8 : OperandRx;
        instruction.modrm.mod = 0x3;
        instruction.setRegisterR(src.register);
        instruction.setRegisterB(dst.register);
        instruction.setOperandSize(src.registerSize);
        return instruction;
    }
    
    /// Implement a binary operation like: op register, register
    /// dst is encoded as ModR/M r/m and src as ModR/M reg
    static typeof(this) OpBinaryMR(
        in BinaryOpRMType rmType,
        in X86Instruction OperandR8, in X86Instruction OperandRx,
        in Operand dst, in Operand src
    ) {
        return typeof(this).OpBinaryRM(rmType, OperandR8, OperandRx, src, dst);
    }
    
    /// Implement a binary operation like: op register, [address]
    static typeof(this) OpBinaryRA(
        in BinaryOpRMType rmType,
        in X86Instruction OperandRM8, in X86Instruction OperandRMx,
        in Operand dst, in Operand src
    ) {
        assert(dst.isRegister && src.isIndirect);
        if(!src.isValidIndirect) return Invalid;
        if(!OpBinaryCheckRMType(rmType, src, dst)) return SizeMismatch;
        X86Instruction instruction;
        instruction = dst.registerSize == 8 ? OperandRM8 : OperandRMx;
        instruction.setIndirection(src);
        instruction.setRegisterR(dst.register);
        instruction.setOperandSize(dst.registerSize);
        return instruction;
    }
    
    /// Implement a binary operation like: op [address], register
    static typeof(this) OpBinaryAR(
        in BinaryOpRMType rmType,
        in X86Instruction OperandR8, in X86Instruction OperandRx,
        in Operand dst, in Operand src
    ) {
        assert(dst.isIndirect && src.isRegister);
        if(!dst.isValidIndirect) return Invalid;
        if(!OpBinaryCheckRMType(rmType, dst, src)) return SizeMismatch;
        X86Instruction instruction;
        instruction = dst.registerSize == 8 ? OperandR8 : OperandRx;
        instruction.setIndirection(dst);
        instruction.setRegisterR(src.register);
        instruction.setOperandSize(src.registerSize);
        return instruction;
    }
    
    /// Implement a binary operation like: op register, immediate
    /// The register is written to ModR/M r/m
    static typeof(this) OpBinaryRI(
        in BinaryOpImmediateType immediateType,
        in X86Instruction OperandR8I8, in X86Instruction OperandRxI8,
        in Operand dst, in Operand src
    ) {
        assert(dst.isRegister && src.isImmediate);
        if(!typeof(this).OpBinaryCheckImmediateType(immediateType, dst, src)) {
            return SizeMismatch;
        }
        X86Instruction instruction;
        instruction = dst.registerSize == 8 ? OperandR8I8 : OperandRxI8;
        if(instruction.modrm.opcode != 0) {
            instruction.modrm.mod = 0x3;
        }
        instruction.setImmediate(src);
        instruction.setRegisterB(dst.register);
        instruction.setOperandSize(dst.registerSize);
        return instruction;
    }
    
    /// Implement a binary operation like: op register, immediate
    /// The register ID is added to the opcode byte
    static typeof(this) OpBinaryOI(
        in BinaryOpImmediateType immediateType,
        in X86Instruction OperandR8I8, in X86Instruction OperandRxI8,
        in Operand dst, in Operand src
    ) {
        assert(dst.isRegister && src.isImmediate);
        if(!typeof(this).OpBinaryCheckImmediateType(immediateType, dst, src)) {
            return SizeMismatch;
        }
        X86Instruction instruction;
        instruction = dst.registerSize == 8 ? X86MovR8I8 : X86MovRIq;
        instruction.opcode += (dst.registerId & 0x7);
        instruction.rex.b = dst.isExtendedRegister;
        instruction.setOperandSize(dst.registerSize);
        instruction.setImmediate(src);
        return instruction;
    }
    
    /// Implement a binary operation like: op [address], immediate
    static typeof(this) OpBinaryAI(
        in BinaryOpImmediateType immediateType,
        in X86Instruction OperandR8I8, in X86Instruction OperandRIx,
        in Operand dst, in Operand src
    ) {
        assert(dst.isIndirect && src.isImmediate);
        if(!typeof(this).OpBinaryCheckImmediateType(immediateType, dst, src)) {
            return SizeMismatch;
        }
        X86Instruction instruction;
        instruction = dst.addressSize == 8 ? OperandR8I8 : OperandRIx;
        instruction.setIndirection(dst);
        instruction.setOperandSize(dst.addressSize);
        instruction.setImmediate(src);
        return instruction;
    }
    
    /// Operation with just a dst register or memory address,
    /// either 8, 16, 32, or 64 bits.
    /// Examples: not, neg, inc, dec
    static typeof(this) UnaryOpRb(string name, string suffix = "")(
        in Operand dst
    ) {
        static enum OperandR8 = mixin("X86" ~ name ~ "R8" ~ suffix);
        static enum OperandRx = mixin("X86" ~ name ~ "Rx" ~ suffix);
        if(dst.isRegister) {
            X86Instruction instruction;
            instruction = dst.registerSize == 8 ? OperandR8 : OperandRx;
            instruction.setRegisterB(dst.register);
            instruction.setOperandSize(dst.registerSize);
            instruction.modrm.mod = 0x3;
            return instruction;
        }
        else if(dst.isIndirect) {
            X86Instruction instruction;
            instruction = dst.addressSize == 8 ? OperandR8 : OperandRx;
            instruction.setIndirection(dst);
            instruction.setOperandSize(dst.addressSize);
            return instruction;
        }
        else {
            return Invalid;
        }
    }
    
    /// Operation with only a 32 bit or 64 bit destination register.
    /// The low 3 bits of the destination register ID are added to
    /// the instruction's opcode.
    /// Examples: bswap
    static typeof(this) UnaryOpRe(string name)(in Operand dst) {
        static enum OperandRe = mixin("X86" ~ name ~ "Re");
        if(dst.registerSize >= 32) {
            X86Instruction instruction = OperandRe;
            instruction.opcode += (dst.registerId & 0x7);
            instruction.rex.b = dst.isExtendedRegister;
            instruction.setOperandSize(dst.registerSize);
            return instruction;
        }
        else {
            return Invalid;
        }
    }
    
    /// Operation with register or memory dst and an 8-bit immediate.
    /// Register dst can be 8, 16, 32, or 64 bits.
    /// Examples: shl, shr, sar
    static typeof(this) BinaryOpRbI8(string name)(
        in Operand dst, in Operand src
    ) {
        static enum OperandR8I8 = mixin("X86" ~ name ~ "R8I8");
        static enum OperandRxI8 = mixin("X86" ~ name ~ "RxI8");
        static enum ImmByte = BinaryOpImmediateType.Byte;
        if(src.immediateSize != 8) return SizeMismatch;
        /// register, immediate
        if(dst.isRegister) {
            return OpBinaryRI(ImmByte, OperandR8I8, OperandRxI8, dst, src);
        }
        // [address], immediate
        else if(dst.isIndirect) {
            return OpBinaryAI(ImmByte, OperandR8I8, OperandRxI8, dst, src);
        }
        else {
            return Invalid;
        }
    }
    
    /// Operation with register dst and either a register or indirect src.
    /// Register dst can only be 16 bits or larger.
    /// Examples: bsf, bsr
    static typeof(this) BinaryOpRx(string name)(
        in Operand dst, in Operand src
    ) {
        static enum OperandRx = mixin("X86" ~ name ~ "Rx");
        if(dst.registerSize < 16) return Invalid;
        // register, register (Note swapped operands)
        if(src.isRegister && dst.isRegister) {
            return OpBinaryMR(BinaryOpRMType.SameSize, Invalid, OperandRx, dst, src);
        }
        // register, [address]
        else if(src.isIndirect && dst.isRegister) {
            return OpBinaryRA(BinaryOpRMType.SameSize, Invalid, OperandRx, dst, src);
        }
        // ?
        else {
            return Invalid;
        }
    }
    
    /// Operation with register or indirect dst and register, indirect,
    /// or immediate src. So-named because it covers 9 total opcodes
    /// covering the same conceptual operation.
    /// Examples: add, sub, and, or, xor
    static typeof(this) BinaryOp9(string name)(
        in Operand dst, in Operand src
    ) {
        alias ImmType = BinaryOpImmediateType;
        static enum OperandR8 = mixin("X86" ~ name ~ "R8");
        static enum OperandRx = mixin("X86" ~ name ~ "Rx");
        static enum OperandRM8 = mixin("X86" ~ name ~ "RM8");
        static enum OperandRMx = mixin("X86" ~ name ~ "RMx");
        static enum OperandAL = mixin("X86" ~ name ~ "AL");
        static enum OperandAX = mixin("X86" ~ name ~ "AX");
        static enum OperandR8I8 = mixin("X86" ~ name ~ "R8I8");
        static enum OperandRIx = mixin("X86" ~ name ~ "RIx");
        static enum OperandRxI8 = mixin("X86" ~ name ~ "RxI8");
        // register, register
        if(src.isRegister && dst.isRegister) {
            return OpBinaryRM(BinaryOpRMType.SameSize, OperandR8, OperandRx, dst, src);
        }
        // register, [address]
        else if(src.isIndirect && dst.isRegister) {
            return OpBinaryRA(BinaryOpRMType.SameSize, OperandRM8, OperandRMx, dst, src);
        }
        // [address], register
        else if(dst.isIndirect && src.isRegister) {
            return OpBinaryAR(BinaryOpRMType.SameSize, OperandR8, OperandRx, dst, src);
        }
        // [address], immediate
        else if(src.isImmediate && dst.isIndirect) {
            return OpBinaryAI(ImmType.SameSize, OperandR8I8, OperandRIx, dst, src);
        }
        // al/ax/eax/rax, immediate
        else if(src.isImmediate && dst.isRegister && dst.registerId == 0) {
            return OpBinaryRI(ImmType.SameSizeMax32, OperandAL, OperandAX, dst, src);
        }
        // register, immediate8
        else if(src.isImmediate && dst.isRegister && src.immediateSize == 8) {
            return OpBinaryRI(ImmType.Byte, OperandR8I8, OperandRxI8, dst, src);
        }
        // register, immediate
        else if(src.isImmediate && dst.isRegister) {
            return OpBinaryRI(ImmType.SameSizeMax32, OperandR8I8, OperandRIx, dst, src);
        }
        // ?
        else {
            return Invalid;
        }
    }
    
    /// Examples: movsx, movzx
    static typeof(this) BinaryOpMovX(string name)(
        in Operand dst, in Operand src
    ) {
        static enum OperandR8 = mixin("X86" ~ name ~ "R8");
        static enum OperandR16 = mixin("X86" ~ name ~ "R16");
        if(dst.registerSize < 16) return Invalid;
        if(src.registerSize == 8) {
            return OpBinaryMR(BinaryOpRMType.Byte, OperandR8, OperandR8, dst, src);
        }
        else if(src.addressSize == 8) {
            return OpBinaryRA(BinaryOpRMType.Byte, OperandR8, OperandR8, dst, src);
        }
        else if(src.registerSize == 16) {
            return OpBinaryMR(BinaryOpRMType.Word, OperandR16, OperandR16, dst, src);
        }
        else if(src.addressSize == 16) {
            return OpBinaryRA(BinaryOpRMType.Word, OperandR16, OperandR16, dst, src);
        }
        else {
            return Invalid;
        }
    }
    
    /// One's complement negation / bitwise negation
    alias Not = UnaryOpRb!"Not";
    /// Two's complement negation / arithmetic negation
    alias Neg = UnaryOpRb!"Neg";
    /// Increment by 1
    alias Inc = UnaryOpRb!"Inc";
    /// Decrement by 1
    alias Dec = UnaryOpRb!"Dec";
    /// Shift arithmetic right (shift once)
    alias Sar1 = UnaryOpRb!("Sar", "1");
    /// Shift arithmetic right (shift CL times)
    alias SarCL = UnaryOpRb!("Sar", "CL");
    /// Shift logical right (shift once)
    alias Shr1 = UnaryOpRb!("Shr", "1");
    /// Shift logical right (shift CL times)
    alias ShrCL = UnaryOpRb!("Shr", "CL");
    /// Shift logical left (shift once)
    alias Shl1 = UnaryOpRb!("Shl", "1");
    /// Shift logical left (shift CL times)
    alias ShlCL = UnaryOpRb!("Shl", "CL");
    /// Integer addition
    alias Add = BinaryOp9!"Add";
    /// Bitwise OR
    alias Or = BinaryOp9!"Or";
    /// Add with carry
    alias Adc = BinaryOp9!"Adc";
    /// Integer subtraction with borrow
    alias Sbb = BinaryOp9!"Sbb";
    /// Bitwise AND
    alias And = BinaryOp9!"And";
    /// Integer subtraction
    alias Sub = BinaryOp9!"Sub";
    /// Bitwise XOR
    alias Xor = BinaryOp9!"Xor";
    /// Compare two operands
    alias Cmp = BinaryOp9!"Cmp";
    /// Bit scan forward (count trailing zeros)
    alias Bsf = BinaryOpRx!"Bsf";
    /// Bit scan reverse (count leading zeros)
    alias Bsr = BinaryOpRx!"Bsr";
    /// Move with sign extension
    alias Movsx = BinaryOpMovX!"Movsx";
    /// Move with zero extension
    alias Movzx = BinaryOpMovX!"Movzx";
    /// Count the number of trailing zero bits
    alias Tzcnt = BinaryOpRx!"Tzcnt";
    /// Return the count of number of bits set to 1 (population count)
    alias Popcnt = BinaryOpRx!"Popcnt";
    /// Byte swap
    alias Bswap = UnaryOpRe!"Bswap";
    
    /// No operation
    /// Nop(1): Opcode 90
    /// Nop(2): Prefix 66 / Opcode 90
    /// Nop(3): Opcode 0f 1f / ModR/M 00
    /// Nop(4): Opcode 0f 1f / ModR/M 40 / Disp8 00
    /// Nop(5): Opcode 0f 1f / ModR/M 44 / SIB 00 / Disp8 00
    /// Nop(6): Prefix 66 / Opcode 0f 1f / ModR/M 44 / SIB 00 / Disp8 00
    /// Nop(7): Opcode 0f 1f / ModR/M 80 / Disp32 00 00 00 00
    /// Nop(8): Opcode 0f 1f / ModR/M 84 / SIB 00 / Disp32 00 00 00 00
    /// Nop(9): Prefix 66 / Opcode 0f 1f / ModR/M 84 / SIB 00 / Disp32 00 00 00 00
    static typeof(this) Nop(in ubyte length = 1) {
        if(length <= 0 || length > 9) return Invalid;
        if(length <= 2) {
            X86Instruction instruction = X86Nop1;
            instruction.operandSizePrefix = (length == 2);
            return instruction;
        }
        X86Instruction instruction = X86NopRx;
        instruction.forceModRMByte = true;
        instruction.modrm.mod = (length >= 7 ? 0x2 : length >= 4 ? 0x01 : 0);
        instruction.modrm.rm = (length >= 5 && length != 7 ? 0x4 : 0);
        instruction.operandSizePrefix = (length == 6 || length == 9);
        instruction.displacementSize = (
            length >= 7 ? DisplacementSize.DWord :
            length >= 4 ? DisplacementSize.Byte : DisplacementSize.None
        );
        return instruction;
    }
    
    /// Shift arithmetic right
    static typeof(this) Sar(in Operand dst, in Operand src) {
        if(src.isImmediate && src.immediate == 1) {
            return typeof(this).Sar1(dst);
        }
        else if(src.isRegister && src.register is Register.cl) {
            return typeof(this).SarCL(dst);
        }
        else {
            return typeof(this).BinaryOpRbI8!("Sar")(dst, src);
        }
    }
    
    /// Shift logical right
    static typeof(this) Shr(in Operand dst, in Operand src) {
        if(src.isImmediate && src.immediate == 1) {
            return typeof(this).Shr1(dst);
        }
        else if(src.isRegister && src.register is Register.cl) {
            return typeof(this).ShrCL(dst);
        }
        else {
            return typeof(this).BinaryOpRbI8!("Shr")(dst, src);
        }
    }
    
    /// Shift logical left
    static typeof(this) Shl(in Operand dst, in Operand src) {
        if(src.isImmediate && src.immediate == 1) {
            return typeof(this).Shl1(dst);
        }
        else if(src.isRegister && src.register is Register.cl) {
            return typeof(this).ShlCL(dst);
        }
        else {
            return typeof(this).BinaryOpRbI8!("Shl")(dst, src);
        }
    }
    
    /// Move
    static typeof(this) Mov(in Operand dst, in Operand src) {
        // register, register
        if(src.isRegister && dst.isRegister) {
            return OpBinaryRM(BinaryOpRMType.SameSize, X86MovR8, X86MovRx, dst, src);
        }
        // register, [address]
        else if(src.isIndirect && dst.isRegister) {
            return OpBinaryRA(BinaryOpRMType.SameSize, X86MovRM8, X86MovRMx, dst, src);
        }
        // [address], register
        else if(dst.isIndirect && src.isRegister) {
            return OpBinaryAR(BinaryOpRMType.SameSize, X86MovR8, X86MovRx, dst, src);
        }
        // [address], immediate
        else if(dst.isIndirect && src.isImmediate) {
            static enum ImmSameSize = BinaryOpImmediateType.SameSize;
            return OpBinaryAI(ImmSameSize, X86MovRM8I8, X86MovRMIx, dst, src);
        }
        // register, segment
        else if(src.isSegmentRegister && dst.isRegister) {
            if(dst.registerSize < 16) return Invalid;
            X86Instruction instruction = X86MovRxS;
            instruction.modrm.mod = 0x3;
            instruction.modrm.reg = cast(byte) (src.segmentRegisterId & 0x7);
            instruction.setRegisterB(dst.register);
            instruction.setOperandSize(dst.registerSize);
            return instruction;
        }
        // segment, register
        else if(src.isRegister && dst.isSegmentRegister) {
            if(src.registerSize < 16) return Invalid;
            X86Instruction instruction = X86MovSRx;
            instruction.modrm.mod = 0x3;
            instruction.modrm.reg = cast(byte) (dst.segmentRegisterId & 0x7);
            instruction.setRegisterB(src.register);
            instruction.rex.w = (src.registerSize == 64);
            return instruction;
        }
        // register, immediate
        else if(dst.isRegister && src.isImmediate) {
            if(dst.registerSize == 64 && src.immediateSize == 32) {
                X86Instruction instruction = OpBinaryRI(
                    BinaryOpImmediateType.SameSizeMax32,
                    X86MovR8I8, X86MovRMIx, dst, src
                );
                // Always has a ModR/M byte, even when modrm.opcode == 0
                instruction.modrm.mod = 0x3;
                return instruction;
            }
            else {
                static enum ImmSameSize = BinaryOpImmediateType.SameSize;
                return OpBinaryOI(ImmSameSize, X86MovR8I8, X86MovRIq, dst, src);
            }
        }
        // ?
        else {
            return Invalid;
        }
    }
}

enum X86Mode: ubyte {
    Real,
    Protected,
    //Unreal,
    Virtual8086,
    //SystemManagement,
    Long,
    //Virtualization,
}

/// Capacity should generally be at minimum 15, since a single instruction
/// can be up to 15 bytes long.
struct X86InstructionBuffer(size_t capacity) {
    alias DisplacementSize = X86DisplacementSize;
    alias ImmediateSize = X86ImmediateSize;
    alias Instruction = X86Instruction;
    alias Operand = X86Operand;
    alias Register = X86Register;
    alias REX = X86REX;
    
    ubyte length;
    byte[capacity] buffer;
    
    this(size_t N)(in byte[N] bytes) {
        this = bytes;
    }
    
    void clear() {
        this.length = 0;
    }
    
    const(byte)[] getBytes() const {
        return this.buffer[0 .. this.length];
    }
    
    void opAssign(size_t N)(in byte[N] bytes) {
        static assert(N <= this.buffer.length);
        this.buffer[0 .. N] = bytes;
    }
    
    void pushByte(in byte value) {
        assert(this.length < this.buffer.length);
        this.buffer[this.length++] = value;
    }
    
    void pushShort(in short value) {
        assert(this.length + 2 <= this.buffer.length);
        this.buffer[this.length++] = cast(byte) (value);
        this.buffer[this.length++] = cast(byte) (value >> 8);
    }
    
    void pushInt(in int value) {
        assert(this.length + 4 <= this.buffer.length);
        this.buffer[this.length++] = cast(byte) (value);
        this.buffer[this.length++] = cast(byte) (value >> 8);
        this.buffer[this.length++] = cast(byte) (value >> 16);
        this.buffer[this.length++] = cast(byte) (value >> 24);
    }
    
    void pushLong(in long value) {
        assert(this.length + 8 <= this.buffer.length);
        this.buffer[this.length++] = cast(byte) (value);
        this.buffer[this.length++] = cast(byte) (value >> 8);
        this.buffer[this.length++] = cast(byte) (value >> 16);
        this.buffer[this.length++] = cast(byte) (value >> 24);
        this.buffer[this.length++] = cast(byte) (value >> 32);
        this.buffer[this.length++] = cast(byte) (value >> 40);
        this.buffer[this.length++] = cast(byte) (value >> 48);
        this.buffer[this.length++] = cast(byte) (value >> 56);
    }
    
    void pushInstruction(in Instruction instr) {
        final switch(instr.status) {
            case Instruction.Status.Ok: break;
            case Instruction.Status.Unimplemented: assert(false, "Unimplemented.");
            case Instruction.Status.Invalid: assert(false, "Invalid.");
            case Instruction.Status.SizeMismatch: assert(false, "Size Mismatch.");
        }
        if(instr.hasLockByte) {
            this.pushByte(instr.getLockByte);
        }
        if(instr.hasSegmentOverridePrefixByte) {
            this.pushByte(instr.getSegmentOverridePrefixByte);
        }
        if(instr.hasAddressSizePrefixByte) {
            this.pushByte(instr.getAddressSizePrefixByte);
        }
        if(instr.hasOperandSizePrefixByte) {
            this.pushByte(instr.getOperandSizePrefixByte);
        }
        if(instr.hasREXByte) {
            this.pushByte(instr.getREXByte);
        }
        if(cast(ushort) instr.opcodeEscape > ubyte.max) {
            const escByte = cast(byte) (cast(short) instr.opcodeEscape >> 8);
            this.pushByte(escByte);
        }
        if(instr.opcodeEscape) {
            const escByte = cast(byte) instr.opcodeEscape;
            this.pushByte(escByte);
        }
        if(true) {
            this.pushByte(cast(byte) instr.opcode);
        }
        if(instr.hasModRMByte) {
            this.pushByte(instr.getModRMByte);
        }
        if(instr.hasSIBByte) {
            this.pushByte(instr.getSIBByte);
        }
        final switch(instr.displacementSize) {
            case ImmediateSize.None:
                break;
            case DisplacementSize.Byte:
                this.pushByte(cast(byte) instr.displacement);
                break;
            case DisplacementSize.Word:
                this.pushShort(cast(short) instr.displacement);
                break;
            case DisplacementSize.DWord:
                this.pushInt(cast(int) instr.displacement);
                break;
            case DisplacementSize.QWord:
                this.pushLong(cast(long) instr.displacement);
                break;
        }
        final switch(instr.immediateSize) {
            case ImmediateSize.None:
                break;
            case ImmediateSize.Byte:
                this.pushByte(cast(byte) instr.immediate);
                break;
            case ImmediateSize.Word:
                this.pushShort(cast(short) instr.immediate);
                break;
            case ImmediateSize.DWord:
                this.pushInt(cast(int) instr.immediate);
                break;
            case ImmediateSize.QWord:
                this.pushLong(cast(long) instr.immediate);
                break;
        }
    }
}
