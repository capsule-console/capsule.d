module capsule.dynarec.x86.instruction;

private:

import capsule.dynarec.x86.mode : X86Mode;
import capsule.dynarec.x86.opcode : X86Opcode;
import capsule.dynarec.x86.opcode : X86OpcodeOperandTypeIsImplicit;
import capsule.dynarec.x86.opcode : X86OpcodeOperandTypeIsReg;
import capsule.dynarec.x86.opcode : X86OpcodeOperandTypeIsRM;
import capsule.dynarec.x86.opcode : X86OpcodeOperandTypeIsImmediate;
import capsule.dynarec.x86.opcode : X86OpcodeOperandTypeIsMemoryOffset;
import capsule.dynarec.x86.opcode : X86OpcodeOperandTypeSize;
import capsule.dynarec.x86.opcodes : X86AllOpcodes, X86FilterAllOpcodes;
import capsule.dynarec.x86.register : X86Register, X86SegmentRegister;
import capsule.dynarec.x86.register : X86RegisterSize, X86RegisterIsExtended;
import capsule.dynarec.x86.register : X86RegisterLongModeOnly;
import capsule.dynarec.x86.size : X86DataSize;
import capsule.dynarec.x86.size : X86DisplacementSize, X86ImmediateSize;

public pure nothrow @safe @nogc:

extern(C): // Make sure this works with --betterC

alias X86InstructionOperandSize = X86DataSize;

enum X86InstructionOperandType: ubyte {
    None = 0,
    Register,
    SegmentRegister,
    MemoryAddress,
    MemoryOffset,
    Immediate,
    Relative,
}

/// base flag: 0x1
/// index flag: 0x2
/// disp32 flag: 0x4
/// disp8 flag: 0x8
/// rip/eip flag: 0x10
enum X86MemoryAddressMode: ubyte {
    None = 0,
    /// [base]
    base = 0x1,
    /// [base + index * scale]
    base_index = 0x3,
    /// [disp32]
    /// When not in protected mode, this is treated as rip_disp32
    disp32 = 0x4,
    /// [base + disp32]
    base_disp32 = 0x5,
    /// [index + disp32]
    index_disp32 = 0x6,
    /// [base + index * scale + disp32]
    base_index_disp32 = 0x7,
    /// [base + disp8]
    base_disp8 = 0x9,
    /// [base + index * scale + disp8]
    base_index_disp8 = 0xb,
    /// [EIP/RIP + disp32]
    /// Not available in protected mode; conflicts with disp32
    rip_disp32 = 0x14,
}

bool X86MemoryAddressHasBase(in X86MemoryAddressMode mode) {
    return (mode & 0x1) != 0;
}

bool X86MemoryAddressHasIndex(in X86MemoryAddressMode mode) {
    return (mode & 0x2) != 0;
}

bool X86MemoryAddressHasDisp32(in X86MemoryAddressMode mode) {
    return (mode & 0x4) != 0;
}

bool X86MemoryAddressHasDisp8(in X86MemoryAddressMode mode) {
    return (mode & 0x8) != 0;
}

/// Given a memory addressing mode, get the value that should be written
/// to an instruction's ModR/M byte "mod" field (the two highest bits).
ubyte X86InstructionMemoryAddressModeMod(in X86MemoryAddressMode mode) {
    alias Mode = X86MemoryAddressMode;
    final switch(mode) {
        case Mode.None: return 0;
        case Mode.base: return 0;
        case Mode.base_index: return 0;
        case Mode.disp32: return 0;
        case Mode.base_disp32: return 2;
        case Mode.index_disp32: return 0;
        case Mode.base_index_disp32: return 2;
        case Mode.base_disp8: return 1;
        case Mode.base_index_disp8: return 1;
        case Mode.rip_disp32: return 0;
    }
}

static bool X86OperandArrayMatch(
    in X86Opcode* opcode, in X86InstructionOperand[] operands
) {
    assert(operands.length <= 4, "Too many operands.");
    if(opcode is null || operands.length != opcode.countOperands) {
        return false;
    }
    foreach(i, _; operands) {
        if(!X86OperandMatch(
            opcode.hasSignExtendedImmediate, opcode.operands[i], operands[i]
        )) {
            return false;
        }
    }
    return true;
}

