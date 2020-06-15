module capsule.casm.syntax;

import capsule.core.ascii : isDigit, eitherCaseStringEquals;
import capsule.core.enums : getEnumMemberName, getEnumMemberAttribute;
import capsule.core.file : FileLocation;
import capsule.casm.instructionargs : CapsuleInstructionArgs;
import capsule.core.obj : CapsuleObjectReference, CapsuleObjectSymbol;
import capsule.core.typestrings : getCapsuleOpcodeName;
import capsule.core.types : CapsuleInstruction, CapsuleOpcode;

public nothrow @safe @nogc:

Type getCapsuleAsmNodeTypeWithName(Type)(in string name) {
    foreach(member; __traits(allMembers, Type)) {
        static assert(member.length);
        enum type = __traits(getMember, Type, member);
        const typeName = getEnumMemberAttribute!string(type);
        if(eitherCaseStringEquals(name, typeName)) {
            return type;
        }
    }
    return Type.None;
}

/// Enumeration of recognized Capsule assembly syntax node types.
enum CapsuleAsmNodeType: uint {
    /// No node or missing node
    None = 0,
    /// Node represents a label definition, e.g. "my_label:"
    Label = 1,
    /// Node represents a instruction, e.g. "add A, B, C"
    Instruction = 2,
    /// Node represents a pseudo-instruction, e.g. "li A, 0x1234"
    PseudoInstruction = 3,
    /// Node represents a directive, e.g. ".text"
    Directive = 4,
}

/// Enumeration of recognized number directives, which are special
/// numeric values assigned by the linker and referenced
/// using an identifier beginning with a period '.'
enum CapsuleAsmNumberLinkDirectiveType: uint {
    None = 0,
    @("text") TextSegmentOffset,
    @("rodata") ReadOnlyDataSegmentOffset,
    @("data") DataSegmentOffset,
    @("bss") BSSSegmentOffset,
}

/// Enumeration of recognized pseudo-instructions
enum CapsuleAsmPseudoInstructionType: uint {
    @("none") None = 0,
    @("nop") NoOperation,
    @("mv") CopyRegister,
    @("not") Not,
    @("neg") Negate,
    @("nand") Nand,
    @("nor") Nor,
    @("xnor") Xnor,
    @("nandi") NandImmediate,
    @("nori") NorImmediate,
    @("xnori") XnorImmediate,
    @("andn") AndNot,
    @("orn") OrNot,
    @("xorn") XorNot,
    @("slli") ShiftLeftLogicalImmediate,
    @("srli") ShiftRightLogicalImmediate,
    @("srai") ShiftRightArithmeticImmediate,
    @("addi") AddImmediate,
    @("addwi") AddWordImmediate,
    @("andwi") AndWordImmediate,
    @("orwi") OrWordImmediate,
    @("xorwi") XorWordImmediate,
    @("sltwi") SetLessThanWordImmediateSigned,
    @("sltwiu") SetLessThanWordImmediateUnsigned,
    @("clo") CountLeadingOnes,
    @("cto") CountTrailingOnes,
    @("seqz") SetEqualZero,
    @("snez") SetNotEqualZero,
    @("sltz") SetLessZero,
    @("sgtz") SetGreaterZero,
    @("slez") SetLessEqualZero,
    @("sgez") SetGreaterEqualZero,
    @("li") LoadImmediate,
    @("la") LoadAddress,
    @("lba") LoadByteSignExt,
    @("lbua") LoadByteZeroExt,
    @("lha") LoadHalfWordSignExt,
    @("lhua") LoadHalfWordZeroExt,
    @("lwa") LoadWord,
    @("sba") StoreByte,
    @("sha") StoreHalfWord,
    @("swa") StoreWord,
    @("seq") SetEqual,
    @("sne") SetNotEqual,
    @("sge") SetGreaterEqualSigned,
    @("sgeu") SetGreaterEqualUnsigned,
    @("sgt") SetGreaterSigned,
    @("sgtu") SetGreaterUnsigned,
    @("sle") SetLessEqualSigned,
    @("sleu") SetLessEqualUnsigned,
    @("beqz") BranchEqualZero,
    @("bnez") BranchNotEqualZero,
    @("blez") BranchLessEqualZero,
    @("bgez") BranchGreaterEqualZero,
    @("bltz") BranchLessZero,
    @("bgtz") BranchGreaterZero,
    @("bgt") BranchGreaterSigned,
    @("ble") BranchLessEqualSigned,
    @("bgtu") BranchGreaterUnsigned,
    @("bleu") BranchLessEqualUnsigned,
    @("j") Jump,
    @("jr") JumpRegister,
    @("call") Call,
    @("ret") Return,
    @("ecalli") ExtensionCallImmediate,
}

