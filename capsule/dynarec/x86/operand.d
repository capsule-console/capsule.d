module capsule.dynarec.x86.operand;

private:

import capsule.dynarec.x86.instruction : X86SIBScale;
import capsule.dynarec.x86.register : X86Register, X86SegmentRegister;
import capsule.dynarec.x86.register : getX86RegisterId, getX86RegisterSize;
import capsule.dynarec.x86.register : isX86ExtendedRegister;
import capsule.dynarec.x86.size : X86AddressSize;
import capsule.dynarec.x86.size : X86ImmediateSize, X86DisplacementSize;

public:

enum X86OperandType: ubyte {
    Register = 1,
    SegmentRegister = 2,
    Indirect = 4,
    Immediate8 = X86ImmediateSize.Byte,
    Immediate16 = X86ImmediateSize.Word,
    Immediate32 = X86ImmediateSize.DWord,
    Immediate64 = X86ImmediateSize.QWord,
}

/// The high two bits correspond to a Mod value from the ModR/M
/// byte and the low three bits correspond to its R/M bits.
enum X86AddressMode16: ubyte {
    BX_SI = 0x00,
    BX_DI = 0x01,
    BP_SI = 0x02,
    BP_DI = 0x03,
    SI = 0x04,
    DI = 0x05,
    disp16 = 0x06,
    BX = 0x07,
    BX_SI_disp8 = 0x40,
    BX_DI_disp8 = 0x41,
    BP_SI_disp8 = 0x42,
    BP_DI_disp8 = 0x43,
    SI_disp8 = 0x44,
    DI_disp8 = 0x45,
    BP_disp8 = 0x46,
    BX_disp8 = 0x47,
    BX_SI_disp16 = 0xc0,
    BX_DI_disp16 = 0xc1,
    BP_SI_disp16 = 0xc2,
    BP_DI_disp16 = 0xc3,
    SI_disp16 = 0xc4,
    DI_disp16 = 0xc5,
    BP_disp16 = 0xc6,
    BX_disp16 = 0xc7,
}

enum X86AddressMode32: ubyte {
    None = 0,
    /// When not in protected mode, this is treated as rip_disp32
    disp32,
    index_disp32,
    base,
    base_disp32,
    base_index,
    base_index_disp32,
    base_disp8,
    base_index_disp8,
    /// Not available in protected mode; conflicts with disp32
    rip_disp32,
}

ubyte getX86AddressMode32Mod(in X86AddressMode32 mode) pure nothrow @safe @nogc {
    alias Mode = X86AddressMode32;
    final switch(mode) {
        case Mode.None: return 0;
        case Mode.disp32: return 0;
        case Mode.index_disp32: return 0;
        case Mode.base: return 0;
        case Mode.base_disp32: return 2;
        case Mode.base_index: return 0;
        case Mode.base_index_disp32: return 2;
        case Mode.base_disp8: return 1;
        case Mode.base_index_disp8: return 1;
        case Mode.rip_disp32: return 0;
    }
}

/// This type is used to represent an operand to an X86 instruction.
/// Operands represent GP registers, segment registers, memory addresses,
/// or immediate values.
struct X86Operand {
    alias AddressMode = X86AddressMode32;
    alias AddressSize = X86AddressSize;
    alias ImmediateSize = X86ImmediateSize;
    alias Scale = X86SIBScale;
    alias Type = X86OperandType;
    
    /// What kind of operand this instance represents.
    Type type;
    /// Represents either a regular GP register operand,
    /// or the base register for a memory address.
    X86Register register;
    /// Index register for a memory address.
    X86Register index;
    /// Represents a segment register operand, or a segment that a
    /// memory address should be relative to.
    X86SegmentRegister segmentRegister;
    /// Whether this operand has a segment override prefix.
    /// Relates to indirection operands.
    bool hasSegmentOverride;
    /// Memory address index scaling factor.
    Scale scale;
    /// Memory address displacement.
    int displacement = 0;
    /// Indicates what addressing mode to use, for indirection operands.
    AddressMode addressMode = AddressMode.None;
    ///
    AddressSize addressSize = AddressSize.None;
    