/// Determine whether a given operand vararg list is a match for the given
/// opcode.
static bool X86OperandListMatch(T...)(
    in X86Opcode* opcode, in ref T operands
) {
    static assert(operands.length <= 4, "Too many operands.");
    if(opcode is null || operands.length != opcode.countOperands) {
        return false;
    }
    const signExtImm = opcode.hasSignExtendedImmediate;
    foreach(i, _; operands) {
        static assert(IsX86InstructionOperandType!(T[i]), "Wrong argument type.");
        static if(is(T[i] == X86InstructionOperand)) {
            const match = X86OperandMatch(
                signExtImm, opcode.operands[i], operands[i]
            );
        }
        else static if(is(T[i] == X86Register)) {
            const match = X86OperandMatchRegister(
                signExtImm, opcode.operands[i], operands[i]
            );
        }
        else static if(is(T[i] == X86SegmentRegister)) {
            const match = X86OperandMatchSegmentRegister(
                signExtImm, opcode.operands[i], operands[i]
            );
        }
        else {
            static assert(false);
        }
        if(!match) {
            return false;
        }
    }
    return true;
}

static bool X86OperandMatchRegister(
    in bool signExtendImmediates,
    in X86Opcode.OperandType operandType,
    in X86Register register
) {
    return X86OperandMatch(
        signExtendImmediates, operandType, X86InstructionOperand(register)
    );
}

static bool X86OperandMatchSegmentRegister(
    in bool signExtendImmediates,
    in X86Opcode.OperandType operandType,
    in X86SegmentRegister segmentRegister
) {
    return X86OperandMatch(
        signExtendImmediates, operandType, X86InstructionOperand(segmentRegister)
    );
}