/// Enumeration of recognized directives
enum CapsuleAsmDirectiveType: uint {
    @("none") None = 0,
    @("align") Align,
    @("bss") BSS,
    @("byte") Byte,
    @("comment") Comment,
    @("const") Constant,
    @("data") Data,
    @("endproc") EndProcedure,
    @("entry") Entry,
    @("export") Export,
    @("extern") Extern,
    @("half") HalfWord,
    @("padb") PadBytes,
    @("padh") PadHalfWords,
    @("padw") PadWords,
    @("priority") Priority,
    @("procedure") Procedure,
    @("resb") ReserveBytes,
    @("resh") ReserveHalfWords,
    @("resw") ReserveWords,
    @("rodata") ReadOnlyData,
    @("string") String,
    @("stringz") StringZ,
    @("text") Text,
    @("word") Word,
}

auto getCapsuleInstructionArgs(in CapsuleOpcode opcode) {
    alias Args = CapsuleInstructionArgs;
    alias Opcode = CapsuleOpcode;
    switch(opcode) {
        case Opcode.None: return Args.None;
        case Opcode.And: return Args.RegAllImmNever;
        case Opcode.AndImmediate: return Args.RegDestSrcImmAlways;
        case Opcode.Or: return Args.RegAllImmNever;
        case Opcode.OrImmediate: return Args.RegDestSrcImmAlways;
        case Opcode.Xor: return Args.RegAllImmNever;
        case Opcode.XorImmediate: return Args.RegDestSrcImmAlways;
        case Opcode.ShiftLeftLogical: return Args.RegAllImmMaybe;
        case Opcode.ShiftRightLogical: return Args.RegAllImmMaybe;
        case Opcode.ShiftRightArithmetic: return Args.RegAllImmMaybe;
        case Opcode.SetMinimumSigned: return Args.RegAllImmNever;
        case Opcode.SetMinimumUnsigned: return Args.RegAllImmNever;
        case Opcode.SetMaximumSigned: return Args.RegAllImmNever;
        case Opcode.SetMaximumUnsigned: return Args.RegAllImmNever;
        case Opcode.SetLessThanSigned: return Args.RegAllImmNever;
        case Opcode.SetLessThanUnsigned: return Args.RegAllImmNever;
        case Opcode.SetLessThanImmediateSigned: return Args.RegDestSrcImmAlways;
        case Opcode.SetLessThanImmediateUnsigned: return Args.RegDestSrcImmAlways;
        case Opcode.Add: return Args.RegAllImmMaybe;
        case Opcode.Subtract: return Args.RegAllImmMaybe;
        case Opcode.LoadUpperImmediate: return Args.RegDestImmAlways;
        case Opcode.AddUpperImmediateToPC: return Args.RegDestImmAlways;
        case Opcode.MultiplyAndTruncate: return Args.RegAllImmNever;
        case Opcode.MultiplySignedAndShift: return Args.RegAllImmNever;
        case Opcode.MultiplyUnsignedAndShift: return Args.RegAllImmNever;
        case Opcode.MultiplySignedUnsignedAndShift: return Args.RegAllImmNever;
        case Opcode.DivideSigned: return Args.RegAllImmNever;
        case Opcode.DivideUnsigned: return Args.RegAllImmNever;
        case Opcode.RemainderSigned: return Args.RegAllImmNever;
        case Opcode.RemainderUnsigned: return Args.RegAllImmNever;
        case Opcode.ReverseByteOrder: return Args.RegDestSrcImmNever;
        case Opcode.ReverseHalfWordOrder: return Args.RegDestSrcImmNever;
        case Opcode.CountLeadingZeroes: return Args.RegDestSrcImmNever;
        case Opcode.CountTrailingZeroes: return Args.RegDestSrcImmNever;
        case Opcode.CountSetBits: return Args.RegDestSrcImmNever;
        case Opcode.LoadByteSignExt: return Args.RegDestSrcImmMaybe;
        case Opcode.LoadByteZeroExt: return Args.RegDestSrcImmMaybe;
        case Opcode.LoadHalfWordSignExt: return Args.RegDestSrcImmMaybe;
        case Opcode.LoadHalfWordZeroExt: return Args.RegDestSrcImmMaybe;
        case Opcode.LoadWord: return Args.RegDestSrcImmMaybe;
        case Opcode.StoreByte: return Args.RegBothSrcImmMaybe;
        case Opcode.StoreHalfWord: return Args.RegBothSrcImmMaybe;
        case Opcode.StoreWord: return Args.RegBothSrcImmMaybe;
        case Opcode.JumpAndLink: return Args.JumpAndLink;
        case Opcode.JumpAndLinkRegister: return Args.JumpAndLinkRegister;
        case Opcode.BranchEqual: return Args.Branch;
        case Opcode.BranchNotEqual: return Args.Branch;
        case Opcode.BranchLessSigned: return Args.Branch;
        case Opcode.BranchLessUnsigned: return Args.Branch;
        case Opcode.BranchGreaterEqualSigned: return Args.Branch;
        case Opcode.BranchGreaterEqualUnsigned: return Args.Branch;
        case Opcode.ExtensionCall: return Args.RegAllImmMaybe;
        case Opcode.Breakpoint: return Args.None;
        default: return Args.None;
    }
}

