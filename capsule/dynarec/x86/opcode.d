module capsule.dynarec.x86.opcode;

private:

import capsule.dynarec.x86.mode : X86Mode;
import capsule.dynarec.x86.size : X86DataSize;

public pure nothrow @safe @nogc extern(C):

alias X86OperandSize = X86DataSize;

// TODO: Is this going to get used or no?
enum X86OpcodeEncodingType: ubyte {
    /// No operands
    ZO,
    /// Operand 0: Add register ID to opcode
    OR,
    /// Operand 0: Add register ID to opcode, Operand 1: immediate
    OR_I,
    /// Operand 0: r/m
    RM,
    /// Operand 0: r, Operand 1: r/m
    R_RM,
    /// Operand 0: r/m, Operand 1: r
    RM_R,
    /// Operand 0: r/m, Operand 1: immediate
    RM_I,
    /// Operand 0: r, Operand 1: r/m, Operand 2: immediate
    R_RM_I,
}

// TODO: Is this going to get used or no?
enum X86OpcodeOperandTypePlacement: ubyte {
    /// Implicit operand (indicated by opcode or etc.)
    None = 0,
    /// Operand is written to the reg field of a ModR/M byte
    Reg,
    /// Operand is written to the r/m field of a ModR/M byte
    RM,
    /// Operand is written as a 16-bit immediate
    /// Not mutually exclusive with the Immediate placement
    FarSegmentImmediate,
    /// Operand is written as an immediate value
    Immediate,
}

/// Enumeration of recognized X86 operand types.    
enum X86OpcodeOperandType: ubyte {
    /// No operand
    None = 0,
    /// Implicit AL register operand
    al = 'a',
    /// Implicit AX register operand
    ax = 'b',
    /// Implicit EAX register operand
    eax = 'c',
    /// Implicit RAX register operand
    rax = 'd',
    /// Implicit CL register operand
    cl = 'e',
    /// Implicit CS segment register operand
    cs = 'f',
    /// Implicit SS segment register operand
    ss = 'g',
    /// Implicit DS segment register operand
    ds = 'h',
    /// Implicit ES segment register operand
    es = 'i',
    /// Implicit FS segment register operand
    fs = 'j',
    /// Implicit GS segment register operand
    gs = 'k',
    /// Implicit literal 1 value operand
    lit1 = 'l',
    /// Segment register (encoded as reg in ModR/M byte)
    sreg = 'm',
    /// 8-bit "r" register
    r8 = 'n',
    /// 16-bit "r" register
    r16 = 'o',
    /// 32-bit "r" register
    r32 = 'p',
    /// 64-bit "r" register
    r64 = 'q',
    /// 8-bit "r/m" register or memory address
    rm8 = 'r',
    /// 16-bit "r/m" register or memory address
    rm16 = 's',
    /// 32-bit "r/m" register or memory address
    rm32 = 't',
    /// 64-bit "r/m" register or memory address
    rm64 = 'u',
    /// 8-bit "r/m" register; not a memory address
    rm_r8 = 'v',
    /// 16-bit "r/m" register; not a memory address
    rm_r16 = 'w',
    /// 32-bit "r/m" register; not a memory address
    rm_r32 = 'x',
    /// 64-bit "r/m" register; not a memory address
    rm_r64 = 'y',
    /// 16-bit "r/m" register; must be a memory address pointing to m16:16
    m16_16 = 'z',
    /// 16-bit "r/m" register; must be a memory address pointing to m16:32
    m16_32 = 'A',
    /// 16-bit "r/m" register; must be a memory address pointing to m16:64
    m16_64 = 'B',
    /// 8-bit memory offset; has a segment register and an immediate offset
    moffs8 = 'C',
    /// 16-bit memory offset; has a segment register and an immediate offset
    moffs16 = 'D',
    /// 32-bit memory offset; has a segment register and an immediate offset
    moffs32 = 'E',
    /// 64-bit memory offset; has a segment register and an immediate offset
    moffs64 = 'F',
    /// 8-bit immediate
    imm8 = 'G',
    /// 16-bit immediate
    imm16 = 'H',
    /// 32-bit immediate
    imm32 = 'I',
    /// 64-bit immediate
    imm64 = 'J',
    /// 8-bit immediate relative offset
    rel8 = 'K',
    /// 16-bit immediate relative offset
    rel16 = 'L',
    /// 32-bit immediate relative offset
    rel32 = 'M',
    /// 64-bit immediate relative offset
    rel64 = 'N',
    /// The second portion of a far pointer, stored to EIP/RIP (16 bits)
    far16 = 'O',
    /// The second portion of a far pointer, stored to EIP/RIP (32 bits)
    far32 = 'P',
    /// The second portion of a far pointer, stored to EIP/RIP (64 bits)
    far64 = 'Q',
    /// The first, 16-bit portion of a far pointer (stored to CS register)
    farseg16 = 'R',
}

