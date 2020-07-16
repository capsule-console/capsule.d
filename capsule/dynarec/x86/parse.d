module capsule.dynarec.x86.parse;

private:

import capsule.dynarec.x86.encode : X86Encoder;
import capsule.dynarec.x86.instruction : X86Instruction;
import capsule.dynarec.x86.mode : X86Mode;
import capsule.dynarec.x86.opcode : X86Opcode;
import capsule.dynarec.x86.opcodes : X86AllOpcodes;
import capsule.dynarec.x86.opcodes : X86FilterOpcodes, X86FilterAllOpcodes;
import capsule.dynarec.x86.register : X86Register, X86SegmentRegister;
import capsule.dynarec.x86.size : X86DataSize;

private struct StringBuffer {
    import core.stdc.stdlib : malloc, realloc, free;
    
    nothrow @safe @nogc extern(C):
    
    char* buffer = null;
    size_t size = 0;
    size_t length = 0;
    
    @trusted this(in size_t size) {
        this.buffer = cast(char*) malloc(size);
        this.size = size;
    }
    
    @trusted ~this() {
        if(this.buffer !is null) {
            free(this.buffer);
        }
    }
    
    bool empty() const {
        return this.length == 0;
    }
    
    @trusted const(char)[] getChars() const {
        return this.buffer[0 .. this.length];
    }
    
    @trusted void opOpAssign(string op: "~")(in char[] text) {
        if(this.length + text.length > this.size) {
            this.size *= 2;
            this.buffer = cast(char*) realloc(this.buffer, this.size);
        }
        for(size_t i = 0; i < text.length; i++) {
            this.buffer[this.length++] = text[i];
        }
    }
}

public:

struct X86Parser {
    extern(C):
    
    alias DataSize = X86DataSize;
    alias Instruction = X86Instruction;
    alias Mode = X86Mode;
    alias Operand = X86Instruction.Operand;
    
    Mode mode = Mode.None;
    string source = null;
    uint index = 0;
    
    pure nothrow @safe @nogc:
    
    static bool isInteger(in string text) pure {
        return (
            (text.length > 2 && (text[0] == '0' && text[1] == 'x')) ||
            (text.length > 0 && (text[0] >= '0' && text[0] <= '9')) ||
            (text.length > 1 && (text[0] == '-' || text[0] == '+'))
        );
    }
    
    static T parseInteger(T)(in string text) {
        if(text.length > 2 && text[0] == '0' && text[1] == 'x') {
            return typeof(this).parseHexInteger!T(text[2 .. $]);
        }
        else {
            return typeof(this).parseDecimalInteger!T(text);
        }
    }
    
    static T parseDecimalInteger(T)(in string text) {
        if(!text.length) {
            assert(false, "Invalid integer literal.");
        }
        T value = 0;
        const bool isNegative = (text[0] == '-');
        const bool hasSign = (text[0] == '+' || text[0] == '-');
        for(uint i = hasSign ? 1 : 0; i < text.length; i++) {
            const ch = text[i];
            if(ch < '0' || ch > '9') {
                assert(false, "Invalid integer literal.");
            }
            value = cast(T) ((value * 10) + (ch - '0'));
        }
        return cast(T) (isNegative ? -value : value);
    }
    
    static T parseHexInteger(T)(in string text) {
        if(!text.length) {
            assert(false, "Invalid hexadecimal literal.");
        }
        T value;
        for(uint i = 0; i < text.length; i++) {
            const ch = text[i];
            if(ch >= '0' && ch <= '9') {
                value = cast(T) ((value << 4) | (ch - '0'));
            }
            else if(ch >= 'a' && ch <= 'f') {
                value = cast(T) ((value << 4) | (ch - 'a' + 10));
            }
            else if(ch >= 'A' && ch <= 'F') {
                value = cast(T) ((value << 4) | (ch - 'A' + 10));
            }
            else {
                assert(false, "Invalid hexadecimal literal.");
            }
        }
        return value;
    }
    
    static X86Register parseRegister(in string text) {
        static foreach(member; __traits(allMembers, X86Register)) {
            if(text == member) {
                return __traits(getMember, X86Register, member);
            }
        }
        assert(false, "Invalid register name.");
    }
    
    static DataSize parseDataSize(in string text) {
        if(text == "byte") {
            return DataSize.Byte;
        }
        else if(text == "word") {
            return DataSize.Word;
        }
        else if(text == "dword") {
            return DataSize.DWord;
        }
        else if(text == "qword") {
            return DataSize.QWord;
        }
        else {
            return DataSize.None;
        }
    }
    
    bool empty() const {
        return this.index >= this.source.length;
    }
    
    Instruction parseInstruction() {
        uint numOperands = 0;
        Operand[4] operands;
        const name = this.nextToken();
        while(!this.empty) {
            if(numOperands >= operands.length) {
                assert(false, "Too many instruction arguments.");
            }
            operands[numOperands++] = this.nextOperand();
            if(!this.empty && this.nextToken() != ",") {
                assert(false, "Invalid instruction arguments.");
            }
        }
        return X86Instruction(this.mode, name, operands[0 .. numOperands]);
    }
    