auto getCapsulePseudoInstructionArgs(in CapsuleAsmPseudoInstructionType type) {
    alias Args = CapsuleInstructionArgs;
    alias Type = CapsuleAsmPseudoInstructionType;
    switch(type) {
        case Type.NoOperation: return Args.None;
        case Type.CopyRegister: return Args.RegDestSrcImmNever;
        case Type.Not: return Args.RegDestSrcImmNever;
        case Type.Negate: return Args.RegDestSrcImmNever;
        case Type.Nand: return Args.RegAllImmNever;
        case Type.Nor: return Args.RegAllImmNever;
        case Type.Xnor: return Args.RegAllImmNever;
        case Type.NandImmediate: return Args.RegDestSrcImmAlways;
        case Type.NorImmediate: return Args.RegDestSrcImmAlways;
        case Type.XnorImmediate: return Args.RegDestSrcImmAlways;
        case Type.AndNot: return Args.RegAllImmNever;
        case Type.OrNot: return Args.RegAllImmNever;
        case Type.XorNot: return Args.RegAllImmNever;
        case Type.ShiftLeftLogicalImmediate: return Args.RegDestSrcImmAlways;
        case Type.ShiftRightLogicalImmediate: return Args.RegDestSrcImmAlways;
        case Type.ShiftRightArithmeticImmediate: return Args.RegDestSrcImmAlways;
        case Type.AddImmediate: return Args.RegDestSrcImmAlways;
        case Type.AddWordImmediate: return Args.PseudoWordImmediate;
        case Type.AndWordImmediate: return Args.PseudoWordImmediate;
        case Type.OrWordImmediate: return Args.PseudoWordImmediate;
        case Type.XorWordImmediate: return Args.PseudoWordImmediate;
        case Type.SetLessThanWordImmediateSigned: return Args.PseudoWordImmediate;
        case Type.SetLessThanWordImmediateUnsigned: return Args.PseudoWordImmediate;
        case Type.CountLeadingOnes: return Args.RegDestSrcImmNever;
        case Type.CountTrailingOnes: return Args.RegDestSrcImmNever;
        case Type.SetEqualZero: return Args.RegDestSrcImmNever;
        case Type.SetNotEqualZero: return Args.RegDestSrcImmNever;
        case Type.SetLessZero: return Args.RegDestSrcImmNever;
        case Type.SetGreaterZero: return Args.RegDestSrcImmNever;
        case Type.SetLessEqualZero: return Args.RegDestSrcImmNever;
        case Type.SetGreaterEqualZero: return Args.RegDestSrcImmNever;
        case Type.LoadImmediate: return Args.LoadImmediate;
        case Type.LoadAddress: return Args.LoadAddress;
        case Type.LoadByteSignExt: return Args.RegDestImmAlways;
        case Type.LoadByteZeroExt: return Args.RegDestImmAlways;
        case Type.LoadHalfWordSignExt: return Args.RegDestImmAlways;
        case Type.LoadHalfWordZeroExt: return Args.RegDestImmAlways;
        case Type.LoadWord: return Args.RegDestImmAlways;
        case Type.StoreByte: return Args.StoreAddress;
        case Type.StoreHalfWord: return Args.StoreAddress;
        case Type.StoreWord: return Args.StoreAddress;
        case Type.SetEqual: return Args.RegAllImmNever;
        case Type.SetNotEqual: return Args.RegAllImmNever;
        case Type.SetGreaterEqualSigned: return Args.RegAllImmNever;
        case Type.SetGreaterEqualUnsigned: return Args.RegAllImmNever;
        case Type.SetGreaterSigned: return Args.RegAllImmNever;
        case Type.SetGreaterUnsigned: return Args.RegAllImmNever;
        case Type.SetLessEqualSigned: return Args.RegAllImmNever;
        case Type.SetLessEqualUnsigned: return Args.RegAllImmNever;
        case Type.BranchEqualZero: return Args.BranchCompareZero;
        case Type.BranchNotEqualZero: return Args.BranchCompareZero;
        case Type.BranchLessEqualZero: return Args.BranchCompareZero;
        case Type.BranchGreaterEqualZero: return Args.BranchCompareZero;
        case Type.BranchLessZero: return Args.BranchCompareZero;
        case Type.BranchGreaterZero: return Args.BranchCompareZero;
        case Type.BranchGreaterSigned: return Args.Branch;
        case Type.BranchLessEqualSigned: return Args.Branch;
        case Type.BranchGreaterUnsigned: return Args.Branch;
        case Type.BranchLessEqualUnsigned: return Args.Branch;
        case Type.Jump: return Args.Jump;
        case Type.JumpRegister: return Args.JumpRegister;
        case Type.Call: return Args.Call;
        case Type.Return: return Args.RegSrcImmNever;
        case Type.ExtensionCallImmediate: return Args.ExtensionCallImmediate;
        default: return Args.None;
    }
}

