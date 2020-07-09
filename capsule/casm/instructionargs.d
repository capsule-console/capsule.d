/**

This module defines types used by the Capsule assembly parser to determine
what register and/or immediate arguments to expect for a given instruction
or pseudo-instruction.

*/

module capsule.casm.instructionargs;

private:

import capsule.core.obj : CapsuleObjectReferenceType;
import capsule.core.opcode : CapsuleOpcode;
import capsule.core.register : CapsuleRegisterParameter;

public:

/// Enumeration of descriptions of which register arguments are meaningful
/// to a given Capsule assembly instruction.
enum CapsuleInstructionArgsRegisters: uint {
    /// The instruction recognizes no register arguments.
    /// Examples: break, rfe
    None = 0x0,
    /// The instruction uses only the destination register (rd).
    /// Examples: lui, auipc
    Destination = 0x1,
    /// The instruction uses only the first source register (rs1).
    /// Examples: jr, ret, beqz, bnez, blez, bgez, bltz, bgtz
    FirstSource = 0x2,
    /// The instruction uses only the destination (rd)
    /// and first source register (rs1).
    /// Examples: revb, revh, clz, ctz, pcnt
    DestinationSource = 0x3,
    /// The instruction uses only the second source register (rs2).
    /// Not currently used by any recognized instruction.
    SecondSource = 0x4,
    /// The instruction uses only the destination (rd)
    /// and second source register (rs2).
    /// Examples: sba, sha, swa
    DestinationSecondSource = 0x5,
    /// The instruction uses both source registers (rs1, rs2),
    /// but does not use the destination register (rd).
    /// Examples: beq, bne, blt, bltu, bge, bgeu
    BothSources = 0x6,
    /// The instruction utilizes all three of the register
    /// arguments (rs1, rs2, rd).
    /// Examples: and, or, xor, andn, sll, srl, sra
    All = 0x7,
    /// The instruction uses both source registers (rs2, rs1),
    /// but does not use the destination register (rd),
    /// however the source registers are given in reverse order.
    /// Examples: sw, sh, sb
    BothSourcesSwapped = 0xe,
    /// The instruction utilizes all three of the register
    /// arguments, but the source register order is swapped
    /// (rs2, rs1, rd).
    /// Not currently used by any recognized instruction.
    AllSourcesSwapped = 0xf,
}

/// Enumeration of options for if and how an immediate value argument is
/// meaningful to a given Capsule assembly instruction.
enum CapsuleInstructionArgsImmediate: uint {
    /// Immediate is unused/ignored for this instruction.
    /// Examples: and, or, xor, andn, min, minu, max, maxu
    Never = 0,
    /// Immediate is used for this instruction, though leaving it to
    /// a default zero value is normal and reasonable.
    /// Examples: add, sub, sll, srl, sra
    Maybe,
    /// Immediate is used for this instruction, and leaving it as
    /// an implicit zero value most likely signals a coding mistake.
    /// Examples: andi, ori, xori, slti, sltiu, lui, auipc
    Always,
}

uint[16] CapsuleInstructionArgsRegisterParameterCounts = [
    0, // None
    1, // Destination
    1, // FirstSource
    2, // DestinationSource
    1, // SecondSource
    2, // DestinationSecondSource
    2, // BothSources
    3, // All
    0, // -
    0, // -
    0, // -
    0, // -
    0, // -
    0, // -
    2, // BothSourcesSwapped
    3, // AllSourcesSwapped
];

static const CapsuleRegisterParameter[3] CapsuleInstructionArgsRegisterParameterListNone = [
    CapsuleRegisterParameter.None,
    CapsuleRegisterParameter.None,
    CapsuleRegisterParameter.None,
];