/// Get whether a given operand type corresponds to an implicit operand,
/// i.e. an operand that is not literally part of the instruction encoding
/// because it is implied by the opcode.
bool X86OpcodeOperandTypeIsImplicit(in X86OpcodeOperandType operandType) {
    alias OperandType = X86OpcodeOperandType;
    switch(operandType) {
        case OperandType.None: return true;
        case OperandType.al: return true;
        case OperandType.ax: return true;
        case OperandType.eax: return true;
        case OperandType.rax: return true;
        case OperandType.cl: return true;
        case OperandType.cs: return true;
        case OperandType.ss: return true;
        case OperandType.ds: return true;
        case OperandType.es: return true;
        case OperandType.fs: return true;
        case OperandType.gs: return true;
        case OperandType.lit1: return true;
        default: return false;
    }
}

///
bool X86OpcodeOperandTypeIsReg(in X86OpcodeOperandType operandType) {
    alias OperandType = X86OpcodeOperandType;
    switch(operandType) {
        case OperandType.r8: return true;
        case OperandType.r16: return true;
        case OperandType.r32: return true;
        case OperandType.r64: return true;
        default: return false;
    }
}

///
bool X86OpcodeOperandTypeIsRM(in X86OpcodeOperandType operandType) {
    alias OperandType = X86OpcodeOperandType;
    switch(operandType) {
        case OperandType.rm8: return true;
        case OperandType.rm16: return true;
        case OperandType.rm32: return true;
        case OperandType.rm64: return true;
        case OperandType.rm_r8: return true;
        case OperandType.rm_r16: return true;
        case OperandType.rm_r32: return true;
        case OperandType.rm_r64: return true;
        case OperandType.m16_16: return true;
        case OperandType.m16_32: return true;
        case OperandType.m16_64: return true;
        default: return false;
    }
}

bool X86OpcodeOperandTypeIsImmediate(in X86OpcodeOperandType operandType) {
    alias OperandType = X86OpcodeOperandType;
    switch(operandType) {
        case OperandType.imm8: return true;
        case OperandType.imm16: return true;
        case OperandType.imm32: return true;
        case OperandType.imm64: return true;
        case OperandType.rel8: return true;
        case OperandType.rel16: return true;
        case OperandType.rel32: return true;
        case OperandType.rel64: return true;
        case OperandType.far16: return true;
        case OperandType.far32: return true;
        case OperandType.far64: return true;
        default: return false;
    }
}

bool X86OpcodeOperandTypeIsMemoryOffset(in X86OpcodeOperandType operandType) {
    alias OperandType = X86OpcodeOperandType;
    switch(operandType) {
        case OperandType.moffs8: return true;
        case OperandType.moffs16: return true;
        case OperandType.moffs32: return true;
        case OperandType.moffs64: return true;
        default: return false;
    }
}