/// Determine whether a given operand is a match for an expected operand type.
static bool X86OperandMatch(
    in bool signExtendImmediates,
    in X86Opcode.OperandType operandType,
    in X86InstructionOperand operand
) {
    alias Opcode = X86Opcode;
    alias Operand = X86InstructionOperand;
    alias Register = X86Register;
    alias SegmentRegister = X86SegmentRegister;
    final switch(operandType) {
        case Opcode.OperandType.None:
            return operand.type is Operand.Type.None;
        case Opcode.OperandType.al:
            return operand.isRegister(Register.al);
        case Opcode.OperandType.ax:
            return operand.isRegister(Register.ax);
        case Opcode.OperandType.eax:
            return operand.isRegister(Register.eax);
        case Opcode.OperandType.rax:
            return operand.isRegister(Register.rax);
        case Opcode.OperandType.cl:
            return operand.isRegister(Register.cl);
        case Opcode.OperandType.cs:
            return operand.isSegmentRegister(SegmentRegister.cs);
        case Opcode.OperandType.ss:
            return operand.isSegmentRegister(SegmentRegister.ss);
        case Opcode.OperandType.ds:
            return operand.isSegmentRegister(SegmentRegister.ds);
        case Opcode.OperandType.es:
            return operand.isSegmentRegister(SegmentRegister.es);
        case Opcode.OperandType.fs:
            return operand.isSegmentRegister(SegmentRegister.fs);
        case Opcode.OperandType.gs:
            return operand.isSegmentRegister(SegmentRegister.gs);
        case Opcode.OperandType.lit1:
            return operand.isImmediate && operand.immediate == 1;
        case Opcode.OperandType.sreg:
            return operand.isSegmentRegister;
        case Opcode.OperandType.r8:
            return operand.isRegisterSize(8);
        case Opcode.OperandType.r16:
            return operand.isRegisterSize(16);
        case Opcode.OperandType.r32:
            return operand.isRegisterSize(32);
        case Opcode.OperandType.r64:
            return operand.isRegisterSize(64);
        case Opcode.OperandType.rm8:
            return operand.isRegisterOrMemoryAddressSize(8);
        case Opcode.OperandType.rm16:
            return operand.isRegisterOrMemoryAddressSize(16);
        case Opcode.OperandType.rm32:
            return operand.isRegisterOrMemoryAddressSize(32);
        case Opcode.OperandType.rm64:
            return operand.isRegisterOrMemoryAddressSize(64);
        case Opcode.OperandType.rm_r8:
            return operand.isRegisterSize(8);
        case Opcode.OperandType.rm_r16:
            return operand.isRegisterSize(16);
        case Opcode.OperandType.rm_r32:
            return operand.isRegisterSize(32);
        case Opcode.OperandType.rm_r64:
            return operand.isRegisterSize(64);
        case Opcode.OperandType.m16_16:
            return operand.isMemoryAddressSize(16); // ?
        case Opcode.OperandType.m16_32:
            return operand.isMemoryAddressSize(32); // ?
        case Opcode.OperandType.m16_64:
            return operand.isMemoryAddressSize(64); // ?
        case Opcode.OperandType.moffs8:
            return operand.isMemoryOffsetSize(8);
        case Opcode.OperandType.moffs16:
            return operand.isMemoryOffsetSize(16);
        case Opcode.OperandType.moffs32:
            return operand.isMemoryOffsetSize(32);
        case Opcode.OperandType.moffs64:
            return operand.isMemoryOffsetSize(64);
        case Opcode.OperandType.imm8:
            return operand.isImmediateSize(8, signExtendImmediates);
        case Opcode.OperandType.imm16:
            return operand.isImmediateSize(16, signExtendImmediates);
        case Opcode.OperandType.imm32:
            return operand.isImmediateSize(32, signExtendImmediates);
        case Opcode.OperandType.imm64:
            return operand.isImmediateSize(64, signExtendImmediates);
        case Opcode.OperandType.rel8:
            return operand.isRelativeSize(8, signExtendImmediates);
        case Opcode.OperandType.rel16:
            return operand.isRelativeSize(16, signExtendImmediates);
        case Opcode.OperandType.rel32:
            return operand.isRelativeSize(32, signExtendImmediates);
        case Opcode.OperandType.rel64:
            return operand.isRelativeSize(64, signExtendImmediates);
        case Opcode.OperandType.far16:
            return operand.isImmediateSize(16, signExtendImmediates);
        case Opcode.OperandType.far32:
            return operand.isImmediateSize(32, signExtendImmediates);
        case Opcode.OperandType.far64:
            return operand.isImmediateSize(64, signExtendImmediates);
        case Opcode.OperandType.farseg16:
            return operand.isImmediateSize(16, signExtendImmediates);
    }
}

struct X86InstructionMemoryAddressData {
    alias DisplacementSize = X86DisplacementSize;
    alias Mode = X86MemoryAddressMode;
    
    align(1):
    X86Register base;
    X86Register index;
    ubyte scale = 0;
    Mode mode;
    align(4):
    int displacement = 0;
    
    pure const nothrow @safe @nogc:
    
    bool ok() const {
        return (
            this.mode !is Mode.None &&
            this.base < X86Register.ax &&
            this.index < X86Register.ax &&
            this.scale <= 0x3
        );
    }
    
    static ubyte getScale(in uint value) {
        assert(value == 1 || value == 2 || value == 4 || value == 8);
        switch(value) {
            case 1: return ubyte(0);
            case 2: return ubyte(1);
            case 4: return ubyte(2);
            case 8: return ubyte(3);
            default: assert(false);
        }
    }
    
    /// Returns true if the memory address includes a base register.
    bool hasBase() {
        return X86MemoryAddressHasBase(this.mode);
    }
    
    /// Returns true if the memory address includes an index register.
    bool hasIndex() {
        return X86MemoryAddressHasIndex(this.mode);
    }
    
    /// Returns true if the memory address includes a 32-bit displacement.
    bool hasDisp32() {
        return X86MemoryAddressHasDisp32(this.mode);
    }
    
    /// Returns true if the memory address includes an 8-bit displacement.
    bool hasDisp8() {
        return X86MemoryAddressHasDisp8(this.mode);
    }
    
    /// Returns true if the memory address includes an extended
    /// base register, i.e. r8-r15.
    bool hasExtendedBase() {
        return this.hasBase && X86RegisterIsExtended(this.base);
    }
    
