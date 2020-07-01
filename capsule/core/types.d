/**

This module defines fundamental types that are used by the Capsule
virtual machine (capsule) and by the tools that produce Capsule program
files to represent and understand technical information such as
exception codes or bytecode instructions.

*/

module capsule.core.types;

public:

/// Enumeration of Capsule instruction opcodes
/// Attributes: (name, registers, immediate: never(0), sometimes(1), always(2))
enum CapsuleOpcode: ubyte {
    @("none") None = 0x00, /// Missing or invalid instruction
    @("and") And = 0x04, /// Bitwise AND
    @("or") Or = 0x05, /// Bitwise OR
    @("xor") Xor = 0x06, /// Bitwise XOR
    @("sub") Subtract = 0x07, /// Subtract
    @("min") SetMinimumSigned = 0x08, /// Set to minimum
    @("minu") SetMinimumUnsigned = 0x09, /// Set to minimum unsigned
    @("max") SetMaximumSigned = 0x0a, /// Set to maximum
    @("maxu") SetMaximumUnsigned = 0x0b, /// Set to maximum unsigned
    @("slt") SetLessThanSigned = 0x0c, /// Set if less than
    @("sltu") SetLessThanUnsigned = 0x0d, /// Set if less than unsigned
    @("mul") MultiplyAndTruncate = 0x10, /// Multiply and truncate
    @("mulh") MultiplySignedAndShift = 0x11, /// Multiply signed and shift
    @("mulhu") MultiplyUnsignedAndShift = 0x12, /// Multiply unsigned and shift
    @("mulhsu") MultiplySignedUnsignedAndShift = 0x13, /// Multiply signed by unsigned and shift
    @("div") DivideSigned = 0x14, /// Divide
    @("divu") DivideUnsigned = 0x15, /// Divide unsigned
    @("rem") RemainderSigned = 0x16, /// Remainder
    @("remu") RemainderUnsigned = 0x17, /// Remainder unsigned
    @("revb") ReverseByteOrder = 0x18, /// Reverse byte order
    @("revh") ReverseHalfWordOrder = 0x19, /// Reverse half word order
    @("clz") CountLeadingZeroes = 0x1a, /// Count leading zeros
    @("ctz") CountTrailingZeroes = 0x1b, /// Count trailing zeros
    @("pcnt") CountSetBits = 0x1c, /// Count set bits
    @("ebreak") Breakpoint = 0x3f, /// Breakpoint
    @("andi") AndImmediate = 0x44, /// Bitwise AND immediate
    @("ori") OrImmediate = 0x45, /// Bitwise OR immediate
    @("xori") XorImmediate = 0x46, /// Bitwise XOR immediate
    @("sll") ShiftLeftLogical = 0x48, /// Shift logical left
    @("srl") ShiftRightLogical = 0x49, /// Shift logical right
    @("sra") ShiftRightArithmetic = 0x4a, /// Shift arithmetic right
    @("add") Add = 0x4b, /// Add
    @("slti") SetLessThanImmediateSigned = 0x4c, /// Set if less than immediate
    @("sltiu") SetLessThanImmediateUnsigned = 0x4d, /// Set if less than immediate unsigned
    @("lui") LoadUpperImmediate = 0x4e, /// Load upper immediate
    @("auipc") AddUpperImmediateToPC = 0x4f, /// Add upper immediate to program counter
    @("lb") LoadByteSignExt = 0x50, /// Load sign-extended byte
    @("lbu") LoadByteZeroExt = 0x51, /// Load zero-extended byte
    @("lh") LoadHalfWordSignExt = 0x52, /// Load sign-extended half word
    @("lhu") LoadHalfWordZeroExt = 0x53, /// Load zero-extended half word
    @("lw") LoadWord = 0x54, /// Load word
    @("sb") StoreByte = 0x55, /// Store byte
    @("sh") StoreHalfWord = 0x56, /// Store half word
    @("sw") StoreWord = 0x57, /// Store word
    @("jal") JumpAndLink = 0x58, /// Jump and link
    @("jalr") JumpAndLinkRegister = 0x59, /// Jump and link register
    @("beq") BranchEqual = 0x5a, /// Branch if equal
    @("bne") BranchNotEqual = 0x5b, /// Branch if not equal
    @("blt") BranchLessSigned = 0x5c, /// Branch if less than signed
    @("bltu") BranchLessUnsigned = 0x5d, /// Branch if less than unsigned
    @("bge") BranchGreaterEqualSigned = 0x5e, /// Branch if greater or equal signed
    @("bgeu") BranchGreaterEqualUnsigned = 0x5f, /// Branch if greater or equal unsigned
    @("ecall") ExtensionCall = 0x7f, /// Call extension
}