    /// Immediate value.
    long immediate;
    
    alias base = register;
    
    /// General purpose register, e.g. al, ax, eax, rax
    static typeof(this) Register(in X86Register register) {
        X86Operand operand;
        operand.type = Type.Register;
        operand.register = register;
        return operand;
    }
    
    /// Segment register, e.g. cs, ds, ss, es
    static typeof(this) SegmentRegister(in X86SegmentRegister register) {
        X86Operand operand;
        operand.type = Type.SegmentRegister;
        operand.segmentRegister = register;
        return operand;
    }
    
    /// Indirection with displacement, e.g. [0x123456780]
    static typeof(this) Indirect(in AddressSize addressSize, in int displacement) {
        X86Operand operand;
        operand.type = Type.Indirect;
        operand.displacement = displacement;
        operand.addressMode = AddressMode.disp32;
        operand.addressSize = addressSize;
        return operand;
    }
    
    /// Instruction pointer relative address
    static typeof(this) IndirectRIP(in AddressSize addressSize, in int displacement) {
        X86Operand operand;
        operand.type = Type.Indirect;
        operand.displacement = displacement;
        operand.addressMode = AddressMode.rip_disp32;
        operand.addressSize = addressSize;
        return operand;
    }
    
    static typeof(this) Indirect(
        in AddressSize addressSize, in X86Register base,
        in int displacement = 0,
    ) {
        X86Operand operand;
        operand.type = Type.Indirect;
        operand.register = base;
        operand.displacement = displacement;
        operand.addressSize = addressSize;
        enum bpRegisterId = getX86RegisterId(X86Register.rbp);
        const baseRegisterId = getX86RegisterId(base);
        operand.addressMode = (
            displacement == 0 && baseRegisterId != bpRegisterId ?
            AddressMode.base :
            displacement == cast(byte) displacement ?
            AddressMode.base_disp8 :
            AddressMode.base_disp32
        );
        return operand;
    }
    
    static typeof(this) IndirectIndex(
        in AddressSize addressSize,
        in X86Register index, in Scale scale,
        in int displacement,
    ) {
        assert(scale !is Scale.One);
        X86Operand operand;
        operand.type = Type.Indirect;
        operand.index = index;
        operand.scale = scale;
        operand.displacement = displacement;
        operand.addressSize = addressSize;
        operand.addressMode = AddressMode.index_disp32;
        return operand;
    }
    
    static typeof(this) Indirect(
        in AddressSize addressSize,
        in X86Register base, in X86Register index,
        in Scale scale, in int displacement = 0
    ) {
        assert(getX86RegisterId(index) != getX86RegisterId(X86Register.rsp));
        X86Operand operand;
        operand.type = Type.Indirect;
        operand.register = base;
        operand.index = index;
        operand.scale = scale;
        operand.displacement = displacement;
        operand.addressSize = addressSize;
        enum bpRegisterId = getX86RegisterId(X86Register.rbp);
        const baseRegisterId = getX86RegisterId(base);
        operand.addressMode = (
            displacement == 0 && baseRegisterId != bpRegisterId ?
            AddressMode.base_index :
            displacement == cast(byte) displacement ?
            AddressMode.base_index_disp8 :
            AddressMode.base_index_disp32
        );
        return operand;
    }
    
    static typeof(this) Immediate8(in byte immediate) {
        X86Operand operand;
        operand.type = Type.Immediate8;
        operand.immediate = cast(long) immediate;
        return operand;
    }
    
    static typeof(this) Immediate16(in short immediate) {
        X86Operand operand;
        operand.type = Type.Immediate16;
        operand.immediate = cast(long) immediate;
        return operand;
    }
    