    void skipWhitespace() {
        while(this.index < this.source.length &&
            this.source[this.index] == ' '
        ) {
            this.index++;
        }
    }
    
    string nextToken() {
        this.skipWhitespace();
        if(this.index >= this.source.length) {
            return null;
        }
        const token = this.peekNextToken();
        this.index += token.length;
        return token;
    }
    
    string peekNextToken() const {
        static bool isPunctuation(in char ch) {
            return (ch == '[' || ch == ']' || ch == '+' ||
                ch == '*' || ch == ':' || ch == ','
            );
        }
        uint i = this.index;
        while(i < this.source.length && this.source[i] == ' ') {
            i++;
        }
        if(i >= this.source.length) {
            return null;
        }
        const start = i;
        const char ch = this.source[i];
        if(isPunctuation(ch)) {
            return this.source[i .. i + 1];
        }
        while(i < this.source.length &&
            this.source[i] != ' ' && !isPunctuation(this.source[i])
        ) {
            i++;
        }
        return this.source[start .. i];
    }
    
    Operand nextOperand() {
        const token = this.nextToken();
        if(!token.length) {
            return Operand.init;
        }
        else if(token == ".") {
            if(this.nextToken() != "+") {
                assert(false, "Invalid relative address syntax.");
            }
            return Operand.Relative(
                DataSize.None, typeof(this).parseInteger!long(this.nextToken())
            );
        }
        const size = typeof(this).parseDataSize(token);
        if(size !is DataSize.None) {
            return this.nextSizedOperand(size);
        }
        else if(typeof(this).isInteger(token)) {
            const value = typeof(this).parseInteger!long(token);
            return Operand.Immediate(DataSize.None, value);
        }
        static foreach(member; __traits(allMembers, X86Register)) {
            if(token == member) {
                return Operand.Register(
                    __traits(getMember, X86Register, member)
                );
            }
        }
        static foreach(member; __traits(allMembers, X86SegmentRegister)) {
            if(token == member) {
                return Operand.SegmentRegister(
                    __traits(getMember, X86SegmentRegister, member)
                );
            }
        }
        assert(false, "Invalid operand.");
    }
    
    Operand nextSizedOperand(in DataSize size) {
        const token = this.nextToken();
        if(token == "ptr") {
            return this.nextMemoryAddressOperand(size);
        }
        else {
            assert(false, "Invalid pointer syntax.");
        }
    }
    
    Operand nextMemoryAddressOperand(in DataSize size) {
        const first = this.nextToken();
        static foreach(member; __traits(allMembers, X86SegmentRegister)) {
            if(first == member) {
                return this.nextMemoryOffsetOperand(
                    size, __traits(getMember, X86SegmentRegister, member)
                );
            }
        }
        if(first != "[") {
            assert(false, "Invalid memory address operand syntax.");
        }
        uint i = 0;
        bool ipRelative = false;
        int displacement = 0;
        uint scale = 1;
        string register;
        string base;
        string index;
        string token = this.nextToken();
        while(token.length && token != "]" && i++ < 8) {
            if(typeof(this).isInteger(token) && !register.length) {
                displacement = typeof(this).parseInteger!int(token);
                token = this.nextToken();
                break;
            }
            else if(token == "rip") {
                const sign = this.peekNextToken();
                if(sign != "+" && sign != "-") {
                    assert(false, "Invalid memory address operand syntax.");
                }
                ipRelative = true;
                register = null;
            }
            else if(token == "+") {
                if(register.length && !base.length) {
                    base = register;
                }
                else if(!ipRelative && (!index.length || register.length)) {
                    assert(false, "Invalid memory address operand syntax.");
                }
                register = null;
            }
            else if(token == "-") {
                if(register.length && !base.length) {
                    base = register;
                }
                else if(!ipRelative && (!index.length || register.length)) {
                    assert(false, "Invalid memory address operand syntax.");
                }
                displacement = -typeof(this).parseInteger!int(this.nextToken());
                token = this.nextToken();
                register = null;
                break;
            }
            else if(token == "*" && register.length) {
                index = register;
                scale = typeof(this).parseInteger!uint(this.nextToken());
                register = null;
            }
            else if(!register.length) {
                register = token;
            }
            else {
                assert(false, "Invalid memory address operand syntax.");
            }
            token = this.nextToken();
        }
        if(token != "]") {
            assert(false, "Invalid memory address operand syntax.");
        }
        if(register.length) {
            if(!base.length) {
                base = register;
            }
            else if(!index.length) {
                index = register;
            }
            else {
                assert(false, "Invalid memory address operand syntax.");
            }
        }
        if(ipRelative) {
            return Operand.MemoryAddressIPRelative(size, displacement);
        }
        else if(!base.length && !index.length) {
            return Operand.MemoryAddress(size, displacement);
        }
        else if(base.length && !index.length) {
            const baseRegister = typeof(this).parseRegister(base);
            return Operand.MemoryAddress(size, baseRegister, displacement);
        }
        else if(!base.length && index.length) {
            const indexRegister = typeof(this).parseRegister(index);
            return Operand.MemoryAddressIndex(
                size, indexRegister, scale, displacement
            );
        }
        else if(base.length && index.length) {
            const baseRegister = typeof(this).parseRegister(base);
            const indexRegister = typeof(this).parseRegister(index);
            return Operand.MemoryAddress(
                size, baseRegister, indexRegister, scale, displacement
            );
        }
        else {
            assert(false, "Invalid memory address operand syntax.");
        }
    }
    
