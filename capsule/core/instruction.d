/**

This module defines a type that is used to represent a single Capsule
bytecode instruction.

*/

module capsule.core.instruction;

private:

import capsule.core.opcode : CapsuleOpcode;
import capsule.core.opcode : CapsuleOpcodeFlag, getCapsuleOpcodeFlags;
import capsule.core.register : CapsuleRegister;

public:

/// Data structure to represent a capsule instruction.
struct CapsuleInstruction {
    nothrow @safe @nogc:
    
    static enum uint OpcodeMask = 0x007f;
    static enum uint DestinationRegisterMask = 0x0380;
    static enum uint FirstSourceRegisterMask = 0x1c00;
    static enum uint SecondSourceRegisterMask = 0xe000;
    static enum uint ImmediateMask = 0xffff0000;
    
    static assert(uint.max == (
        OpcodeMask ^
        DestinationRegisterMask ^
        FirstSourceRegisterMask ^
        SecondSourceRegisterMask ^
        ImmediateMask
    ));
    
    alias Immediate = short;
    alias Opcode = CapsuleOpcode;
    alias OpcodeFlag = CapsuleOpcodeFlag;
    alias Register = CapsuleRegister;
    
    union {
        uint data;
        Immediate[2] halves;
    }
    
    this(in uint data) {
        this.data = data;
    }
    
    this(
        in Opcode opcode,
        in Register rd, in Register rs1, in Register rs2,
        in Immediate imm16 = 0
    ) {
        assert(cast(uint) opcode <= 0x7f);
        assert(cast(uint) rd < 8);
        assert(cast(uint) rs1 < 8);
        assert(cast(uint) rs2 < 8);
        this(
            (cast(uint) opcode) |
            (cast(uint) rd << 7) |
            (cast(uint) rs1 << 10) |
            (cast(uint) rs2 << 13) |
            (cast(uint) imm16 << 16)
        );
    }
    
    /// Get the instruction's opcode.
    pragma(inline, true) Opcode opcode() pure const {
        return cast(Opcode) (this.data & 0x7f);
    }
    
    /// Assign the instruction's opcode.
    void opcode(in Opcode opcode) pure {
        this.data &= ~OpcodeMask;
        this.data |= opcode;
    }
    
    /// Get the instruction's destination register.
    pragma(inline, true) Register rd() pure const {
        return cast(Register) ((this.data >> 7) & 0x7);
    }
    
    /// Assign the instruction's destination register.
    void rd(in Register register) pure {
        this.data &= ~DestinationRegisterMask;
        this.data |= (cast(uint) register << 7);
    }
    
    /// Get the instruction's first source register.
    pragma(inline, true) Register rs1() pure const {
        return cast(Register) ((this.data >> 10) & 0x7);
    }
    
    /// Assign the instruction's first source register.
    void rs1(in Register register) pure {
        this.data &= ~FirstSourceRegisterMask;
        this.data |= (cast(uint) register << 10);
    }
    
    /// Get the instruction's second source register.
    pragma(inline, true) Register rs2() pure const {
        return cast(Register) ((this.data >> 13) & 0x7);
    }
    
    /// Assign the instruction's second source register.
    void rs2(in Register register) pure {
        this.data &= ~SecondSourceRegisterMask;
        this.data |= (cast(uint) register << 13);
    }
    
    /// Get the instruction's 16-bit immediate value.
    pragma(inline, true) Immediate imm16() pure const {
        return this.halves[1];
    }
    
    /// Assign the instruction's 16-bit immediate value.
    void imm16(in Immediate immediate) pure {
        this.halves[1] = immediate;
    }
    
    /// Get the instruction's immediate value, sign-extended to 32 bits.
    pragma(inline, true) int imm32() pure const {
        return cast(int) this.halves[1];
    }
    
    /// Get the flags associated with this instruction's opcode.
    uint flags() const {
        return getCapsuleOpcodeFlags(this.opcode);
    }
    
    /// Returns true if executing this instruction may change the value
    /// in its destination register.
    bool setsRegister() const {
        return (this.flags & OpcodeFlag.SetsRegister) != 0;
    }
    
    /// Returns true if this instruction, when executed, may access the
    /// value in its first source register.
    bool readsFirstRegister() const {
        return (this.flags & OpcodeFlag.ReadsFirstRegister) != 0;
    }
    
    /// Returns true if this instruction, when executed, may access the
    /// value in its second source register.
    bool readsSecondRegister() const {
        return (this.flags & OpcodeFlag.ReadsSecondRegister) != 0;
    }
    
    /// Returns true if this instruction, when executed, may access its
    /// immediate value.
    bool readsImmediate() const {
        return (this.flags & OpcodeFlag.ReadsImmediate) != 0;
    }
    
    /// Returns true if this instruction's output or other behavior depends
    /// on the current value of the PC, or program counter.
    /// Notably, while this is true of instructions that must read the PC in
    /// order to add an offset to it (auipc, jal, branch instructions) this
    /// flag is not set for the jalr instruction since it changes the PC
    /// without accessing its value first.
    bool readsProgamCounter() const {
        return (this.flags & OpcodeFlag.ReadsPC) != 0;
    }
    
    /// Returns true if executing this instruction may have some effect on
    /// program state besides changing the value in its destination register,
    /// for example executing an extension or storing a value in memory.
    bool hasSideEffect() const {
        return (this.flags & OpcodeFlag.HasSideEffect) != 0;
    }
    
    /// Returns true if this instruction, when executed, may read something
    /// from program memory.
    bool isLoad() const {
        return (this.flags & OpcodeFlag.IsLoad) != 0;
    }
    
    /// Returns true if this instruction, when executed, may store something
    /// in program memory.
    bool isStore() const {
        return (this.flags & OpcodeFlag.IsStore) != 0;
    }
    
    /// Returns true if this instruction, when executed, will access program
    /// memory, whether as a load or as a store.
    bool isMemoryAccess() const {
        return (this.flags & OpcodeFlag.IsMemoryAccess) != 0;
    }
    
    /// Returns true if executing this instruction will unconditionally
    /// cause execution to begin at another location in the program code.
    bool isJump() const {
        return (this.flags & OpcodeFlag.IsJump) != 0;
    }
    
    /// Returns true if executing this instruction will conditionally
    /// cause execution to begin at another location in the program code.
    bool isBranch() const {
        return (this.flags & OpcodeFlag.IsBranch) != 0;
    }
    
    /// Returns true if this instruction will cause executing to begin at
    /// another location in the program code, i.e. if it is either a jump
    /// or a branch instruction.
    bool isControlFlow() const {
        return (this.flags & OpcodeFlag.IsControlFlow) != 0;
    }
    
    /// Returns true if this is a breakpoint (ebreak) instruction.
    /// Breakpoints are a no-operation during normal execution, or signal
    /// a breakpoint if running in a debug mode.
    bool isBreakpoint() const {
        return this.opcode is CapsuleOpcode.Breakpoint;
    }
    
    /// Returns true if this is an extension call (ecall) instruction.
    bool isExtCall() const {
        return this.opcode is CapsuleOpcode.ExtensionCall;
    }
}