struct CapsuleAsmNumber {
    nothrow @safe @nogc:
    
    alias LinkDirectiveType = CapsuleAsmNumberLinkDirectiveType;
    alias LocalType = CapsuleObjectReference.LocalType;
    alias ReferenceType = CapsuleObjectReference.Type;
    
    /// The literal value represented by this number, if any.
    long value = 0;
    
    /// Identifies the type of reference, if this number represents
    /// a reference to a symbol as opposed to a literal value.
    ReferenceType referenceType = ReferenceType.None;
    /// For locals, indicates whether this is a forward or a
    /// backward reference.
    LocalType localType = LocalType.None;
    /// Name of the symbol being referenced.
    string name = null;
    /// A constant value to add to a referenced value.
    int addend = 0;
    
    this(in long value) {
        this.value = value;
    }
    
    this(
        in ReferenceType referenceType, in LocalType localType,
        in string name, in int addend = 0
    ) {
        this.referenceType = referenceType;
        this.localType = localType;
        this.name = name;
        this.addend = addend;
    }
    
    /// Get a number that is a copy of this one, but with the reference
    /// information set to whatever the input was.
    typeof(this) withReferenceType(in ReferenceType referenceType) const {
        CapsuleAsmNumber number;
        number.value = this.value;
        number.referenceType = referenceType;
        number.localType = this.localType;
        number.name = this.name;
        number.addend = this.addend;
        return number;
    }
    
    bool isPcRelativeReference() const {
        return CapsuleObjectReference.isPcRelativeType(this.referenceType);
    }
    
    bool isPcRelativeLowHalfReference() const {
        return CapsuleObjectReference.isPcRelativeLowHalfType(this.referenceType);
    }
    
    bool opCast(T: bool)() const {
        return this.referenceType || this.value != 0;
    }
}

/// Syntax nodes are produced by the CapsuleAsmParser from assembly
/// source, and consumed by the CapsuleAsmCompiler in order to produce
/// an object file.
struct CapsuleAsmNode {
    nothrow @safe @nogc:
    
    alias DirectiveType = CapsuleAsmDirectiveType;
    alias InstructionArgs = CapsuleInstructionArgs;
    alias Number = CapsuleAsmNumber;
    alias PseudoInstructionType = CapsuleAsmPseudoInstructionType;
    alias Type = CapsuleAsmNodeType;
    
    alias getInstructionArgs = getCapsuleInstructionArgs;
    alias getPseudoInstructionArgs = getCapsulePseudoInstructionArgs;
    alias getTypeWithName = getCapsuleAsmNodeTypeWithName;
    alias getPseudoInstructionTypeWithName = getCapsuleAsmNodeTypeWithName!PseudoInstructionType;
    alias getDirectiveTypeWithName = getCapsuleAsmNodeTypeWithName!DirectiveType;
    