    Operand nextMemoryOffsetOperand(
        in DataSize size, in X86SegmentRegister segmentRegister
    ) {
        if(this.nextToken() != ":") {
            assert(false, "Invalid seg:offset operand.");
        }
        if(this.nextToken() != "[") {
            assert(false, "Invalid seg:offset operand.");
        }
        const offset = this.nextToken();
        if(this.nextToken() != "]") {
            assert(false, "Invalid seg:offset operand.");
        }
        return Operand.MemoryOffset(
            size, segmentRegister, this.parseInteger!int(offset)
        );
    }
}

private version(unittest) {
    import capsule.io.stdio : stdio;
    import capsule.dynarec.x86.strings : X86InstructionToString;
}

private version(unittest) shared immutable X86ParserCommonTestStrings = [
    "inc bx",
    "inc edx",
    "dec si",
    "dec ebp",
    "push dx",
    "push fs",
    "add al, ch",
    "xchg bh, bl",
    "xor ah, dh",
    "add al, 0x10",
    "sub ax, 0x1234",
    "adc ecx, 0xabcdabcd",
    "sal ch, 0x0f",
    "sar bx, 0x03",
    "shl ecx, 1",
    "shr ebx, cl",
    "mov eax, dword ptr [ebp]",
    "mov dword ptr [ebp + esi], eax",
    "and ebx, dword ptr [ecx * 4]",
    "imul eax, dword ptr [ebx], 0x9f", // TODO: picks the wrong imul?
    "push 0x20",
    "push 0x40302010",
    "jmp . + 0x20",
    "jmp . + 0x12340404",
    "call . + 0x34561234",
];

private version(unittest) shared immutable X86ParserLegacyTestStrings = [
    "pusha",
    "pushad",
    "push cs",
    "push esi",
    "call di",
    "call eax",
    "jmp . + 0x2080",
    "call . + 0x3456",
];

private version(unittest) shared immutable X86ParserLongTestStrings = [
    "push rdi",
    "inc rdx",
    "dec r8",
    "call rcx",
    "add al, r10b",
    "add eax, r9d",
    "xchg ecx, r14d",
    "mov rax, r8",
    "sar r9, 0x0a",
    "mov r10, 0x0fedcba9",
    "mov rbp, 0x123456789abcdef0",
    "add dx, word ptr [rax + rcx * 8]",
    "mov qword ptr [ebp + esi], rax",
    "xor rbx, qword ptr [ecx * 4]",
    "cmp byte ptr [rbx * 2 + 0x6677aabb], r10b",
    "sbb ax, word ptr [rcx + rax * 4 + 0x20406080]",
    "or eax, dword ptr [rsi - 0x00004000]",
    "neg dword ptr [rip + 0x56781234]",
    "neg dword ptr [rip - 0x01020304]",
];

unittest {
    static void test(in X86Mode mode, in string testString, in bool expectValid) {
        assert(mode is X86Mode.Legacy || mode is X86Mode.Long);
        const string modeName = (mode is X86Mode.Long ? "Long" : "Legacy");
        const instruction = X86Parser(mode, testString).parseInstruction();
        if(!instruction.ok) {
            if(expectValid) {
                assert(0, modeName ~ " mode parse failure: " ~ testString);
            }
            return;
        }
        const outString = X86InstructionToString(instruction);
        const match = (outString == testString);
        if(expectValid && !match) assert(0,
            modeName ~ " mode round-trip failure:\n" ~
            "Expected: " ~ testString ~ "\n" ~
            "Actual:   " ~ outString ~ "\n"
        );
        else if(!expectValid && match) assert(0,
            modeName ~ " unexpected mode round-trip success:\n" ~
            "Expected: " ~ testString ~ "\n" ~
            "Actual:   " ~ outString ~ "\n"
        );
    }
    foreach(testString; X86ParserCommonTestStrings) {
        stdio.writeln("Attempting common: " ~ testString);
        test(X86Mode.Legacy, testString, true);
        test(X86Mode.Long, testString, true);
    }
    foreach(testString; X86ParserLegacyTestStrings) {
        stdio.writeln("Attempting legacy: " ~ testString);
        test(X86Mode.Legacy, testString, true);
        test(X86Mode.Long, testString, false);
    }
    foreach(testString; X86ParserLongTestStrings) {
        stdio.writeln("Attempting long:   " ~ testString);
        test(X86Mode.Long, testString, true);
        test(X86Mode.Legacy, testString, false);
    }
}