X86DataSize X86OpcodeOperandTypeSize(in X86OpcodeOperandType operandType) {
    alias OperandType = X86OpcodeOperandType;
    alias Size = X86DataSize;
    final switch(operandType) {
        case OperandType.None: return Size.None;
        case OperandType.al: return Size.Byte;
        case OperandType.ax: return Size.Word;
        case OperandType.eax: return Size.DWord;
        case OperandType.rax: return Size.QWord;
        case OperandType.cl: return Size.Word;
        case OperandType.cs: return Size.Word;
        case OperandType.ss: return Size.Word;
        case OperandType.ds: return Size.Word;
        case OperandType.es: return Size.Word;
        case OperandType.fs: return Size.Word;
        case OperandType.gs: return Size.Word;
        case OperandType.lit1: return Size.Byte;
        case OperandType.sreg: return Size.Word;
        case OperandType.r8: return Size.Byte;
        case OperandType.r16: return Size.Word;
        case OperandType.r32: return Size.DWord;
        case OperandType.r64: return Size.QWord;
        case OperandType.rm8: return Size.Byte;
        case OperandType.rm16: return Size.Word;
        case OperandType.rm32: return Size.DWord;
        case OperandType.rm64: return Size.QWord;
        case OperandType.rm_r8: return Size.Byte;
        case OperandType.rm_r16: return Size.Word;
        case OperandType.rm_r32: return Size.DWord;
        case OperandType.rm_r64: return Size.QWord;
        case OperandType.m16_16: return Size.None; // ?
        case OperandType.m16_32: return Size.None; // ?
        case OperandType.m16_64: return Size.None; // ?
        case OperandType.moffs8: return Size.Byte;
        case OperandType.moffs16: return Size.Word;
        case OperandType.moffs32: return Size.DWord;
        case OperandType.moffs64: return Size.QWord;
        case OperandType.imm8: return Size.Byte;
        case OperandType.imm16: return Size.Word;
        case OperandType.imm32: return Size.DWord;
        case OperandType.imm64: return Size.QWord;
        case OperandType.rel8: return Size.Byte;
        case OperandType.rel16: return Size.Word;
        case OperandType.rel32: return Size.DWord;
        case OperandType.rel64: return Size.QWord;
        case OperandType.far16: return Size.Word;
        case OperandType.far32: return Size.DWord;
        case OperandType.far64: return Size.QWord;
        case OperandType.farseg16: return Size.Word;
    }
}

enum ushort X86OpcodeEscapeA = 0x0f;
enum ushort X86OpcodeEscapeB = 0x0f38;
enum ushort X86OpcodeEscapeC = 0x0f3a;

shared immutable ushort[4] X86OpcodeEscapeList = [
    0x0000, X86OpcodeEscapeA, X86OpcodeEscapeB, X86OpcodeEscapeC
];

/// TODO: Give these more descriptive names
enum X86OpcodeEscape: ubyte {
    /// No opcode escape bytes
    None = 0,
    /// 0x0f
    A,
    /// 0x0f 0x38
    B,
    /// 0x0f 0x3a
    C,
}

enum X86OpcodeLockPrefix: ubyte {
    /// No lock prefix byte
    None = 0,
    /// 0xf0
    Lock,
    /// 0xf3
    RepeatZ,
    /// 0xf2
    RepeatNZ,
}

/*X86OpcodeOperandTypePlacement X86OpcodeOperandTypePlacement(
    in X86OpcodeOperandType operandType
) {
    alias OperandType = X86OpcodeOperandType;
    alias Placement = X86OpcodeOperandTypePlacement;
    final switch(operandType) {
        case OperandType.None: return Placement.None;
        case OperandType.al: return Placement.None;
        case OperandType.ax: return Placement.None;
        case OperandType.eax: return Placement.None;
        case OperandType.rax: return Placement.None;
        case OperandType.cl: return Placement.None;
        case OperandType.cs: return Placement.None;
        case OperandType.ss: return Placement.None;
        case OperandType.ds: return Placement.None;
        case OperandType.es: return Placement.None;
        case OperandType.fs: return Placement.None;
        case OperandType.gs: return Placement.None;
        case OperandType.lit1: return Placement.None;
        case OperandType.sreg: return Placement.Reg;
        case OperandType.r8: return Placement.Reg;
        case OperandType.r16: return Placement.Reg;
        case OperandType.r32: return Placement.Reg;
        case OperandType.r64: return Placement.Reg;
        case OperandType.rm8: return Placement.RM;
        case OperandType.rm16: return Placement.RM;
        case OperandType.rm32: return Placement.RM;
        case OperandType.rm64: return Placement.RM;
        case OperandType.rm_r8: return Placement.RM;
        case OperandType.rm_r16: return Placement.RM;
        case OperandType.rm_r32: return Placement.RM;
        case OperandType.rm_r64: return Placement.RM;
        case OperandType.m16_16: return Placement.RM;
        case OperandType.m16_32: return Placement.RM;
        case OperandType.m16_64: return Placement.RM;
        case OperandType.imm8: return Placement.Immediate;
        case OperandType.imm16: return Placement.Immediate;
        case OperandType.imm32: return Placement.Immediate;
        case OperandType.imm64: return Placement.Immediate;
        case OperandType.rel8: return Placement.Immediate;
        case OperandType.rel16: return Placement.Immediate;
        case OperandType.rel32: return Placement.Immediate;
        case OperandType.rel64: return Placement.Immediate;
        case OperandType.far16: return Placement.Immediate;
        case OperandType.far32: return Placement.Immediate;
        case OperandType.far64: return Placement.Immediate;
        case OperandType.farseg16: return Placement.FarSegmentImmediate;
    }
}*/

