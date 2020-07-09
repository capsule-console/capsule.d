/**

This module defines types and constants related to Capsule bytecode
instruction opcodes.

*/

module capsule.core.opcode;

public:

enum CapsuleOpcodeFlag: uint {
    /// Flag set for instruction opcodes where the destination register
    /// may be modified.
    SetsRegister = 0x1,
    /// Flag set for instruction opcodes where the first source register
    /// may be accessed.
    ReadsFirstRegister = 0x2,
    /// Flag set for instruction opcodes where the second source register
    /// may be accessed.
    ReadsSecondRegister = 0x4,
    /// Flag set for instruction opcodes where the immediate value
    /// may be accessed.
    ReadsImmediate = 0x8,
    /// Flag set for instruction opcodes where the program counter may
    /// be accessed. Notably, the jalr instruction does not have this flag
    /// set, since even though it assigns a new value to the PC, it doesn't
    /// care about the old PC value, unlike jal or branches which must read
    /// the PC in order to add an offset to it.
    ReadsPC = 0x10,
    /// Flag set for instruction opcodes that have any form of output
    /// or that effect any kind of state change other than just setting the
    /// value of the destination register.
    HasSideEffect = 0x20,
    /// Flag set for instruction opcodes that may read a value from memory.
    IsLoad = 0x40,
    /// Flag set for instruction opcodes that may change a value in memory.
    IsStore = 0x80,
    /// Flag set for instruction opcodes that unconditionally assign a new
    /// value to the PC.
    IsJump = 0x100,
    /// Flag set for instruction opcodes that conditionally assign a new
    /// value to the PC.
    IsBranch = 0x200,
    /// Combines the flags indicating that an instruction opcode may access the
    /// first source register, and that it may access the second source register.
    ReadsBothRegisters = (
        CapsuleOpcodeFlag.ReadsFirstRegister |
        CapsuleOpcodeFlag.ReadsSecondRegister
    ),
    /// Combines the flags indicating that an instruction opcode may access the
    /// first source register, that it may access the second source register,
    /// and that it may change the value in the destination register.
    UsesAllRegisters = (
        CapsuleOpcodeFlag.SetsRegister |
        CapsuleOpcodeFlag.ReadsFirstRegister |
        CapsuleOpcodeFlag.ReadsSecondRegister
    ),
    /// Mask that can be used to determine whether either of an instruction
    /// opcode's memory access flags are set, i.e. the load or store flag.
    IsMemoryAccess = (
        CapsuleOpcodeFlag.IsLoad |
        CapsuleOpcodeFlag.IsStore
    ),
    /// Mask that can be used to determine whether either of an instruction
    /// opcode's control flow flags are set, i.e. the jump or branch flag.
    IsControlFlow = (
        CapsuleOpcodeFlag.IsJump |
        CapsuleOpcodeFlag.IsBranch
    ),
}

/// Table is initialized to associate an opcode index with a name string,
/// e.g. "add" or "and" or "auipc".
shared immutable string[128] CapsuleOpcodeNames;

/// Table is initialized to associate an opcode index with flags describing
/// each opcode's behavior.
shared immutable uint[128] CapsuleOpcodeFlags;

/// Initialize opcode name and flags tables.
shared static this() nothrow @safe @nogc {
    CapsuleOpcodeNames = initializeCapsuleOpcodeNames();
    CapsuleOpcodeFlags = initializeCapsuleOpcodeFlags();
}

/// Initialize the opcode names table.
string[128] initializeCapsuleOpcodeNames() pure nothrow @safe @nogc {
    // Initialize name table based on UDAs
    string[128] names;
    foreach(member; __traits(allMembers, CapsuleOpcode)) {
        const opcode = __traits(getMember, CapsuleOpcode, member);
        enum Attributes = __traits(
            getAttributes, __traits(getMember, CapsuleOpcode, member)
        );
        static assert(Attributes.length && is(typeof(Attributes[0]) == string));
        names[cast(size_t) opcode] = Attributes[0];
    }
    return names;
}