    static typeof(this) Immediate32(in int immediate) {
        X86Operand operand;
        operand.type = Type.Immediate32;
        operand.immediate = cast(long) immediate;
        return operand;
    }
    
    static typeof(this) Immediate64(in long immediate) {
        X86Operand operand;
        operand.type = Type.Immediate64;
        operand.immediate = cast(long) immediate;
        return operand;
    }
    
    typeof(this) SegmentOverride(in X86SegmentRegister register) pure const {
        assert(this.isIndirect);
        X86Operand operand = this;
        operand.segmentRegister = register;
        operand.hasSegmentOverride = true;
        return operand;
    }
    
    bool isValidIndirect() pure const {
        const hasBase = this.hasBaseRegister;
        const hasIndex = this.hasIndexRegister;
        const baseSize = this.baseRegisterSize;
        const indexSize = this.indexRegisterSize;
        return this.isIndirect && this.addressMode && (
            (!hasBase || baseSize >= 32) &&
            (!hasIndex || indexSize >= 32) &&
            (!hasBase || !hasIndex || baseSize == indexSize) &&
            (this.addressSize !is AddressSize.None)
        );
    }
    
    /// Returns true if this operand represents a general-purpose register.
    bool isRegister() pure const {
        return this.type is Type.Register;
    }
    
    bool isSegmentRegister() pure const {
        return this.type is Type.SegmentRegister;
    }
    
    /// Returns true if this operand represents an indirection.
    bool isIndirect() pure const {
        return this.type is Type.Indirect;
    }
    
    bool isImmediate8() pure const {
        return this.type is Type.Immediate8;
    }
    
    bool isImmediate16() pure const {
        return this.type is Type.Immediate16;
    }
    
    bool isImmediate32() pure const {
        return this.type is Type.Immediate32;
    }
    
    bool isImmediate64() pure const {
        return this.type is Type.Immediate64;
    }
    
    /// Returns true if this operand represents an immediate value.
    bool isImmediate() pure const {
        final switch(this.type) {
            case Type.Register: return false;
            case Type.SegmentRegister: return false;
            case Type.Indirect: return false;
            case Type.Immediate8: return true;
            case Type.Immediate16: return true;
            case Type.Immediate32: return true;
            case Type.Immediate64: return true;
        }
    }
    
    /// Get the size in bits of the immediate value, or zero if the
    /// operand does not define an immediate value.
    X86ImmediateSize immediateSize() pure const {
        final switch(this.type) {
            case Type.Register: return X86ImmediateSize.None;
            case Type.SegmentRegister: return X86ImmediateSize.None;
            case Type.Indirect: return X86ImmediateSize.None;
            case Type.Immediate8: return X86ImmediateSize.Byte;
            case Type.Immediate16: return X86ImmediateSize.Word;
            case Type.Immediate32: return X86ImmediateSize.DWord;
            case Type.Immediate64: return X86ImmediateSize.QWord;
        }
    }
    
    /// Get the size in bits of the register value, or zero if the
    /// operand does not define an register value.
    uint registerSize() pure const {
        return this.isRegister ? getX86RegisterSize(this.register) : 0;
    }
    
    uint baseRegisterSize() pure const {
        return this.hasBaseRegister ? getX86RegisterSize(this.base) : 0;
    }
    
    uint indexRegisterSize() pure const {
        return this.hasIndexRegister ? getX86RegisterSize(this.index) : 0;
    }
    
    /// Get the register ID, or -1 if this isn't a register operand.
    int registerId() pure const {
        return (this.isRegister ?
            cast(int) getX86RegisterId(this.register) : -1
        );
    }
    
    int segmentRegisterId() pure const {
        return (this.hasSegmentRegister ?
            cast(int) this.segmentRegister : -1
        );
    }
    
    int baseRegisterId() pure const {
        return (this.hasBaseRegister ?
            cast(int) getX86RegisterId(this.base) : -1
        );
    }
    
