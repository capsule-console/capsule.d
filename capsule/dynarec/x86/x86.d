module capsule.dynarec.x86.x86;

private:

import capsule.dynarec.x86.encode : X86Encoder;
import capsule.dynarec.x86.instruction : X86Instruction;
import capsule.dynarec.x86.mode : X86Mode;
import capsule.dynarec.x86.opcode : X86Opcode;
import capsule.dynarec.x86.opcodes : X86AllOpcodes;
import capsule.dynarec.x86.opcodes : X86FilterOpcodes, X86FilterAllOpcodes;
import capsule.dynarec.x86.parse : X86Parser;
import capsule.dynarec.x86.register : X86Register, X86SegmentRegister;
import capsule.dynarec.x86.size : X86DataSize;
import capsule.dynarec.x86.strings : X86ToString;

public:

struct X86 {
    alias AllOpcodes = X86AllOpcodes;
    alias DataSize = X86DataSize;
    alias Encoder = X86Encoder;
    alias Instruction = X86Instruction;
    alias Mode = X86Mode;
    alias Opcode = X86Opcode;
    alias Operand = X86Instruction.Operand;
    alias OperandType = X86Opcode.OperandType;
    alias Register = X86Register;
    alias SegmentRegister = X86SegmentRegister;
    
    static foreach(member; __traits(allMembers, X86Register)) {
        mixin(`alias ` ~ member ~ ` = X86Register.` ~ member ~ `;`);
    }
    
    static foreach(member; __traits(allMembers, X86SegmentRegister)) {
        mixin(`alias ` ~ member ~ ` = X86SegmentRegister.` ~ member ~ `;`);
    }
    
    pure nothrow @safe:
    
    /// Get a string representation of some X86 data type, for example
    /// a register or an opcode or an instruction.
    alias toString = X86ToString;
    
    pure nothrow @safe @nogc:
    
    static Operand imm(in long value) {
        return Operand.Immediate(Operand.Size.None, value);
    }
    
    static Operand imm8(in long value) {
        return Operand.Immediate(Operand.Size.Byte, value);
    }
    
    static Operand imm16(in long value) {
        return Operand.Immediate(Operand.Size.Word, value);
    }
    
    static Operand imm32(in long value) {
        return Operand.Immediate(Operand.Size.DWord, value);
    }
    
    static Operand imm64(in long value) {
        return Operand.Immediate(Operand.Size.QWord, value);
    }
    
    static Operand rel8(in long value) {
        return Operand.Relative(Operand.Size.Byte, value);
    }
    
    static Operand rel16(in long value) {
        return Operand.Relative(Operand.Size.Word, value);
    }
    
    static Operand rel32(in long value) {
        return Operand.Relative(Operand.Size.DWord, value);
    }
    
    static Operand rel64(in long value) {
        return Operand.Relative(Operand.Size.QWord, value);
    }
    
    static Operand moffs8(in SegmentRegister segmentRegister, in int offset) {
        return Operand.MemoryOffset(Operand.Size.Byte, segmentRegister, offset);
    }
    
    static Operand moffs16(in SegmentRegister segmentRegister, in int offset) {
        return Operand.MemoryOffset(Operand.Size.Word, segmentRegister, offset);
    }
    
    static Operand moffs32(in SegmentRegister segmentRegister, in int offset) {
        return Operand.MemoryOffset(Operand.Size.DWord, segmentRegister, offset);
    }
    
    static Operand moffs64(in SegmentRegister segmentRegister, in int offset) {
        return Operand.MemoryOffset(Operand.Size.QWord, segmentRegister, offset);
    }
    
    /// IP-relative byte pointer
    static Operand mem8iprel(in int displacement) {
        return Operand.MemoryAddressIPRelative(Operand.Size.Byte, displacement);
    }
    
    /// IP-relative word pointer
    static Operand mem16iprel(in int displacement) {
        return Operand.MemoryAddressIPRelative(Operand.Size.Word, displacement);
    }
    
    /// IP-relative dword pointer
    static Operand mem32iprel(in int displacement) {
        return Operand.MemoryAddressIPRelative(Operand.Size.DWord, displacement);
    }
    
    /// IP-relative qword pointer
    static Operand mem64iprel(in int displacement) {
        return Operand.MemoryAddressIPRelative(Operand.Size.QWord, displacement);
    }
    
    /// Absolute pointer to byte
    static Operand mem8(in int displacement) {
        return Operand.MemoryAddress(Operand.Size.Byte, displacement);
    }
    
    /// Absolute pointer to word
    static Operand mem16(in int displacement) {
        return Operand.MemoryAddress(Operand.Size.Word, displacement);
    }
    
    /// Absolute pointer to dword
    static Operand mem32(in int displacement) {
        return Operand.MemoryAddress(Operand.Size.DWord, displacement);
    }
    
    /// Absolute pointer to qword
    static Operand mem64(in int displacement) {
        return Operand.MemoryAddress(Operand.Size.QWord, displacement);
    }
    
    /// Add base register + displacement to get byte pointer
    static Operand mem8(in Register base, in int displacement = 0) {
        return Operand.MemoryAddress(Operand.Size.Byte, base, displacement);
    }
    
    /// Add base register + displacement to get word pointer
    static Operand mem16(in Register base, in int displacement = 0) {
        return Operand.MemoryAddress(Operand.Size.Word, base, displacement);
    }
    