/// Initialize the opcode flags table.
uint[128] initializeCapsuleOpcodeFlags() pure nothrow @safe @nogc {
    alias Flag = CapsuleOpcodeFlag;
    alias Opcode = CapsuleOpcode;
    // Flags used by ebreak and by invalid instructions
    enum uint NoFlags = 0;
    // Flags common to the lui and auipc instructions
    enum uint IsUnaryWithImmediate = (
        Flag.SetsRegister |
        Flag.ReadsImmediate
    );
    // Flags common to several instructions (revb, revh, ctz, clz, pcnt)
    enum uint IsUnaryWithRegister = (
        Flag.SetsRegister |
        Flag.ReadsFirstRegister
    );
    // Flags common to several instructions (andi, ori, xori, slti, sltiu)
    enum uint IsBinaryWithImmediate = (
        Flag.SetsRegister |
        Flag.ReadsFirstRegister |
        Flag.ReadsImmediate
    );
    // Flags common to several instructions (sll, srl, sra, add)
    enum uint IsTernary = (
        Flag.SetsRegister |
        Flag.ReadsBothRegisters |
        Flag.ReadsImmediate
    );
    // Flags common to load instructions (lb, lbu, lh, lhu, lw)
    enum uint LoadFlags = (
        Flag.IsLoad |
        Flag.SetsRegister |
        Flag.ReadsFirstRegister |
        Flag.ReadsImmediate
    );
    // Flags common to store instructions (sb, sh, sw)
    enum uint StoreFlags = (
        Flag.IsStore |
        Flag.HasSideEffect |
        Flag.ReadsBothRegisters |
        Flag.ReadsImmediate
    );
    // Flags common to branch instructions (beq, bne, blt, bltu, bge, bgeu)
    enum uint BranchFlags = (
        Flag.IsBranch |
        Flag.ReadsPC |
        Flag.HasSideEffect |
        Flag.ReadsBothRegisters |
        Flag.ReadsImmediate
    );
    // Flags for the jal instruction
    enum uint JumpAndLinkFlags = (
        Flag.IsJump |
        Flag.ReadsPC |
        Flag.HasSideEffect |
        Flag.SetsRegister |
        Flag.ReadsImmediate
    );
    // Flags for the jalr instruction
    enum uint JumpAndLinkRegisterFlags = (
        Flag.IsJump |
        Flag.HasSideEffect |
        Flag.SetsRegister |
        Flag.ReadsFirstRegister |
        Flag.ReadsImmediate
    );
    // Flags for the ecall instruction
    enum uint ExtensionCallFlags = (
        Flag.HasSideEffect |
        Flag.SetsRegister |
        Flag.ReadsBothRegisters |
        Flag.ReadsImmediate
    );
    // Assign flags corresponding to each opcode
    uint[128] flags;
    flags[Opcode.None] = NoFlags;
    flags[Opcode.And] = Flag.UsesAllRegisters;
    flags[Opcode.Or] = Flag.UsesAllRegisters;
    flags[Opcode.Xor] = Flag.UsesAllRegisters;
    flags[Opcode.Subtract] = Flag.UsesAllRegisters;
    flags[Opcode.SetMinimumSigned] = Flag.UsesAllRegisters;
    flags[Opcode.SetMinimumUnsigned] = Flag.UsesAllRegisters;
    flags[Opcode.SetMaximumSigned] = Flag.UsesAllRegisters;
    flags[Opcode.SetMaximumUnsigned] = Flag.UsesAllRegisters;
    flags[Opcode.SetLessThanSigned] = Flag.UsesAllRegisters;
    flags[Opcode.SetLessThanUnsigned] = Flag.UsesAllRegisters;
    flags[Opcode.MultiplyAndTruncate] = Flag.UsesAllRegisters;
    flags[Opcode.MultiplySignedAndShift] = Flag.UsesAllRegisters;
    flags[Opcode.MultiplyUnsignedAndShift] = Flag.UsesAllRegisters;
    flags[Opcode.MultiplySignedUnsignedAndShift] = Flag.UsesAllRegisters;
    flags[Opcode.DivideSigned] = Flag.UsesAllRegisters;
    flags[Opcode.DivideUnsigned] = Flag.UsesAllRegisters;
    flags[Opcode.RemainderSigned] = Flag.UsesAllRegisters;
    flags[Opcode.RemainderUnsigned] = Flag.UsesAllRegisters;
    flags[Opcode.ReverseByteOrder] = IsUnaryWithRegister;
    flags[Opcode.ReverseHalfWordOrder] = IsUnaryWithRegister;
    flags[Opcode.CountLeadingZeroes] = IsUnaryWithRegister;
    flags[Opcode.CountTrailingZeroes] = IsUnaryWithRegister;
    flags[Opcode.CountSetBits] = IsUnaryWithRegister;
    flags[Opcode.Breakpoint] = NoFlags;
    flags[Opcode.AndImmediate] = IsBinaryWithImmediate;
    flags[Opcode.OrImmediate] = IsBinaryWithImmediate;
    flags[Opcode.XorImmediate] = IsBinaryWithImmediate;
    flags[Opcode.ShiftLeftLogical] = IsTernary;
    flags[Opcode.ShiftRightLogical] = IsTernary;
    flags[Opcode.ShiftRightArithmetic] = IsTernary;
    flags[Opcode.Add] = IsTernary;
    flags[Opcode.SetLessThanImmediateSigned] = IsBinaryWithImmediate;
    flags[Opcode.SetLessThanImmediateUnsigned] = IsBinaryWithImmediate;
    flags[Opcode.LoadUpperImmediate] = IsUnaryWithImmediate;
    flags[Opcode.AddUpperImmediateToPC] = Flag.ReadsPC | IsUnaryWithImmediate;
    flags[Opcode.LoadByteSignExt] = LoadFlags;
    flags[Opcode.LoadByteZeroExt] = LoadFlags;
    flags[Opcode.LoadHalfWordSignExt] = LoadFlags;
    flags[Opcode.LoadHalfWordZeroExt] = LoadFlags;
    flags[Opcode.LoadWord] = LoadFlags;
    flags[Opcode.StoreByte] = StoreFlags;
    flags[Opcode.StoreHalfWord] = StoreFlags;
    flags[Opcode.StoreWord] = StoreFlags;
    flags[Opcode.JumpAndLink] = JumpAndLinkFlags;
    flags[Opcode.JumpAndLinkRegister] = JumpAndLinkRegisterFlags;
    flags[Opcode.BranchEqual] = BranchFlags;
    flags[Opcode.BranchNotEqual] = BranchFlags;
    flags[Opcode.BranchLessSigned] = BranchFlags;
    flags[Opcode.BranchLessUnsigned] = BranchFlags;
    flags[Opcode.BranchGreaterEqualSigned] = BranchFlags;
    flags[Opcode.BranchGreaterEqualUnsigned] = BranchFlags;
    flags[Opcode.ExtensionCall] = ExtensionCallFlags;
    // All done
    return flags;
}
 