    /// Returns true if the memory address includes an extended
    /// index register, i.e. r8-r15.
    bool hasExtendedIndex() {
        return this.hasIndex && X86RegisterIsExtended(this.index);
    }
    
    /// Returns the address's displacement size: dword, byte, or none.
    DisplacementSize getDisplacementSize() {
        if(this.hasDisp32) {
            return DisplacementSize.DWord;
        }
        else if(this.hasDisp8) {
            return DisplacementSize.Byte;
        }
        else {
            return DisplacementSize.None;
        }
    }
    
    ubyte getScaleValue() {
        assert(this.scale <= 0x3);
        return cast(ubyte) (1 << this.scale);
    }
}

struct X86InstructionMemoryOffsetData {
    int offset;
    X86SegmentRegister segmentRegister;
}

struct X86InstructionOperand {
    extern(C): // Make sure this works with --betterC
    
    alias MemoryAddressData = X86InstructionMemoryAddressData;
    alias MemoryAddressMode = X86MemoryAddressMode;
    alias MemoryOffsetData = X86InstructionMemoryOffsetData;
    alias Type = X86InstructionOperandType;
    alias Size = X86InstructionOperandSize;
    
    union {
        X86Register register;
        X86SegmentRegister segmentRegister;
        MemoryAddressData memoryAddress;
        MemoryOffsetData memoryOffset;
        long immediate;
    }
    
    align(1):
    Type type;
    Size size;
    
    pure nothrow @safe @nogc:
    
    this(in typeof(this) operand) {
        this = operand;
    }
    
    this(in X86Register register) {
        this.type = Type.Register;
        this.size = X86RegisterSize(register);
        this.register = register;
    }
    
    this(in X86SegmentRegister segmentRegister) {
        this.type = Type.SegmentRegister;
        this.size = Size.Word;
        this.segmentRegister = segmentRegister;
    }
    
    const:
    
    static typeof(this) Register(in X86Register register) {
        return typeof(this)(register);
    }
    
    static typeof(this) SegmentRegister(in X86SegmentRegister segmentRegister) {
        return typeof(this)(segmentRegister);
    }
    
    static typeof(this) MemoryOffset(
        in Size size, in X86SegmentRegister segmentRegister, in int offset
    ) {
        assert(size !is Size.None);
        X86InstructionOperand operand;
        operand.type = Type.MemoryOffset;
        operand.size = size;
        operand.memoryOffset.segmentRegister = segmentRegister;
        operand.memoryOffset.offset = offset;
        return operand;
    }
    
    static typeof(this) MemoryAddress(in Size size, in int displacement) {
        assert(size !is Size.None);
        X86InstructionOperand operand;
        operand.type = Type.MemoryAddress;
        operand.size = size;
        operand.memoryAddress.mode = MemoryAddressMode.disp32;
        operand.memoryAddress.displacement = displacement;
        return operand;
    }
    
    static typeof(this) MemoryAddressIPRelative(
        in Size size, in int displacement
    ) {
        assert(size !is Size.None);
        X86InstructionOperand operand;
        operand.type = Type.MemoryAddress;
        operand.size = size;
        operand.memoryAddress.mode = MemoryAddressMode.rip_disp32;
        operand.memoryAddress.displacement = displacement;
        return operand;
    }
    
    static typeof(this) MemoryAddress(
        in Size size, in X86Register base, in int displacement = 0
    ) {
        assert(size !is Size.None);
        X86InstructionOperand operand;
        operand.type = Type.MemoryAddress;
        operand.size = size;
        operand.memoryAddress.base = base;
        operand.memoryAddress.displacement = displacement;
        operand.memoryAddress.mode = (
            displacement == 0 && ((base & 0x7) != X86Register.rbp) ?
            MemoryAddressMode.base :
            displacement == cast(byte) displacement ?
            MemoryAddressMode.base_disp8 :
            MemoryAddressMode.base_disp32
        );
        return operand;
    }
    