enum X86OpcodeFlag: ushort {
    /// 0, 0: No opcode escape byte
    /// 0, 1: Opcode escape 0x0f
    /// 1, 0: Opcode escape 0x0f 0x38
    /// 1, 1: Opcode escape 0x0f 0x3a
    EscapeL = 0x0001,
    EscapeH = 0x0002,
    /// 0, 0: No mandatory lock prefix byte
    /// 0, 1: Mandatory lock prefix byte 0xf0 (LOCK)
    /// 1, 0: Mandatory lock prefix byte 0xf2 (REPZ)
    /// 1, 1: Mandatory lock prefix byte 0xf3 (REPNZ)
    LockPrefixL = 0x0004,
    LockPrefixH = 0x0008,
    /// Can be used in legacy/compatibility mode
    Legacy = 0x0010,
    /// Can be used in long mode
    Long = 0x0020,
    /// Documentation discourages the use of this instruction
    Discouraged = 0x0040,
    /// Add r8/r16/r32/r64 ID value to the opcode
    AddRegToOpcode = 0x0080,
    /// The 3 bits, from lowest to highest, making up the opcode bits
    /// in an instruction's ModR/M byte, if it needs them
    ModOpcode0 = 0x0100,
    ModOpcode1 = 0x0200,
    ModOpcode2 = 0x0400,
    /// The "reg" field of the ModR/M byte encodes extra opcode bits
    HasModOpcode = 0x0800,
    /// The "mod" field of the ModR/M byte (two highest bits) must be 0x3
    HasModR = 0x1000,
    /// Must have a REX byte with the REX.W flag set
    HasRexW = 0x2000,
    /// Set for instructions that use a sign-extended immediate value
    SignExtendImmediate = 0x4000,
}

struct X86Opcode {
    extern(C): // Make sure this works with --betterC
    
    alias EncodingType = X86OpcodeEncodingType;
    alias Escape = X86OpcodeEscape;
    alias Flag = X86OpcodeFlag;
    alias Flags = ushort;
    alias OperandType = X86OpcodeOperandType;
    //alias OperandTypePlacement = X86OpcodeOperandTypePlacement;
    alias OperandSize = X86OperandSize;
    alias LockPrefix = X86OpcodeLockPrefix;
    
    /// A name or mnemonic for this opcode.
    string name;
    
    align(4):
    /// The list of operand types accepted by this instruction.
    /// Padded with OperandType.None values.
    OperandType[4] operands;
    
    align(2):
    /// Packed flags and other fields relating to this opcode.
    Flags flags;
    
    align(1):
    /// Value of opcode byte.
    ubyte opcode = 0;
    /// Some opcodes should have an operand size prefix to distinguish
    /// e.g. a 16-bit operation from a 32-bit operation, but they don't
    /// actually have any explicit operands. Use this field to provide
    /// an implicit operand size regardless of actual operand sizes.
    OperandSize implicitOperandSize = OperandSize.None;
    
    pure nothrow @safe @nogc:
    