/// Get the name string associated with a given opcode.
string getCapsuleOpcodeName(in ubyte opcode) pure nothrow @safe @nogc {
    if(opcode < CapsuleOpcodeNames.length) {
        return CapsuleOpcodeNames[opcode];
    }
    else {
        return null;
    }
}

/// Get the behavior flags associated with a given opcode.
uint getCapsuleOpcodeFlags(in ubyte opcode) pure nothrow @safe @nogc {
    if(opcode < CapsuleOpcodeFlags.length) {
        return CapsuleOpcodeFlags[opcode];
    }
    else {
        return 0;
    }
}

/// Get the opcode associated with a given name string.
CapsuleOpcode getCapsuleOpcodeWithName(in char[] name) pure nothrow @safe @nogc {
    for(uint i = 0; i < CapsuleOpcodeNames.length; i++) {
        if(name == CapsuleOpcodeNames[i]) {
            return cast(CapsuleOpcode) i;
        }
    }
    return CapsuleOpcode.None;
}

/// Enumeration of recognized Capsule instruction opcodes.
enum CapsuleOpcode: ubyte {
    @("none") None = 0x00,
    @("and") And = 0x04,
    @("or") Or = 0x05,
    @("xor") Xor = 0x06,
    @("sub") Subtract = 0x07,
    @("min") SetMinimumSigned = 0x08,
    @("minu") SetMinimumUnsigned = 0x09,
    @("max") SetMaximumSigned = 0x0a,
    @("maxu") SetMaximumUnsigned = 0x0b,
    @("slt") SetLessThanSigned = 0x0c,
    @("sltu") SetLessThanUnsigned = 0x0d,
    @("mul") MultiplyAndTruncate = 0x10,
    @("mulh") MultiplySignedAndShift = 0x11,
    @("mulhu") MultiplyUnsignedAndShift = 0x12,
    @("mulhsu") MultiplySignedUnsignedAndShift = 0x13,
    @("div") DivideSigned = 0x14,
    @("divu") DivideUnsigned = 0x15,
    @("rem") RemainderSigned = 0x16,
    @("remu") RemainderUnsigned = 0x17,
    @("revb") ReverseByteOrder = 0x18,
    @("revh") ReverseHalfWordOrder = 0x19,
    @("clz") CountLeadingZeroes = 0x1a,
    @("ctz") CountTrailingZeroes = 0x1b,
    @("pcnt") CountSetBits = 0x1c,
    @("ebreak") Breakpoint = 0x3f,
    @("andi") AndImmediate = 0x44,
    @("ori") OrImmediate = 0x45,
    @("xori") XorImmediate = 0x46,
    @("sll") ShiftLeftLogical = 0x48,
    @("srl") ShiftRightLogical = 0x49,
    @("sra") ShiftRightArithmetic = 0x4a,
    @("add") Add = 0x4b,
    @("slti") SetLessThanImmediateSigned = 0x4c,
    @("sltiu") SetLessThanImmediateUnsigned = 0x4d,
    @("lui") LoadUpperImmediate = 0x4e,
    @("auipc") AddUpperImmediateToPC = 0x4f,
    @("lb") LoadByteSignExt = 0x50,
    @("lbu") LoadByteZeroExt = 0x51,
    @("lh") LoadHalfWordSignExt = 0x52,
    @("lhu") LoadHalfWordZeroExt = 0x53,
    @("lw") LoadWord = 0x54,
    @("sb") StoreByte = 0x55,
    @("sh") StoreHalfWord = 0x56,
    @("sw") StoreWord = 0x57,
    @("jal") JumpAndLink = 0x58,
    @("jalr") JumpAndLinkRegister = 0x59,
    @("beq") BranchEqual = 0x5a,
    @("bne") BranchNotEqual = 0x5b,
    @("blt") BranchLessSigned = 0x5c,
    @("bltu") BranchLessUnsigned = 0x5d,
    @("bge") BranchGreaterEqualSigned = 0x5e,
    @("bgeu") BranchGreaterEqualUnsigned = 0x5f,
    @("ecall") ExtensionCall = 0x7f,
}