    /// Add base register + displacement to get dword pointer
    static Operand mem32(in Register base, in int displacement = 0) {
        return Operand.MemoryAddress(Operand.Size.DWord, base, displacement);
    }
    
    /// Add base register + displacement to get qword pointer
    static Operand mem64(in Register base, in int displacement = 0) {
        return Operand.MemoryAddress(Operand.Size.QWord, base, displacement);
    }
    
    /// Add index register * scale + displacement to get byte pointer
    static Operand mem8idx(
        in Register index, in uint scale, in int displacement = 0
    ) {
        return Operand.MemoryAddressIndex(
            Operand.Size.Byte, index, scale, displacement
        );
    }
    
    /// Add index register * scale + displacement to get word pointer
    static Operand mem16idx(
        in Register index, in uint scale, in int displacement = 0
    ) {
        return Operand.MemoryAddressIndex(
            Operand.Size.Word, index, scale, displacement
        );
    }
    
    /// Add index register * scale + displacement to get dword pointer
    static Operand mem32idx(
        in Register index, in uint scale, in int displacement = 0
    ) {
        return Operand.MemoryAddressIndex(
            Operand.Size.DWord, index, scale, displacement
        );
    }
    
    /// Add index register * scale + displacement to get qword pointer
    static Operand mem64idx(
        in Register index, in uint scale, in int displacement = 0
    ) {
        return Operand.MemoryAddressIndex(
            Operand.Size.QWord, index, scale, displacement
        );
    }
    
    /// Add base + index * scale + displacement to get byte pointer
    static Operand mem8(
        in Register base, in Register index,
        in uint scale, in int displacement = 0
    ) {
        return Operand.MemoryAddress(
            Operand.Size.Byte, base, index, scale, displacement
        );
    }
    
    /// Add base + index * scale + displacement to get word pointer
    static Operand mem16(
        in Register base, in Register index,
        in uint scale, in int displacement = 0
    ) {
        return Operand.MemoryAddress(
            Operand.Size.Word, base, index, scale, displacement
        );
    }
    
    /// Add base + index * scale + displacement to get dword pointer
    static Operand mem32(
        in Register base, in Register index,
        in uint scale, in int displacement = 0
    ) {
        return Operand.MemoryAddress(
            Operand.Size.DWord, base, index, scale, displacement
        );
    }
    
    /// Add base + index * scale + displacement to get qword pointer
    static Operand mem64(
        in Register base, in Register index,
        in uint scale, in int displacement = 0
    ) {
        return Operand.MemoryAddress(
            Operand.Size.QWord, base, index, scale, displacement
        );
    }
    
    static foreach(i, opcode; X86AllOpcodes) {
        static if(i == 0 ||
            X86AllOpcodes[i > 0 ? i - 1 : 0].name != X86AllOpcodes[i].name
        ) {
            mixin(`
                static auto ` ~ opcode.name ~ `(T...)(in Mode mode, in T operands) {
                    return Instruction.OpcodeTemplate!(opcode.name)(mode, operands);
                }
            `);
        }
    }
        
    struct Legacy {
        static opDispatch(property: string, T...)(auto ref T args) {
            mixin(`return X86.` ~ property ~ `(X86Mode.Legacy, ` ~ args ~ `);`);
        }
    }
    
    struct Long {
        static opDispatch(property: string, T...)(auto ref T args) {
            mixin(`return X86.` ~ property ~ `(X86Mode.Long, ` ~ args ~ `);`);
        }
    }
}

version(unittest) {
    import capsule.io.stdio : stdio;
    import capsule.string.hex : getHexString;
    //void test(in string assembly, in string expected) {
        
    //}
}

unittest {
    //for(uint i = 0; i < X86AllOpcodes.length; i += 16) {
    //  stdio.writeln(X86OpcodeToString(X86AllOpcodes[i]));
    //}
    
    //stdio.writeln(X86.toString(
    //    X86Instruction.Operand.Register(X86Register.ecx)
    //));
    
    //stdio.writeln(X86.toString(
    //    X86.add(X86.eax, X86.edx)
    //));
    //stdio.writeln(X86.toString(
    //    X86.mov(X86.ax, X86.imm16(0x4321))
    //));
    
    //X86.mov(X86.eax, X86.ecx)
    const instruction = X86Parser("mov eax, ecx").parseInstruction();
    stdio.writeln(X86.toString(instruction));
    
    /*
    ubyte[16] buffer;
    auto encoder = X86.Encoder(X86.Mode.Long, buffer);
    // mov ax, 0x4321 [0x66, 0xb8, 0x21, 0x43]
    const status = encoder.pushInstruction(
        X86.mov(X86.ax, X86.imm16(0x4321))
    );
    if(status) {
        stdio.writeln("Encoding error");
    }
    else {
        stdio.writeln(getHexString(buffer[0 .. encoder.length]));
    }
    */
}

//pragma(msg, "Instruction: ", X86.Instruction.sizeof);
//pragma(msg, "Instruction.Status: ", X86.Instruction.Status.sizeof);
//pragma(msg, "Instruction.SegmentOverridePrefix: ", X86.Instruction.SegmentOverridePrefix.sizeof);
//pragma(msg, "Instruction.Opcode: ", X86.Instruction.Opcode.sizeof);
//pragma(msg, "Instruction.Operand: ", X86.Instruction.Operand.sizeof);
//pragma(msg, "Instruction.Operand.MemoryAddressData: ", X86.Instruction.Operand.MemoryAddressData.sizeof);