    static typeof(this) MemoryAddress(
        in Size size, in X86Register base,
        in X86Register index, in uint scale,
        in int displacement = 0
    ) {
        assert(size !is Size.None);
        assert((index & 0x7) != X86Register.rsp, "Invalid index register.");
        X86InstructionOperand operand;
        operand.type = Type.MemoryAddress;
        operand.size = size;
        operand.memoryAddress.base = base;
        operand.memoryAddress.index = index;
        operand.memoryAddress.scale = MemoryAddressData.getScale(scale);
        operand.memoryAddress.displacement = displacement;
        operand.memoryAddress.mode = (
            displacement == 0 && ((base & 0x7) != X86Register.rbp) ?
            MemoryAddressMode.base_index :
            displacement == cast(byte) displacement ?
            MemoryAddressMode.base_index_disp8 :
            MemoryAddressMode.base_index_disp32
        );
        return operand;
    }
    
    static typeof(this) MemoryAddressIndex(
        in Size size, in X86Register index, in uint scale,
        in int displacement = 0
    ) {
        assert(size !is Size.None);
        assert((index & 0x7) != X86Register.rsp, "Invalid index register.");
        X86InstructionOperand operand;
        operand.type = Type.MemoryAddress;
        operand.size = size;
        operand.memoryAddress.index = index;
        operand.memoryAddress.scale = MemoryAddressData.getScale(scale);
        operand.memoryAddress.displacement = displacement;
        operand.memoryAddress.mode = MemoryAddressMode.index_disp32;
        return operand;
    }
    
    static typeof(this) Immediate(in Size size, in long value) {
        X86InstructionOperand operand;
        operand.type = Type.Immediate;
        operand.size = size;
        operand.immediate = value;
        return operand;
    }
    
    static typeof(this) Relative(in Size size, in long value) {
        X86InstructionOperand operand;
        operand.type = Type.Relative;
        operand.size = size;
        operand.immediate = value;
        return operand;
    }
    
    bool opCast(T: bool)() const {
        return this.type !is Type.None;
    }
    
    bool isRegister() {
        return this.type is Type.Register;
    }
    
    bool isRegister(in X86Register register) {
        return this.type is Type.Register && this.register == register;
    }
    
    bool isSegmentRegister() {
        return this.type is Type.SegmentRegister;
    }
    
    bool isSegmentRegister(in X86SegmentRegister segmentRegister) {
        return (this.type is Type.SegmentRegister &&
            this.segmentRegister is segmentRegister
        );
    }
    
    bool isMemoryOffset() {
        return this.type is Type.MemoryOffset;
    }
    
    bool isMemoryAddress() {
        return this.type is Type.MemoryAddress;
    }
    
    bool isRegisterOrMemoryAddress() {
        return this.type is Type.Register || this.type is Type.MemoryAddress;
    }
    
    bool isImmediate() {
        return this.type is Type.Immediate;
    }
    
    bool isRelative() {
        return this.type is Type.Relative;
    }
    
    bool isRegisterSize(in uint size) {
        return this.type is Type.Register && this.size == size;
    }
    
    bool isMemoryAddressSize(in uint size) {
        return this.type is Type.MemoryAddress && this.size == size;
    }
    
    bool isMemoryOffsetSize(in uint size) {
        return this.type is Type.MemoryOffset && this.size == size;
    }
    
    bool isRegisterOrMemoryAddressSize(in uint size) {
        return this.size == size && (
            this.type is Type.Register || this.type is Type.MemoryAddress
        );
    }
    
    bool isInferredSize(in Type type, in uint size, in bool signExtended) {
        if(this.type !is type) {
            return false;
        }
        else if(this.size !is Size.None) {
            return this.size == size;
        }
        else if(size == 8) {
            return (signExtended ?
                this.immediate >= byte.min && this.immediate <= byte.max :
                this.immediate >= byte.min && this.immediate <= ubyte.max
            );
        }
        else if(size == 16) {
            return (signExtended ?
                this.immediate >= short.min && this.immediate <= short.max :
                this.immediate >= short.min && this.immediate <= ushort.max
            );
        }
        else if(size == 32) {
            return (signExtended ?
                this.immediate >= int.min && this.immediate <= int.max :
                this.immediate >= int.min && this.immediate <= uint.max
            );
        }
        else {
            return true;
        }
    }
    
