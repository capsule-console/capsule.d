module capsule.core.types;

public pure nothrow @safe @nogc:

enum CapsuleDataSize: uint {
    None = 0,
    Byte = 8,
    HalfWord = 16,
    Word = 32,
    DoubleWord = 64,
}

/// Enumeration of Capsule instruction opcodes
/// Attributes: (name, registers, immediate: never(0), sometimes(1), always(2))
enum CapsuleOpcode: ubyte {
    @("none") None = 0x00, /// Missing or invalid instruction
    @("and") And = 0x04, /// Bitwise AND
    @("andi") AndImmediate = 0x05, /// Bitwise AND immediate
    @("or") Or = 0x06, /// Bitwise OR
    @("ori") OrImmediate = 0x07, /// Bitwise OR immediate
    @("xor") Xor = 0x08, /// Bitwise XOR
    @("xori") XorImmediate = 0x09, /// Bitwise XOR immediate
    @("sll") ShiftLeftLogical = 0x0d, /// Shift logical left
    @("srl") ShiftRightLogical = 0x0e, /// Shift logical right
    @("sra") ShiftRightArithmetic = 0x0f, /// Shift arithmetic right
    @("min") SetMinimumSigned = 0x10, /// Set to minimum
    @("minu") SetMinimumUnsigned = 0x11, /// Set to minimum unsigned
    @("max") SetMaximumSigned = 0x12, /// Set to maximum
    @("maxu") SetMaximumUnsigned = 0x13, /// Set to maximum unsigned
    @("slt") SetLessThanSigned = 0x14, /// Set if less than
    @("sltu") SetLessThanUnsigned = 0x15, /// Set if less than unsigned
    @("slti") SetLessThanImmediateSigned = 0x16, /// Set if less than immediate
    @("sltiu") SetLessThanImmediateUnsigned = 0x17, /// Set if less than immediate unsigned
    @("add") Add = 0x18, /// Add
    @("sub") Subtract = 0x19, /// Subtract
    @("lui") LoadUpperImmediate = 0x1a, /// Load upper immediate
    @("auipc") AddUpperImmediateToPC = 0x1b, /// Add upper immediate to program counter
    @("mul") MultiplyAndTruncate = 0x1c, /// Multiply and truncate
    @("mulh") MultiplySignedAndShift = 0x1d, /// Multiply signed and shift
    @("mulhu") MultiplyUnsignedAndShift = 0x1e, /// Multiply unsigned and shift
    @("mulhsu") MultiplySignedUnsignedAndShift = 0x1f, /// Multiply signed by unsigned and shift
    @("div") DivideSigned = 0x20, /// Divide
    @("divu") DivideUnsigned = 0x21, /// Divide unsigned
    @("rem") RemainderSigned = 0x22, /// Remainder
    @("remu") RemainderUnsigned = 0x23, /// Remainder unsigned
    @("revb") ReverseByteOrder = 0x24, /// Reverse byte order
    @("revh") ReverseHalfWordOrder = 0x25, /// Reverse half word order
    @("clz") CountLeadingZeroes = 0x29, /// Count leading zeros
    @("ctz") CountTrailingZeroes = 0x2a, /// Count trailing zeros
    @("pcnt") CountSetBits = 0x2b, /// Count set bits
    @("lb") LoadByteSignExt = 0x2c, /// Load sign-extended byte
    @("lbu") LoadByteZeroExt = 0x2d, /// Load zero-extended byte
    @("lh") LoadHalfWordSignExt = 0x2e, /// Load sign-extended half word
    @("lhu") LoadHalfWordZeroExt = 0x2f, /// Load zero-extended half word
    @("lw") LoadWord = 0x30, /// Load word
    @("sb") StoreByte = 0x31, /// Store byte
    @("sh") StoreHalfWord = 0x32, /// Store half word
    @("sw") StoreWord = 0x33, /// Store word
    @("jal") JumpAndLink = 0x34, /// Jump and link
    @("jalr") JumpAndLinkRegister = 0x35, /// Jump and link register
    @("beq") BranchEqual = 0x36, /// Branch if equal
    @("bne") BranchNotEqual = 0x37, /// Branch if not equal
    @("blt") BranchLessSigned = 0x38, /// Branch if less than signed
    @("bltu") BranchLessUnsigned = 0x39, /// Branch if less than unsigned
    @("bge") BranchGreaterEqualSigned = 0x3a, /// Branch if greater or equal signed
    @("bgeu") BranchGreaterEqualUnsigned = 0x3b, /// Branch if greater or equal unsigned
    @("ecall") ExtensionCall = 0x3c, /// Call extension
    @("ebreak") Breakpoint = 0x3d, /// Breakpoint
    @("rfe") ReturnFromException = 0x3e, /// Return from exception
}

/// Enumeration of Capsule exception codes
enum CapsuleExceptionCode: ubyte {
    @("none") None = 0x00, /// No exception or missing exception
    @("triple") TripleFault = 0x01, /// Triple fault
    @("double") DoubleFault = 0x02, /// Double fault
    @("instr") InvalidInstruction = 0x03, /// Invalid instruction
    @("break") Breakpoint = 0x04, /// Breakpoint
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