static const CapsuleRegisterParameter[3][16] CapsuleInstructionArgsRegisterParameterLists = [
    // None
    CapsuleInstructionArgsRegisterParameterListNone,
    // Destination
    [
        CapsuleRegisterParameter.Destination,
        CapsuleRegisterParameter.None,
        CapsuleRegisterParameter.None,
    ],
    // FirstSource
    [
        CapsuleRegisterParameter.FirstSource,
        CapsuleRegisterParameter.None,
        CapsuleRegisterParameter.None,
    ],
    // DestinationSource
    [
        CapsuleRegisterParameter.Destination,
        CapsuleRegisterParameter.FirstSource,
        CapsuleRegisterParameter.None,
    ],
    // SecondSource
    [
        CapsuleRegisterParameter.SecondSource,
        CapsuleRegisterParameter.None,
        CapsuleRegisterParameter.None,
    ],
    // DestinationSecondSource
    [
        CapsuleRegisterParameter.Destination,
        CapsuleRegisterParameter.SecondSource,
        CapsuleRegisterParameter.None,
    ],
    // BothSources
    [
        CapsuleRegisterParameter.FirstSource,
        CapsuleRegisterParameter.SecondSource,
        CapsuleRegisterParameter.None,
    ],
    // All
    [
        CapsuleRegisterParameter.Destination,
        CapsuleRegisterParameter.FirstSource,
        CapsuleRegisterParameter.SecondSource,
    ],
    // -
    CapsuleInstructionArgsRegisterParameterListNone,
    // -
    CapsuleInstructionArgsRegisterParameterListNone,
    // -
    CapsuleInstructionArgsRegisterParameterListNone,
    // -
    CapsuleInstructionArgsRegisterParameterListNone,
    // -
    CapsuleInstructionArgsRegisterParameterListNone,
    // -
    CapsuleInstructionArgsRegisterParameterListNone,
    // BothSourcesSwapped
    [
        CapsuleRegisterParameter.SecondSource,
        CapsuleRegisterParameter.FirstSource,
        CapsuleRegisterParameter.None,
    ],
    // AllSourcesSwapped
    [
        CapsuleRegisterParameter.Destination,
        CapsuleRegisterParameter.SecondSource,
        CapsuleRegisterParameter.FirstSource,
    ],
];

/// This type is used by the Capsule assembly parser to determine what
/// arguments are expected for a given instruction or pseudo-instruction.
struct CapsuleInstructionArgs {
    alias Immediate = CapsuleInstructionArgsImmediate;
    alias ReferenceType = CapsuleObjectReferenceType;
    alias Registers = CapsuleInstructionArgsRegisters;
    alias RegisterParameter = CapsuleRegisterParameter;
    alias RegisterParameterCounts = CapsuleInstructionArgsRegisterParameterCounts;
    alias RegisterParameterLists = CapsuleInstructionArgsRegisterParameterLists;
    