/// Enumeration of Capsule exception codes
enum CapsuleExceptionCode: ubyte {
    @("none") None = 0x00, /// No exception or missing exception
    @("triple") TripleFault = 0x01, /// Triple fault
    @("double") DoubleFault = 0x02, /// Double fault
    @("instr") InvalidInstruction = 0x03, /// Invalid instruction
    @("pcexec") PCNotExecutable = 0x04, /// Program counter not in executable memory
    @("lalign") LoadMisaligned = 0x05, /// Misaligned load
    @("salign") StoreMisaligned = 0x06, /// Misaligned store
    @("pcalign") PCMisaligned = 0x07, /// Misaligned program counter
    @("lbounds") LoadOutOfBounds = 0x08, /// Out-of-bounds load
    @("sbounds") StoreOutOfBounds = 0x09, /// Out-of-bounds store
    @("pcbounds") PCOutOfBounds = 0x0A, /// Out-of-bounds program counter
    @("sro") StoreToReadOnly = 0x0B, /// Store to read-only memory address
    @("ovf") ArithmeticOverflow = 0x0C, /// Arithmetic overflow or underflow
    @("divz") DivideByZero = 0x0D, /// Arithmetic divide by zero
    @("extmiss") ExtensionMissing = 0x0E, /// Unknown or unsupported extension
    @("exterr") ExtensionError = 0x0F, /// Error occured during extension call
}

/// Enumeration of Capsule registers
enum CapsuleRegister: ubyte {
    Z = 0, /// Hard-wired zero
    A, /// Accumulator or function return value by convention
    B, /// Stack frame pointer by convention
    C, /// Counter or function argument by convention
    R, /// Return address by convention
    S, /// Stack pointer by convention
    X, /// Temporary register by convention
    Y, /// Temporary register by convention
}

enum CapsuleRegisterParameter: int {
    None = -1,
    Destination = 0, /// rd
    FirstSource = 1, /// rs1
    SecondSource = 2, /// rs2
}

/// Data structure to represent a capsule instruction.
struct CapsuleInstruction {
    nothrow @safe @nogc:
    
    alias Immediate = short;
    alias Opcode = CapsuleOpcode;
    alias Register = CapsuleRegister;
    alias RegisterParameter = CapsuleRegisterParameter;
    
    /// Opcode
    Opcode opcode;
    /// Destination register (rd)
    Register rd;
    /// First source register (rs1)
    Register rs1;
    /// Second source register (rs2)
    Register rs2;
    /// Immediate value (imm)
    Immediate imm;
    
    /// Destructure from a 32-bit word.
    static typeof(this) decode(in uint data) {
        const ubyte opcode = (data & 0x7F);
        const uint rd = (data >> 7) & 0x7;
        const uint rs1 = (data >> 10) & 0x7;
        const uint rs2 = (data >> 13) & 0x7;
        const uint imm = (data >> 16);
        typeof(this) instr = {
            opcode: cast(Opcode) opcode,
            rd: cast(Register) rd,
            rs1: cast(Register) rs1,
            rs2: cast(Register) rs2,
            imm: cast(Immediate) imm,
        };
        return instr;
    }
    
    /// Encode as a 32-bit word.
    uint encode() const {
        return (
            cast(uint) (this.opcode & 0x7F) |
            ((cast(uint) (this.rd & 0x7)) << 7) |
            ((cast(uint) (this.rs1 & 0x7)) << 10) |
            ((cast(uint) (this.rs2 & 0x7)) << 13) |
            ((cast(uint) this.imm) << 16)
        );
    }
    
    /// Get the immediate value as a signed half word.
    short i16() const {
        return cast(short) this.imm;
    }
    
    /// Get the immediate value as an unsigned half word.
    ushort u16() const {
        return cast(ushort) this.imm;
    }
    
    /// Get the immediate value as a signed-extended half word.
    int i32() const {
        return cast(int) this.imm;
    }
    
    /// Get the immediate value as a zero-extended half word.
    uint u32() const {
        return cast(uint) (cast(ushort) this.imm);
    }
}