    this(size_t N)(
        in uint opcode, 
        in string name, in OperandType[N] operands
    ) {
        this.opcode = cast(ubyte) opcode;
        if(opcode >> 8 == X86OpcodeEscapeA) {
            this.setOpcodeEscape(Escape.A);
        }
        else if(opcode >> 8 == X86OpcodeEscapeB) {
            this.setOpcodeEscape(Escape.B);
        }
        else if(opcode >> 8 == X86OpcodeEscapeC) {
            this.setOpcodeEscape(Escape.C);
        }
        else if(opcode >> 8) {
            assert(false, "Invalid opcode escape.");
        }
        this.name = name;
        this.operands[0 .. N] = operands;
        this.setFlag(Flag.Legacy);
        this.setFlag(Flag.Long);
    }
    
    bool opCast(T: bool)() const {
        return this.name.length != 0;
    }
    
    uint countOperands() const {
        uint count = 0;
        foreach(operand; this.operands) {
            count += (operand !is OperandType.None);
        }
        return count;
    }
    
    uint countExplicitOperands() const {
        uint count = 0;
        foreach(operand; this.operands) {
            count += X86OpcodeOperandTypeIsImplicit(operand) ? 0 : 1;
        }
        return count;
    }
    
    /// Get a value indicating what escape bytes should precede the
    /// opcode byte, if any.
    Escape getOpcodeEscape() const {
        static assert(Flag.EscapeL == 0x1);
        static assert(Flag.EscapeH == 0x2);
        const escapeBits = this.flags & 0x3;
        return cast(Escape) escapeBits;
    }
    
    void setOpcodeEscape(in Escape escape) {
        assert(escape <= 0x3);
        this.flags = cast(Flags) ((this.flags & ~0x3) | escape);
    }
    
    /// Get a value indicating what lock prefix byte should precede the
    /// instruction, if any.
    LockPrefix getLockPrefix() const {
        static assert(Flag.LockPrefixL == 0x4);
        static assert(Flag.LockPrefixH == 0x8);
        const lockPrefixBits = (this.flags >> 2) & 0x3;
        return cast(LockPrefix) lockPrefixBits;
    }
    
    /// Set this field to indicate a mandatory lock prefix byte.
    void setLockPrefix(in LockPrefix lockPrefix) {
        assert(lockPrefix <= 0x3);
        this.flags = cast(Flags) ((this.flags & ~0xc) | (lockPrefix << 2));
    }
    
    ubyte getModOpcode() const {
        assert(this.hasModOpcode);
        static assert(Flag.ModOpcode0 == 0x0100);
        static assert(Flag.ModOpcode1 == 0x0200);
        static assert(Flag.ModOpcode2 == 0x0400);
        return cast(ubyte) ((this.flags >> 8) & 0x7);
    }
    
    void setModOpcode(in ubyte opcode) {
        assert(opcode <= 0x7);
        this.flags = cast(Flags) ((this.flags & ~0x700) | (opcode << 8));
    }
    
    bool hasModRMByte() const {
        return (this.hasModR || this.hasModOpcode);
    }
    
    bool getFlag(in Flag flag) const {
        return (this.flags & flag) != 0;
    }
    
    void setFlag(in Flag flag) {
        this.flags = cast(Flags) (this.flags | flag);
    }
    
    void setFlag(in Flag flag, in bool value) {
        this.flags = cast(Flags) (
            value ? this.flags | flag : this.flags & ~cast(uint) flag
        );
    }
    
    template getFlagTemplate(Flag flag) {
        bool getFlagTemplate() const {
            return this.getFlag(flag);
        }
    }
    
    alias validInLegacyMode = getFlagTemplate!(Flag.Legacy);
    alias validInLongMode = getFlagTemplate!(Flag.Long);
    alias isDiscouraged = getFlagTemplate!(Flag.Discouraged);
    alias addRegToOpcode = getFlagTemplate!(Flag.AddRegToOpcode);
    alias hasModOpcode = getFlagTemplate!(Flag.HasModOpcode);
    alias hasModR = getFlagTemplate!(Flag.HasModR);
    alias hasRexW = getFlagTemplate!(Flag.HasRexW);
    alias hasSignExtendedImmediate = getFlagTemplate!(Flag.SignExtendImmediate);
    
    bool validInMode(in X86Mode mode) pure const {
        final switch(mode) {
            case X86Mode.None: return false;
            case X86Mode.Legacy: return this.validInLegacyMode;
            case X86Mode.Long: return this.validInLongMode;
        }
    }
    