    /// Returns true if the immediate is of the given size,
    /// or if it has a size of "None" and a value within the appropriate range.
    bool isImmediateSize(in uint size, in bool signExtended) {
        return this.isInferredSize(Type.Immediate, size, signExtended);
    }
    
    bool isRelativeSize(in uint size, in bool signExtended) {
        return this.isInferredSize(Type.Relative, size, signExtended);
    }
}

enum X86InstructionStatus: ubyte {
    /// Instruction is fine and valid
    Ok = 0,
    /// Instruction is not valid and can't be encoded
    Invalid,
    /// Instruction doesn't have appropriate operands
    OperandError,
    /// Instruction isn't valid in the given mode (long/legacy)
    ModeError,
}

static enum IsX86InstructionOperandType(T) = (
    is(T == X86InstructionOperand) ||
    is(T == X86Register) || is(T == X86SegmentRegister)
);

enum X86InstructionRMOperandType: ubyte {
    None = 0,
    Register,
    MemoryAddress,
    FarSegmentImmediate,
}

struct X86Instruction {
    extern(C): // Make sure this works with --betterC
    
    alias AllOpcodes = X86AllOpcodes;
    alias DataSize = X86DataSize;
    alias DisplacementSize = X86DisplacementSize;
    alias ImmediateSize = X86ImmediateSize;
    alias MemoryAddressData = X86InstructionMemoryAddressData;
    alias MemoryOffsetData = X86InstructionMemoryOffsetData;
    alias Mode = X86Mode;
    alias Operand = X86InstructionOperand;
    alias Opcode = X86Opcode;
    alias Register = X86Register;
    alias RMOperandType = X86InstructionRMOperandType;
    alias SegmentRegister = X86SegmentRegister;
    alias Status = X86InstructionStatus;
    
    static enum typeof(this) Invalid = typeof(this)(Status.Invalid);
    static enum typeof(this) OperandError = typeof(this)(Status.OperandError);
    static enum typeof(this) ModeError = typeof(this)(Status.ModeError);
    
    /// Pointer to the opcode item associated with this instruction
    const(Opcode)* opcode = null;
    /// Immediate value operand, when one is present
    long immediate;
    
    /// Value of the r/m operand, if present (register or memory address)
    union {
        Register rmRegister;
        MemoryAddressData rmMemoryAddress;
        ushort farSegmentImmediate;
    }
    
    align(1):
    /// Whether the r/m operand is a register or a memory address,
    /// assuming the instruction has an r/m operand
    RMOperandType rmOperandType = RMOperandType.None;
    ///
    union {
        /// 
        Register register;
        ///
        SegmentRegister segmentRegister;
    }
    ///
    Status status;
    
    pure nothrow @safe @nogc:
    
    this(in Status status) {
        this.status = status;
    }
    
    this(in Mode mode, in string name, Operand[] operands) {
        assert(operands.length <= 4, "Too many operands.");
        foreach(i, _; X86AllOpcodes) {
            if(name == X86AllOpcodes[i].name &&
                X86AllOpcodes[i].validInMode(mode) &&
                X86OperandArrayMatch(&X86AllOpcodes[i], operands)
            ) {
                this.opcode = &X86AllOpcodes[i];
                assert(operands.length == this.opcode.countOperands);
                for(uint j = 0; j < operands.length; j++) {
                    this.setOperand(mode, this.opcode.operands[j], operands[j]);
                }
                return;
            }
        }
        this.status = Status.Invalid;
    }
    
    @trusted this(T...)(in Opcode* opcode, in T operands) if(
        T.length == 0 || !is(T[0]: Operand[])
    ) {
        assert(operands.length == opcode.countOperands, "Wrong number of operands.");
        this.opcode = opcode;
        static foreach(i, _; operands) {
            static assert(IsX86InstructionOperandType!(T[i]), "Wrong argument type.");
            static if(is(T[i] == Operand)) {
                this.setOperand(mode, opcode.operands[i], operands[i]);
            }
            else {
                this.setOperand(mode, opcode.operands[i], Operand(operands[i]));
            }
        }
    }
    