    int indexRegisterId() pure const {
        return (this.hasIndexRegister ?
            cast(int) getX86RegisterId(this.index) : -1
        );
    }
    
    /// Get whether this is a register operand and the high bit of
    /// the register ID is set.
    bool isExtendedRegister() pure const {
        return (this.isRegister && isX86ExtendedRegister(this.register));
    }
    
    ///
    bool baseIsExtendedRegister() pure const {
        return (this.hasBaseRegister && isX86ExtendedRegister(this.base));
    }
    
    ///
    bool indexIsExtendedRegister() pure const {
        return (this.hasIndexRegister && isX86ExtendedRegister(this.index));
    }
    
    bool hasSegmentRegister() pure const {
        return this.type is Type.SegmentRegister || (
            this.hasSegmentOverride && this.type is Type.Indirect
        );
    }
    
    bool hasBaseRegister() pure const {
        alias Mode = X86AddressMode32;
        final switch(this.addressMode) {
            case Mode.None: return false;
            case Mode.disp32: return false;
            case Mode.index_disp32: return false;
            case Mode.base: return true;
            case Mode.base_disp32: return true;
            case Mode.base_index: return true;
            case Mode.base_index_disp32: return true;
            case Mode.base_disp8: return true;
            case Mode.base_index_disp8: return true;
            case Mode.rip_disp32: return false;
        }
    }
    
    bool hasIndexRegister() pure const {
        alias Mode = X86AddressMode32;
        final switch(this.addressMode) {
            case Mode.None: return false;
            case Mode.disp32: return false;
            case Mode.index_disp32: return true;
            case Mode.base: return false;
            case Mode.base_disp32: return false;
            case Mode.base_index: return true;
            case Mode.base_index_disp32: return true;
            case Mode.base_disp8: return false;
            case Mode.base_index_disp8: return true;
            case Mode.rip_disp32: return false;
        }
    }
    
    bool hasDisplacement8() pure const {
        alias Mode = X86AddressMode32;
        final switch(this.addressMode) {
            case Mode.None: return false;
            case Mode.disp32: return false;
            case Mode.index_disp32: return false;
            case Mode.base: return false;
            case Mode.base_disp32: return false;
            case Mode.base_index: return false;
            case Mode.base_index_disp32: return false;
            case Mode.base_disp8: return true;
            case Mode.base_index_disp8: return true;
            case Mode.rip_disp32: return false;
        }
    }
    
    bool hasDisplacement32() pure const {
        alias Mode = X86AddressMode32;
        final switch(this.addressMode) {
            case Mode.None: return false;
            case Mode.disp32: return true;
            case Mode.index_disp32: return true;
            case Mode.base: return false;
            case Mode.base_disp32: return true;
            case Mode.base_index: return false;
            case Mode.base_index_disp32: return true;
            case Mode.base_disp8: return false;
            case Mode.base_index_disp8: return false;
            case Mode.rip_disp32: return true;
        }
    }
    
    X86DisplacementSize displacementSize() pure const {
        alias Mode = X86AddressMode32;
        final switch(this.addressMode) {
            case Mode.None: return X86DisplacementSize.None;
            case Mode.disp32: return X86DisplacementSize.DWord;
            case Mode.index_disp32: return X86DisplacementSize.DWord;
            case Mode.base: return X86DisplacementSize.None;
            case Mode.base_disp32: return X86DisplacementSize.DWord;
            case Mode.base_index: return X86DisplacementSize.None;
            case Mode.base_index_disp32: return X86DisplacementSize.DWord;
            case Mode.base_disp8: return X86DisplacementSize.Byte;
            case Mode.base_index_disp8: return X86DisplacementSize.Byte;
            case Mode.rip_disp32: return X86DisplacementSize.DWord;
        }
    }
    
    byte getAddressModeMod() pure const {
        return getX86AddressMode32Mod(this.addressMode);
    }
}