    FileLocation location;
    Type type = Type.None;
    uint subtype = 0;
    
    union {
        // Data for labels
        CapsuleAsmLabelNode label;
        // Data for instructions and pseudo-instructions
        CapsuleAsmInstructionNode instruction;
        // Data for .align, .padb, .resb, .resh, .resw
        CapsuleAsmPadDirectiveNode padDirective;
        // Data for .byte, .half, .word
        CapsuleAsmByteDataDirectiveNode byteDataDirective;
        // Data for .comment, .string, .stringz
        CapsuleAsmTextDataDirectiveNode textDirective;
        // Data for .const
        CapsuleAsmConstantDirectiveNode constDirective;
        // Data for .export, .extern
        CapsuleAsmSymbolDirectiveNode symbolDirective;
        // Data for .priority
        CapsuleAsmValueDirectiveNode!int intDirective;
    }
    
    this(in FileLocation location, in Type type) {
        this.location = location;
        this.type = type;
    }
    
    this(in FileLocation location, in Type type, in uint subtype) {
        this.location = location;
        this.type = type;
        this.subtype = subtype;
    }
    
    this(in FileLocation location, in PseudoInstructionType pseudoType) {
        this.location = location;
        this.type = Type.PseudoInstruction;
        this.subtype = cast(uint) pseudoType;
    }
    
    this(in FileLocation location, in DirectiveType directiveType) {
        this.location = location;
        this.type = Type.Directive;
        this.subtype = cast(uint) directiveType;
    }
    
    this(
        in FileLocation location, in ubyte opcode,
        in ubyte rd, in ubyte rs1, in ubyte rs2, 
        in Number immediate = Number.init
    ) @trusted {
        this.location = location;
        this.type = Type.Instruction;
        this.instruction.opcode = opcode;
        this.instruction.rd = rd;
        this.instruction.rs1 = rs1;
        this.instruction.rs2 = rs2;
        this.instruction.immediate = immediate;
    }
    
    static auto getDirectiveDefinitionType(in DirectiveType type) {
        alias Symbol = CapsuleObjectSymbol;
        switch(type) {
            case DirectiveType.Procedure: return Symbol.Type.Procedure;
            default: return Symbol.Type.None;
        }
    }
    
    static bool isPadDirectiveType(in DirectiveType type) {
        return (
            type is DirectiveType.Align ||
            type is DirectiveType.PadBytes ||
            type is DirectiveType.PadHalfWords ||
            type is DirectiveType.PadWords ||
            type is DirectiveType.ReserveBytes ||
            type is DirectiveType.ReserveHalfWords ||
            type is DirectiveType.ReserveWords
        );
    }
    
    static bool isByteDataDirectiveType(in DirectiveType type) {
        return (
            type is DirectiveType.Byte ||
            type is DirectiveType.HalfWord ||
            type is DirectiveType.Word
        );
    }
    
    static bool isTextDirectiveType(in DirectiveType type) {
        return (
            type is DirectiveType.Comment ||
            type is DirectiveType.String ||
            type is DirectiveType.StringZ
        );
    }
    
    static bool isConstDirectiveType(in DirectiveType type) {
        return type is DirectiveType.Constant;
    }
    
    static bool isSymbolDirectiveType(in DirectiveType type) {
        return (
            type is DirectiveType.EndProcedure ||
            type is DirectiveType.Export ||
            type is DirectiveType.Extern
        );
    }
    
    static bool isIntDirectiveType(in DirectiveType type) {
        return type is DirectiveType.Priority;
    }
    
    static string getTypeName(Type)(in Type type) {
        const typeName = getEnumMemberAttribute!string(type);
        return typeName;
    }
    
    auto instructionArgs() @trusted const {
        if(this.isInstruction) {
            return getInstructionArgs(cast(CapsuleOpcode) this.instruction.opcode);
        }
        else if(this.isPseudoInstruction) {
            return getPseudoInstructionArgs(this.pseudoInstructionType);
        }
        else {
            assert(false, "Syntax node is not an instruction.");
        }
    }
    
    auto getDirectiveDefinitionType() const {
        if(this.isDirective) {
            return this.getDirectiveDefinitionType(this.directiveType);
        }
        else {
            return CapsuleObjectSymbol.Type.None;
        }
    }
    