    @trusted this(size_t N)(in Opcode* opcode, in Operand[N] operands) {
        assert(operands.length == opcode.countOperands, "Wrong number of operands.");
        this.opcode = opcode;
        static foreach(i, _; operands) {
            static assert(IsX86InstructionOperandType!(T[i]), "Wrong argument type.");
            static if(is(T[i] == Operand)) {
                this.setOperand(mode, opcode.operands[i], operands[i]);
            }
            else {
                this.setOperand(mode, opcode.operands[i], Operand(operands[i]));
            }
        }
    }
    
    static auto OpcodeTemplate(string name, T...)(in Mode mode, in T operands) {
        // Check preconditions
        static assert(operands.length <= 4, "Too many operands.");
        static foreach(i, _; operands) {
            static assert(IsX86InstructionOperandType!(T[i]), "Wrong argument type.");
        }
        // Find a matching opcode and return an instruction instance
        static enum Opcodes = X86FilterAllOpcodes(name, operands.length);
        static foreach(opcodeIndex; Opcodes) {
            if(X86AllOpcodes[opcodeIndex].validInMode(mode) &&
                X86OperandListMatch(&X86AllOpcodes[opcodeIndex], operands)
            ) {
                return typeof(this)(&X86AllOpcodes[opcodeIndex], operands);
            }
        }
        // No match; return an error status
        return typeof(this).OperandError;
    }
    
    void setOperand(
        in Mode mode, in Opcode.OperandType operandType, in Operand operand
    ) {
        alias OperandType = Opcode.OperandType;        
        /// Implicit operands do not need to be specifically recorded or encoded
        if(X86OpcodeOperandTypeIsImplicit(operandType)) {
            return;
        }
        /// Segment register (sreg) operands
        else if(operandType is OperandType.sreg) {
            assert(this.segmentRegister == 0, "Duplicate segment register operand.");
            this.segmentRegister = operand.segmentRegister;
        }
        // Register r8/r16/r32/r64 operands
        else if(X86OpcodeOperandTypeIsReg(operandType)) {
            assert(this.register == 0, "Duplicate register operand.");
            if(mode !is Mode.Long && X86RegisterLongModeOnly(operand.register)) {
                this.status = Status.ModeError;
            }
            this.register = operand.register;
        }
        /// Immediate value operands imm8/imm16/imm32/imm64
        /// Also accounts for rel8/rel16/rel32/rel64
        else if(X86OpcodeOperandTypeIsImmediate(operandType)) {
            assert(this.immediate == 0, "Duplicate immediate operand.");
            this.immediate = operand.immediate;
        }
        /// Memory offset operands moffs8/moffs16/moffs32/moffs64
        else if(X86OpcodeOperandTypeIsMemoryOffset(operandType)) {
            assert(this.immediate == 0, "Duplicate memory offset operand.");
            assert(this.segmentRegister == 0, "Duplicate memory offset operand.");
            this.segmentRegister = operand.memoryOffset.segmentRegister;
            this.immediate = operand.memoryOffset.offset;
        }
        /// Far pointer 16-bit segment immediate operand
        else if(operandType is OperandType.farseg16) {
            assert(this.rmOperandType == 0,
                "Duplicate far pointer segment immediate operand."
            );
            this.farSegmentImmediate = cast(ushort) operand.immediate;
            this.rmOperandType = RMOperandType.FarSegmentImmediate;
        }
        /// ModR/M "r/m" operands; can represent a register or a memory address
        else if(X86OpcodeOperandTypeIsRM(operandType)) {
            assert(this.rmOperandType == 0, "Duplicate r/m operand.");
            if(operand.type is Operand.Type.MemoryAddress) {
                this.rmMemoryAddress = operand.memoryAddress;
                this.rmOperandType = RMOperandType.MemoryAddress;
                if(mode !is Mode.Long && ((
                    operand.memoryAddress.mode is MemoryAddressData.Mode.rip_disp32
                ) || (
                    operand.memoryAddress.hasBase &&
                    X86RegisterLongModeOnly(operand.memoryAddress.base)
                ) || (
                    operand.memoryAddress.hasIndex &&
                    X86RegisterLongModeOnly(operand.memoryAddress.index)
                ) )) {
                    this.status = Status.ModeError;
                }
                else if(mode is Mode.Long && (
                    operand.memoryAddress.mode is MemoryAddressData.Mode.disp32
                )) {
                    this.status = Status.ModeError;
                }
            }
            else {
                this.rmRegister = operand.register;
                this.rmOperandType = RMOperandType.Register;
                if(mode !is Mode.Long &&
                    X86RegisterLongModeOnly(operand.register)
                ) {
                    this.status = Status.ModeError;
                }
            }
        }
    }
    