    /// Indicate that the instruction encodes part of its opcode bits
    /// in the "reg" field of its ModR/M byte.
    /// This is normally denoted as "/0", "/1", ... "/7" in documentation.
    typeof(this) ROpcode(in ubyte modrmOpcode) const {
        assert(modrmOpcode <= 0x7);
        X86Opcode opcode = this;
        opcode.setFlag(Flag.HasModOpcode);
        opcode.setModOpcode(modrmOpcode);
        return opcode;
    }
    
    /// Indicate that the "mod" field of the instruction's ModR/M byte
    /// should have both bits set.
    /// Instructions with this encoding characteristic are normally denoted
    /// with "/r" in documentation.
    typeof(this) RMod() const {
        X86Opcode opcode = this;
        opcode.setFlag(Flag.HasModR);
        return opcode;
    }
    
    /// Indicate that the instruction's r8/r16/r32/r64 operand is encoded
    /// by adding its ID to the opcode byte.
    typeof(this) AddRToOpcode() const {
        X86Opcode opcode = this;
        opcode.setFlag(Flag.AddRegToOpcode);
        return opcode;
    }
    
    /// Indicate an explicit operand size, for instuctions that may need
    /// an operand size override prefix depending on the mode, but that
    /// do not have any actual explicit operands.
    typeof(this) OpSize(in int size) const {
        assert(size == 8 || size == 16 || size == 32 || size == 64);
        return typeof(this).OpSize(cast(OperandSize) size);
    }
    
    /// Ditto
    typeof(this) OpSize(in OperandSize operandSize) const {
        X86Opcode opcode = this;
        opcode.implicitOperandSize = operandSize;
        return opcode;
    }
    
    /// Indicate that this instruction must be encoded with a lock
    /// prefix byte, and which such prefix byte.
    typeof(this) Lock(in LockPrefix lockPrefix) const {
        X86Opcode opcode = this;
        opcode.setLockPrefix(lockPrefix);
        return opcode;
    }
    
    /// Indicate that the instruction must be encoded with a REPZ
    /// lock prefix byte (0xf2).
    typeof(this) RepZ() const {
        return this.Lock(LockPrefix.RepeatZ);
    }
    
    /// Indicate that the instruction must be encoded with a REPNZ
    /// lock prefix byte (0xf3).
    typeof(this) RepNZ() const {
        return this.Lock(LockPrefix.RepeatNZ);
    }
    
    /// Indicate that this instruction must be encoded with a REX prefix
    /// byte, with the REX.W flag set.
    /// Also marks the instruction as unavailable in legacy/compatibility
    /// mode, since REX prefix bytes are only available in long mode.
    typeof(this) RexW() const {
        X86Opcode opcode = this;
        opcode.setFlag(Flag.HasRexW);
        opcode.setFlag(Flag.Legacy, false);
        return opcode;
    }
    
    /// Set for instructions which have an immediate operand that must
    /// be sign-extended, e.g. to the size of a register operand.
    typeof(this) SExtImm() const {
        X86Opcode opcode = this;
        opcode.setFlag(Flag.SignExtendImmediate);
        return opcode;
    }
    
    /// Indicate if this instruction is available in long mode only,
    /// mode only, not in legacy/compatibility mode.
    typeof(this) LongOnly() const {
        X86Opcode opcode = this;
        opcode.setFlag(Flag.Long);
        opcode.setFlag(Flag.Legacy, false);
        return opcode;
    }
    
    /// Indicate if this instruction is available in legacy/compatibility
    /// mode only, not in long mode.
    typeof(this) LegacyOnly() const {
        X86Opcode opcode = this;
        opcode.setFlag(Flag.Legacy);
        opcode.setFlag(Flag.Long, false);
        return opcode;
    }
    
    /// Indicate if this instruction cannot actually be encoded,
    /// in any mode.
    typeof(this) NotEncodable() const {
        X86Opcode opcode = this;
        opcode.setFlag(Flag.Legacy, false);
        opcode.setFlag(Flag.Long, false);
        return opcode;
    }
    
    /// Indicate if documentation discourages the use of this opcode
    typeof(this) Discouraged() const {
        X86Opcode opcode = this;
        opcode.setFlag(Flag.Discouraged);
        return opcode;
    }
}