    bool isLabel() const {
        return this.type is Type.Label;
    }
    
    bool isInstruction() const {
        return this.type is Type.Instruction;
    }
    
    bool isPseudoInstruction() const {
        return this.type is Type.PseudoInstruction;
    }
    
    bool isPseudoInstructionType(in PseudoInstructionType type) const {
        return this.type is Type.PseudoInstruction && this.pseudoInstructionType is type;
    }
    
    bool isDirective() const {
        return this.type is Type.Directive;
    }
    
    bool isDirectiveType(in DirectiveType type) const {
        return this.type is Type.Directive && this.directiveType is type;
    }
    
    bool isPadDirective() const {
        return this.isDirective && isPadDirectiveType(this.directiveType);
    }
    
    bool isByteDataDirective() const {
        return this.isDirective && isByteDataDirectiveType(this.directiveType);
    }
    
    bool isTextDirective() const {
        return this.isDirective && isTextDirectiveType(this.directiveType);
    }
    
    bool isConstDirective() const {
        return this.isDirective && isConstDirectiveType(this.directiveType);
    }
    
    bool isSymbolDirective() const {
        return this.isDirective && isSymbolDirectiveType(this.directiveType);
    }
    
    bool isIntDirective() const {
        return this.isDirective && isIntDirectiveType(this.directiveType);
    }
    
    PseudoInstructionType pseudoInstructionType() const {
        assert(this.type is Type.PseudoInstruction);
        return cast(PseudoInstructionType) this.subtype;
    }
    
    DirectiveType directiveType() const {
        assert(this.type is Type.Directive);
        return cast(DirectiveType) this.subtype;
    }
    
    string getName() @trusted const {
        if(this.type is Type.Label) {
            return "label";
        }
        else if(this.type is Type.Instruction) {
            return getCapsuleOpcodeName(this.instruction.opcode);
        }
        else if(this.type is Type.PseudoInstruction) {
            return typeof(this).getTypeName(this.pseudoInstructionType);
        }
        else if(this.type is Type.Directive) {
            return typeof(this).getTypeName(this.directiveType);
        }
        else {
            return null;
        }
    }
    
    bool opCast(T: bool)() const {
        return this.type !is Type.None;
    }
}

struct CapsuleAsmLabelNode {
    nothrow @safe @nogc:
    
    string name;
    
    bool isLocal() const {
        return this.name.length && isDigit(this.name[0]);
    }
}

struct CapsuleAsmInstructionNode {
    nothrow @safe @nogc:
    
    alias Instruction = CapsuleInstruction;
    alias Number = CapsuleAsmNumber;
    
    Number immediate;
    ubyte opcode;
    ubyte rd;
    ubyte rs1;
    ubyte rs2;
    
    Instruction getInstruction() const {
        return Instruction(
            cast(Instruction.Opcode) this.opcode,
            cast(Instruction.Register) this.rd,
            cast(Instruction.Register) this.rs1,
            cast(Instruction.Register) this.rs2,
            cast(Instruction.Immediate) this.immediate.value,
        );
    }
    
    uint encode() const {
        return this.getInstruction().encode();
    }
    
    /// Set register by index (rd = 0, rs1 = 1, rs2 = 2)
    void setRegisterByIndex(in uint index, in byte value) {
        switch(index) {
            case 0: this.rd = value; break;
            case 1: this.rs1 = value; break;
            case 2: this.rs2 = value; break;
            default: assert(false, "Invalid register index.");
        }
    }
}

struct CapsuleAsmPadDirectiveNode {
    /// Meaning of the size field varies slightly from one
    /// directive to the next.
    /// .align - Align on a boundary of this many bytes
    /// .padb - Pad using this many bytes
    /// .resb, .resh, .resw - Reserve this many bytes, half words, words
    uint size;
    /// Indicate the fill value to use for the padded space
    /// Not used for reserve directives (.resb, .resh, .resw)
    uint fill;
}

struct CapsuleAsmTextDataDirectiveNode {
    string text;
}

struct CapsuleAsmSymbolDirectiveNode {
    string name;
}

struct CapsuleAsmByteDataDirectiveNode {
    alias Number = CapsuleAsmNumber;
    
    Number[] values;
}

struct CapsuleAsmConstantDirectiveNode {
    string name;
    uint value;
}

struct CapsuleAsmValueDirectiveNode(T) {
    T value;
}