    @trusted bool ok() const {
        return (
            this.opcode !is null &&
            this.status is Status.Ok &&
            (!this.hasMemoryAddress || this.rmMemoryAddress.ok)
        );
    }
    
    bool hasSegmentOverride() const {
        if(this.opcode is null) {
            return false;
        }
        foreach(operand; this.opcode.operands) {
            if(X86OpcodeOperandTypeIsMemoryOffset(operand)) {
                return true;
            }
        }
        return false;
    }
    
    /// Returns true if the instruction has a memory address operand.
    bool hasMemoryAddress() const {
        return this.rmOperandType is RMOperandType.MemoryAddress;
    }
    
    bool hasRMRegister() const {
        return this.rmOperandType is RMOperandType.Register;
    }
    
    bool hasExtendedRegister() const {
        return X86RegisterIsExtended(this.register);
    }
    
    bool hasRegRegister() const {
        if(this.opcode is null) {
            return false;
        }
        foreach(operand; this.opcode.operands) {
            if(X86OpcodeOperandTypeIsReg(operand)) {
                return true;
            }
        }
        return false;
    }
    
    bool hasSegmentRegister() const {
        if(this.opcode is null) {
            return false;
        }
        foreach(operand; this.opcode.operands) {
            if(operand is Opcode.OperandType.sreg) {
                return true;
            }
        }
        return false;
    }
    
    bool hasExtendedRMRegister() const {
        return (
            this.rmOperandType is RMOperandType.Register &&
            X86RegisterIsExtended(this.rmRegister)
        );
    }
    
    X86DataSize getOperandSize() const {
        if(this.opcode is null) {
            return X86DataSize.None;
        }
        foreach(operand; this.opcode.operands) {
            if(X86OpcodeOperandTypeIsReg(operand)) {
                return X86OpcodeOperandTypeSize(operand);
            }
            else if(X86OpcodeOperandTypeIsRM(operand) &&
                this.rmOperandType is RMOperandType.Register
            ) {
                return X86OpcodeOperandTypeSize(operand);
            }
        }
        return X86DataSize.None;
    }
    
    X86DataSize getMemoryAddressSize() const {
        assert(this.hasMemoryAddress);
        return this.getRMSize();
    }
    
    /// Get the size of this instruction's r8/r16/r32/r64 operand,
    /// if it has one.
    X86DataSize getRegSize() const {
        if(this.opcode is null) {
            return X86DataSize.None;
        }
        foreach(operand; this.opcode.operands) {
            if(X86OpcodeOperandTypeIsReg(operand)) {
                return X86OpcodeOperandTypeSize(operand);
            }
        }
        return X86DataSize.None;
    }
    
    /// Get the size of this instruction's r/m operand,
    /// if it has one.
    X86DataSize getRMSize() const {
        if(this.opcode is null) {
            return X86DataSize.None;
        }
        foreach(operand; this.opcode.operands) {
            if(X86OpcodeOperandTypeIsRM(operand)) {
                return X86OpcodeOperandTypeSize(operand);
            }
        }
        return X86DataSize.None;
    }
    
    DisplacementSize getDisplacementSize() const {
        if(this.opcode is null ||
            this.rmOperandType !is RMOperandType.MemoryAddress
        ) {
            return DisplacementSize.None;
        }
        return this.rmMemoryAddress.getDisplacementSize;
    }
    
    ImmediateSize getImmediateSize() const {
        if(this.opcode is null) {
            return X86DataSize.None;
        }
        foreach(operand; this.opcode.operands) {
            if(X86OpcodeOperandTypeIsImmediate(operand)) {
                return X86OpcodeOperandTypeSize(operand);
            }
        }
        return X86DataSize.None;
    }
}