    /// Examples: none, break, rfe
    static enum None = typeof(this)(
        Registers.None, Immediate.Never
    );
    /// Examples: lui, auipc
    static enum RegDestImmAlways = typeof(this)(
        Registers.Destination, Immediate.Always
    );
    /// Examples: ret (pseudo-instruction)
    static enum RegSrcImmNever = typeof(this)(
        Registers.FirstSource, Immediate.Never
    );
    /// Examples: revb, revh, clz, ctz, pcnt
    static enum RegDestSrcImmNever = typeof(this)(
        Registers.DestinationSource, Immediate.Never
    );
    /// Examples: lb, lbu, lh, lhu, lw
    static enum Load = typeof(this)(
        Registers.DestinationSource, Immediate.Maybe
    );
    /// Examples: andi, ori, xori, slti, sltiu
    static enum RegDestSrcImmAlways = typeof(this)(
        Registers.DestinationSource, Immediate.Always
    );
    /// Examples: sb, sh, sw
    static enum Store = typeof(this)(
        Registers.BothSourcesSwapped, Immediate.Maybe
    );
    /// Examples: and, or, xor, andn, min, minu, max, maxu
    static enum RegAllImmNever = typeof(this)(
        Registers.All, Immediate.Never
    );
    /// Examples: sll, srl, sra, add, sub
    static enum RegAllImmMaybe = typeof(this)(
        Registers.All, Immediate.Maybe
    );
    /// Examples: beq, bne, blt, bltu, bge, bgeu
    static enum Branch = typeof(this)(
        Registers.BothSources, Immediate.Always,
        ReferenceType.PCRelativeAddressHalf,
    );
    /// Examples: beqz, bnez, blez, bgez, bltz, bgtz (pseudo-instructions)
    static enum BranchCompareZero = typeof(this)(
        Registers.FirstSource, Immediate.Always,
        ReferenceType.PCRelativeAddressHalf,
    );
    /// Examples: jal
    static enum JumpAndLink = typeof(this)(
        Registers.Destination, Immediate.Always,
        ReferenceType.PCRelativeAddressHalf,
    );
    /// Examples: jalr
    static enum JumpAndLinkRegister = typeof(this)(
        Registers.DestinationSource, Immediate.Maybe,
        ReferenceType.PCRelativeAddressHalf,
    );
    /// Examples: ecall
    static enum ExtensionCall = typeof(this)(
        Registers.AllSourcesSwapped, Immediate.Maybe,
    );
    /// Examples: j (pseudo-instruction)
    static enum Jump = typeof(this)(
        Registers.None, Immediate.Always,
        ReferenceType.PCRelativeAddressHalf,
    );
    /// Examples: jr (pseudo-instruction)
    static enum JumpRegister = typeof(this)(
        Registers.FirstSource, Immediate.Always,
        ReferenceType.PCRelativeAddressHalf,
    );
    /// Examples: li (pseudo-instruction)
    static enum LoadImmediate = typeof(this)(
        Registers.Destination, Immediate.Always,
        ReferenceType.AbsoluteWord,
    );
    /// Examples: la (pseudo-instruction)
    static enum LoadAddress = typeof(this)(
        Registers.Destination, Immediate.Always,
        ReferenceType.PCRelativeAddressWord,
    );
    /// Examples: call (pseudo-instruction)
    static enum Call = typeof(this)(
        Registers.Destination, Immediate.Always,
        ReferenceType.PCRelativeAddressWord,
    );
    /// Examples: ret (pseudo-instruction)
    static enum Return = typeof(this)(
        Registers.FirstSource, Immediate.Never,
    );
    /// Examples: ecalli (pseudo-instruction)
    static enum ExtensionCallImmediate = typeof(this)(
        Registers.DestinationSecondSource, Immediate.Always,
        ReferenceType.AbsoluteWord,
    );
    /// Examples: lba, lbua, lha, lhua, lwa (pseudo-instructions)
    static enum LoadFromAddress = typeof(this)(
        Registers.Destination, Immediate.Always,
        ReferenceType.PCRelativeAddressWord,
    );
    /// Examples: sba, sha, swa (pseudo-instructions)
    static enum StoreToAddress = typeof(this)(
        Registers.DestinationSecondSource, Immediate.Always,
        ReferenceType.PCRelativeAddressWord,
    );
    /// Examples: addwi, andwi, orwi, sltwi, sltwiu (pseudo-instructions)
    static enum PseudoWordImmediate = typeof(this)(
        Registers.DestinationSource, Immediate.Always,
        ReferenceType.AbsoluteWord,
    );
    
    /// Indicate which registers are expected as arguments
    Registers registers;
    /// Indicate whether an immediate value is expected as an argument
    Immediate immediate;
    /// Indicate how an immediate value which references a symbol should be
    /// interpreted in the absence of an explicit reference type specifier.
    ReferenceType defaultReferenceType = ReferenceType.AbsoluteHalfWord;
    
    this(
        in Registers registers, in Immediate immediate,
        in ReferenceType defaultReferenceType = ReferenceType.AbsoluteHalfWord,
    ) {
        this.registers = registers;
        this.immediate = immediate;
        this.defaultReferenceType = defaultReferenceType;
    }
    
    static uint getRegisterParamCount(in Registers registers) {
        assert(registers >= 0 && registers < RegisterParameterCounts.length);
        if(cast(uint) registers < RegisterParameterCounts.length) {
            return RegisterParameterCounts[cast(uint) registers];
        }
        else {
            return 0;
        }
    }
    
    static auto getRegisterParamList(in Registers registers) {
        assert(registers >= 0 && registers < RegisterParameterLists.length);
        if(cast(uint) registers < RegisterParameterLists.length) {
            return RegisterParameterLists[cast(uint) registers];
        }
        else {
            return RegisterParameterLists[0];
        }
    }
    
    uint registerParamCount() const {
        return typeof(this).getRegisterParamCount(this.registers);
    }
    
    auto registerParamList() const {
        return typeof(this).getRegisterParamList(this.registers);
    }
    
    RegisterParameter getParamByArgIndex(in uint index) const {
        const registerParamList = this.registerParamList;
        if(index < registerParamList.length) {
            return registerParamList[index];
        }
        else {
            return RegisterParameter.None;
        }
    }
    
    bool opCast(T: bool)() const {
        return (
            this.registers !is Registers.None ||
            this.immediate !is Immediate.Never
        );
    }
}
