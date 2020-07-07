/**

This module provides functionality for parsing Capsule assembly
source code and producing a list of syntax nodes.

*/

module capsule.casm.parse;

private:

import capsule.io.file : File, FileLocation, FileReader;
import capsule.meta.enums : isNamedEnumMember, getEnumMemberWithAttribute;
import capsule.range.range : toArray;
import capsule.string.ascii : isDigit, eitherCaseStringEquals;
import capsule.string.ascii : isWhitespace, isInlineWhitespace;
import capsule.string.escape : unescapeCapsuleText;
import capsule.string.hex : isHexDigit, getHexDigitValue, parseHexString;

import capsule.core.obj : CapsuleObject;
import capsule.core.typestrings : CapsuleRegisterNames;
import capsule.core.typestrings : getCapsuleRegisterIndex;
import capsule.core.types : CapsuleOpcode;

import capsule.casm.instructionargs : CapsuleInstructionArgs;
import capsule.casm.messages : CapsuleAsmMessageStatus, CapsuleAsmMessageMixin;
import capsule.casm.messages : CapsuleAsmMessageStatusSeverity;
import capsule.casm.syntax : CapsuleAsmNode;

public:

bool isCapsuleAsmIdentifierCharacter(in char ch) {
    return ch == '_' || ch == '.' || (
        (ch >= '0' && ch <= '9') ||
        (ch >= 'a' && ch <= 'z') ||
        (ch >= 'A' && ch <= 'Z')
    );
}

struct CapsuleAsmParseResult(T) {
    alias Status = CapsuleAsmMessageStatus;
    
    Status status = Status.Ok;
    FileLocation location;
    string context = null;
    T value;
    
    static typeof(this) Ok(in FileLocation location, T value) {
        return typeof(this)(Status.Ok, location, null, value);
    }
    
    static typeof(this) Error(
        in FileLocation location, in Status status, in string context = null
    ) {
        return typeof(this)(status, location, context);
    }
    
    static typeof(this) Error(X)(in CapsuleAsmParseResult!X result) {
        return typeof(this)(result.status, result.location, result.context);
    }
    
    bool ok() const {
        return this.status is Status.Ok;
    }
}

struct CapsuleAsmParser {
    mixin CapsuleAsmMessageMixin;
    
    alias DirectiveType = CapsuleAsmNode.DirectiveType;
    alias InstructionArgs = CapsuleInstructionArgs;
    alias LocalType = CapsuleObject.Reference.LocalType;
    alias Node = CapsuleAsmNode;
    alias PseudoInstructionType = CapsuleAsmNode.PseudoInstructionType;
    alias ReferenceType = CapsuleObject.Reference.Type;
    
    FileReader reader;
    CapsuleAsmNode[] nodes;
    bool fatalSyntaxError = false;
    
    this(Log* log, File file) {
        this(log, file.reader);
    }
    
    this(Log* log, FileReader reader) {
        assert(log);
        this.log = log;
        this.reader = reader;
    }
    
    static int parseInstructionName(in string name) {
        foreach(member; __traits(allMembers, CapsuleOpcode)) {
            enum opcode = __traits(getMember, CapsuleOpcode, member);
            const memberName = getEnumMemberAttribute!string(opcode);
            if(eitherCaseStringEquals(name, memberName)) {
                return cast(int) opcode;
            }
        }
        return -1;
    }
    
    void addResultStatus(T)(in CapsuleAsmParseResult!T result) {
        if(!result.ok) {
            this.addStatus(result.location, result.status, result.context);
        }
    }
    
    void addFatalSyntaxError(in FileLocation location, in Status status, in string context = null) {
        this.addStatus(location, Log.Severity.Error, status, context);
        this.fatalSyntaxError = true;
    }
    
    void addResultStatusSkipLine(T)(in CapsuleAsmParseResult!T result) {
        this.addResultStatus(result);
        this.skipToNextLine();
    }
    
    void addStatusSkipLine(in FileLocation location, in Status status, in string context = null) {
        this.addStatus(location, status, context);
        this.skipToNextLine();
    }
    
    FileLocation endLocation(in FileLocation location) {
        return location.end(this.reader.location);
    }
    
    void addNode(in Node node) {
        if(node.type !is Node.Type.None) {
            this.nodes ~= node;
        }
    }
    
    typeof(this) parse() {
        this.addStatus(this.reader.location, Status.ParseStart);
        while(!this.fatalSyntaxError && !this.reader.empty) {
            this.parseNext();
        }
        this.addStatus(this.reader.location, Status.ParseEnd);
        return this;
    }
    
    void parseNext() {
        assert(!this.reader.empty);
        assert(!this.fatalSyntaxError);
        const location = this.reader.location;
        // Comment
        if(this.reader.front == ';') {
            this.parseComment();
            return;
        }
        // Directive
        if(this.reader.front == '.') {
            this.addNode(this.parseDirective(location));
            return;
        }
        // Whitespace
        if(isWhitespace(this.reader.front)) {
            this.parseWhitespace();
            return;
        }
        // Either an instruction or a label (depends on if followed by ':')
        const identifier = this.parseIdentifier();
        if(!identifier.ok || !identifier.value.length) {
            this.addFatalSyntaxError(
                this.endLocation(location), Status.InvalidSyntax
            );
        }
        // Label
        else if(!this.reader.empty && this.reader.front == ':') {
            this.addNode(this.parseLabel(location, identifier.value));
            return;
        }
        // Instruction
        else {
            this.addNode(this.parseInstruction(location, identifier.value));
            return;
        }
    }
    
    void skipToNextLine() {
        this.addStatus(this.reader.location, Status.ParseSkipToNextLine);
        while(!this.reader.empty) {
            this.reader.popFront();
            if(!this.reader.empty && this.reader.front == '\n') {
                this.reader.popFront();
                break;
            }
        }
    }
    
    Node parseLabel(in FileLocation location, in string name) {
        assert(!this.reader.empty);
        assert(this.reader.front == ':');
        assert(name && name.length);
        auto node = Node(location, Node.Type.Label);
        node.label.name = name;
        this.reader.popFront();
        this.endLocation(node.location);
        this.addStatus(location, Status.ParseLabelDefinition, name);
        return node;
    }
    
    /// Parse an instruction or pseudo-instruction
    Node parseInstruction(in FileLocation location, in string opName) {
        if(opName == "op" || opName == "OP") {
            return this.parseHexInstruction();
        }
        Node node;
        const opcode = typeof(this).parseInstructionName(opName);
        if(opcode < 0) {
            const pseudoType = Node.getPseudoInstructionTypeWithName(opName);
            if(pseudoType is PseudoInstructionType.None) {
                this.addStatusSkipLine(
                    this.endLocation(location),
                    Status.InvalidInstructionName,
                    opName
                );
                return Node.init;
            }
            node = Node(location, pseudoType);
        }
        else {
            assert(opcode >= 0 && opcode <= 0x7f);
            node = Node(location, Node.Type.Instruction);
            node.instruction.opcode = cast(ubyte) opcode;
        }
        const expectArgs = node.instructionArgs;
        if(expectArgs) {
            return this.parseInstructionArgs(node);
        }
        else {
            node.location = this.endLocation(node.location);
            return node;
        }
    }
    
    
    /// Parse an instruction which is indicated with a hexadecimal
    /// opcode number, e.g. "[0x01]".
    Node parseHexInstruction() {
        const FileLocation location = this.reader.location;
        // Instruction should start with "[0x" or "[0X"
        assert(!this.reader.empty && this.reader.front == '[');
        if(this.reader.empty || this.reader.front != '[') {
            this.addFatalSyntaxError(location, Status.InvalidSyntax);
            return Node.init;
        }
        this.reader.popFront();
        if(this.reader.empty || this.reader.front != '0') {
            this.addStatusSkipLine(location, Status.InvalidSyntax);
            return Node.init;
        }
        this.reader.popFront();
        if(this.reader.empty || (
            this.reader.front != 'x' && this.reader.front != 'X'
        )) {
            this.addStatusSkipLine(location, Status.InvalidSyntax);
            return Node.init;
        }
        this.reader.popFront();
        // Parse the hex opcode value
        const hexValue = this.parseHexLiteral();
        if(!hexValue.ok) {
            this.addResultStatusSkipLine(hexValue);
            return Node.init;
        }
        // Emit a message if the opcode number isn't valid
        if(hexValue.value > 0x7f) {
            this.addStatus(
                this.endLocation(location), Status.InvalidInstructionOpcode
            );
        }
        // Emit a different message if this is an unknown opcode number
        else if(!isNamedEnumMember(cast(CapsuleOpcode) hexValue.value)) {
            this.addStatus(
                this.endLocation(location), Status.UnknownInstructionOpcode
            );
        }
        // Parse the argument list
        auto node = Node(location, Node.Type.Instruction);
        node.instruction.opcode = cast(ubyte) hexValue.value;
        return this.parseInstructionArgs(node);
    }
    
    /// Parse arguments for an instruction or pseudo-instruction.
    Node parseInstructionArgs(ref Node node) {
        assert(node.isInstruction || node.isPseudoInstruction);
        const inlineOk = this.parseInlineWhitespace();
        if(!inlineOk) {
            return node;
        }
        // If the next non-inline-whitespace character after the instruction
        // is either a newline or special punctuation, then this indicates
        // that the instruction hasn't got any arguments.
        const ch = this.reader.empty ? '\n' : this.reader.front;
        const noArgs = (ch == '\n' || ch == ';' || ch == '.' || ch == ':');
        // Parse the instruction argument list
        uint numRegisters = 0;
        bool hasImmediate = false;
        const expectArgs = node.instructionArgs;
        if(!noArgs) do {
            // Try to parse the next instruction argument
            auto arg = this.parseInstructionArg(expectArgs.defaultReferenceType);
            // Failure parsing the argument
            if(!arg.ok) {
                this.addResultStatusSkipLine(arg);
                return node;
            }
            // This shouldn't happen
            else if(arg.value.register >= 8) {
                this.addFatalSyntaxError(arg.location, Status.InstructionWrongArgs);
                return node;
            }
            // Argument was a register
            else if(arg.value.register >= 0) {
                assert(arg.value.register < 8);
                const regIndex = expectArgs.getParamByArgIndex(numRegisters);
                if(regIndex is InstructionArgs.RegisterParameter.None) {
                    this.addStatusSkipLine(
                        arg.location, Status.InstructionArgsTooManyRegisters, node.getName()
                    );
                    return node;
                }
                assert(numRegisters < 3);
                assert(regIndex >= 0 && regIndex < 3);
                const regValue = cast(ubyte) arg.value.register;
                node.instruction.setRegisterByIndex(regIndex, regValue);
                numRegisters++;
                
            }
            // Argument was an immediate value
            else {
                node.instruction.immediate = arg.value.immediate;
                hasImmediate = true;
                break;
            }
        } while(this.parseArgSeparator());
        // Check if arguments were in line with expectations
        VerifyArgs:
        if(hasImmediate && expectArgs.immediate is InstructionArgs.Immediate.Never) {
            this.addStatus(node.location, Status.InstructionArgsUnexpectedImmediate, node.getName());
        }
        if(!hasImmediate && expectArgs.immediate is InstructionArgs.Immediate.Always) {
            this.addStatus(node.location, Status.InstructionArgsMissingImmediate, node.getName());
        }
        if(numRegisters < expectArgs.registerParamCount) {
            this.addStatus(node.location, Status.InstructionArgsTooFewRegisters, node.getName());
        }
        // All done
        node.location = this.endLocation(node.location);
        return node;
    }
    
    /// Helper for parsing an instruction argument.
    /// Expects to find either a register or an immediate.
    auto parseInstructionArg(in ReferenceType defaultReferenceType) {
        // Define some helpful types
        struct InstructionArg {
            Node.Number immediate;
            byte register = -1;
        }
        alias Result = CapsuleAsmParseResult!InstructionArg;
        // Try to parse the argument
        const location = this.reader.location;
        auto argument = this.parseNumber(defaultReferenceType);
        const name = argument.value.name;
        // Failure parsing the argument
        if(!argument.ok) {
            return Result.Error(argument);
        }
        // Argument is a register name (Z, A, B, C, R, S, X, Y)
        else if(name.length == 1) {
            const register = cast(byte) getCapsuleRegisterIndex(name[0]);
            if(register >= 0 && register < 8) {
                const arg = InstructionArg(Node.Number.init, register);
                return Result.Ok(argument.location, arg);
            }
        }
        // Argument is a register number (r0, r1, r2, r3, r4, r5, r6, r7)
        else if(name.length == 2 &&
            (name[0] == 'r' || name[1] == 'R') &&
            (name[2] >= '0' && name[2] <= '7')
        ) {
            const arg = InstructionArg(Node.Number.init, cast(byte) (name[2] - '0'));
            return Result.Ok(argument.location, arg);
        }
        // Argument is an immediate value
        return Result.Ok(argument.location, InstructionArg(argument.value));
    }
    
    Node parseDirective(in FileLocation location) {
        assert(this.reader.front == '.');
        this.reader.popFront();
        const name = this.parseIdentifier();
        const inlineOk = this.parseInlineWhitespace();
        if(!inlineOk) {
            return Node.init;
        }
        this.addStatus(
            this.endLocation(location), Status.ParseDirective, name.value
        );
        const type = Node.getDirectiveTypeWithName(name.value);
        // .align [offset], [fill]
        if(type is DirectiveType.Align) {
            return this.parsePaddingDirective(location, type);
        }
        // .bss
        else if(type is DirectiveType.BSS) {
            return Node(location, type);
        }
        // .byte [values...]
        else if(type is DirectiveType.Byte) {
            return this.parseByteDataDirective(location, type, ReferenceType.AbsoluteByte);
        }
        // .comment [text]
        else if(type is DirectiveType.Comment) {
            return this.parseTextDataDirective(location, type);
        }
        // .const [symbol], [value]
        else if(type is DirectiveType.Constant) {
            return this.parseConstantDirective(location);
        }
        // .data
        else if(type is DirectiveType.Data) {
            return Node(location, type);
        }
        // .endproc [symbol]
        else if(type is DirectiveType.EndProcedure) {
            return this.parseSymbolDirective(location, type);
        }
        // .entry
        else if(type is DirectiveType.Entry) {
            return Node(location, type);
        }
        // .export [symbol]
        else if(type is DirectiveType.Export) {
            return this.parseSymbolDirective(location, type);
        }
        // .extern [symbol]
        else if(type is DirectiveType.Extern) {
            return this.parseSymbolDirective(location, type);
        }
        // .half [values...]
        else if(type is DirectiveType.HalfWord) {
            return this.parseByteDataDirective(location, type, ReferenceType.AbsoluteHalfWord);
        }
        // .incbin [path]
        else if(type is DirectiveType.IncludeBinary) {
            return this.parseTextDataDirective(location, type);
        }
        // .include [path]
        else if(type is DirectiveType.IncludeSource) {
            return this.parseTextDataDirective(location, type);
        }
        // .padb [length], [fill]
        else if(type is DirectiveType.PadBytes) {
            return this.parsePaddingDirective(location, type);
        }
        // .padh [length], [fill]
        else if(type is DirectiveType.PadHalfWords) {
            return this.parsePaddingDirective(location, type);
        }
        // .padw [length], [fill]
        else if(type is DirectiveType.PadWords) {
            return this.parsePaddingDirective(location, type);
        }
        // .priority [priority]
        else if(type is DirectiveType.Priority) {
            return this.parseIntDirective(location, type);
        }
        // .procedure
        else if(type is DirectiveType.Procedure) {
            return Node(location, type);
        }
        // .resb [count]
        else if(type is DirectiveType.ReserveBytes) {
            return this.parseReserveDirective(location, type);
        }
        // .resh [count]
        else if(type is DirectiveType.ReserveHalfWords) {
            return this.parseReserveDirective(location, type);
        }
        // .resw [count]
        else if(type is DirectiveType.ReserveWords) {
            return this.parseReserveDirective(location, type);
        }
        // .rodata
        else if(type is DirectiveType.ReadOnlyData) {
            return Node(location, type);
        }
        // .string [text]
        else if(type is DirectiveType.String) {
            return this.parseTextDataDirective(location, type);
        }
        // stringz [text]
        else if(type is DirectiveType.StringZ) {
            return this.parseTextDataDirective(location, type);
        }
        // .text
        else if(type is DirectiveType.Text) {
            return Node(location, type);
        }
        // .word [values...]
        else if(type is DirectiveType.Word) {
            return this.parseByteDataDirective(location, type, ReferenceType.AbsoluteWord);
        }
        // Unknown directive
        else {
            this.addStatusSkipLine(
                this.endLocation(location), Status.InvalidDirective, name.value
            );
            return Node.init;
        }
    }
    
    auto parsePaddingDirective(in FileLocation location, in DirectiveType type) {
        auto node = Node(location, type);
        const size = this.parseNumberLiteral();
        const sep = this.parseArgSeparator();
        const fill = this.parseNumberLiteral();
        node.padDirective.size = size.value;
        node.padDirective.fill = fill.value;
        if(!size.ok || !sep || !fill.ok) this.addStatusSkipLine(
            this.endLocation(location), Status.DirectiveWrongArgs, node.getName()
        );
        node.location = this.endLocation(node.location);
        return node;
    }
    
    auto parseReserveDirective(in FileLocation location, in DirectiveType type) {
        auto node = Node(location, type);
        const size = this.parseNumberLiteral();
        node.padDirective.size = size.value;
        node.padDirective.fill = 0;
        if(!size.ok) this.addStatusSkipLine(
            this.endLocation(location), Status.DirectiveWrongArgs, node.getName()
        );
        node.location = this.endLocation(node.location);
        return node;
    }
    
    auto parseIntDirective(in FileLocation location, in DirectiveType type) {
        auto node = Node(location, type);
        const value = this.parseNumberLiteral();
        node.intDirective.value = cast(int) value.value;
        if(!value.ok) this.addStatusSkipLine(
            this.endLocation(location), Status.DirectiveWrongArgs, node.getName()
        );
        node.location = this.endLocation(node.location);
        return node;
    }
    
    auto parseConstantDirective(in FileLocation location) {
        auto node = Node(location, Node.DirectiveType.Constant);
        const name = this.parseIdentifier();
        const sep = this.parseArgSeparator();
        const value = this.parseNumberLiteral();
        node.constDirective.name = name.value;
        node.constDirective.value = value.value;
        if(!name.ok || !name.value.length || !sep || !value.ok) {
            this.addStatusSkipLine(
                this.endLocation(location), Status.DirectiveWrongArgs, node.getName()
            );
            return node;
        }
        else if(name.value[0] == '.' || isDigit(name.value[0])) {
            this.addStatusSkipLine(
                this.endLocation(location), Status.InvalidIdentifier, name.value
            );
            return node;
        }
        node.location = this.endLocation(node.location);
        return node;
    }
    
    auto parseByteDataDirective(
        in FileLocation location, in DirectiveType type,
        in ReferenceType defaultReferenceType
    ) {
        auto node = Node(location, type);
        auto values = this.parseNumberList(defaultReferenceType);
        node.byteDataDirective.values = values.value;
        if(!values.ok || !values.value.length) this.addStatusSkipLine(
            this.endLocation(location), Status.DirectiveWrongArgs, node.getName()
        );
        node.location = this.endLocation(node.location);
        return node;
    }
    
    auto parseTextDataDirective(in FileLocation location, in DirectiveType type) {
        auto node = Node(location, type);
        if(this.reader.front != '"') {
            this.addStatusSkipLine(
                this.endLocation(location), Status.DirectiveWrongArgs, node.getName()
            );
            return node;
        }
        const text = this.parseStringLiteral();
        node.textDirective.value = text.value;
        if(!text.ok) {
            this.addStatusSkipLine(this.endLocation(location), text.status);
        }
        node.location = this.endLocation(node.location);
        return node;
    }
    
    auto parseSymbolDirective(in FileLocation location, in DirectiveType type) {
        auto node = Node(location, type);
        const name = this.parseIdentifier();
        node.symbolDirective.name = name.value;
        if(!name.ok || !name.value.length) {
            this.addStatusSkipLine(
                this.endLocation(location), Status.DirectiveWrongArgs, node.getName()
            );
        }
        else if(name.value[0] == '.' || isDigit(name.value[0])) {
            this.addStatusSkipLine(
                this.endLocation(location), Status.InvalidIdentifier, name.value
            );
            return node;
        }
        node.location = this.endLocation(node.location);
        return node;
    }
    
    void parseWhitespace() {
        while(!this.reader.empty && isWhitespace(this.reader.front)) {
            this.reader.popFront();
        }
    }
    
    bool parseInlineWhitespace() {
        this.parseInlineWhitespaceStrict();
        if(!this.reader.empty && this.reader.front == '\\') {
            return this.parseLineContinuation();
        }
        else {
            return true;
        }
    }
    
    /// Differentiated from parseInlineWhitespace in that this function
    /// does not permit line continuations (backslash '\').
    void parseInlineWhitespaceStrict() {
        while(!this.reader.empty && isInlineWhitespace(this.reader.front)) {
            this.reader.popFront();
        }
    }
    
    bool parseArgSeparator() {
        this.parseInlineWhitespace();
        if(!this.reader.empty && this.reader.front == ',') {
            this.reader.popFront();
            return this.parseInlineWhitespace();
        }
        return false;
    }
    
    /// Move the file reader to the character after the end of a comment.
    /// Expects the current position of the file reader to be over a
    /// semicolon ';', i.e. at the beginning of a comment.
    void parseComment() {
        assert(!this.reader.empty && this.reader.front == ';');
        this.reader.popFront();
        while(!this.reader.empty && this.reader.front != '\n') {
            this.reader.popFront();
        }
        if(!this.reader.empty) {
            this.reader.popFront();
        }
    }
    
    /// Consume a line continuation. Expects the immediate next character
    /// in the source to be a backslash '\', i.e. the line continuation
    /// character.
    /// Returns true if the line continuation could be successfully consumed,
    /// or false if there was invalid syntax.
    bool parseLineContinuation() {
        // Line continuations are indicated by a backslash '\'
        assert(this.reader.front == '\\');
        const location = this.reader.location;
        this.reader.popFront();
        // Only whitespace or comments are allowed following the backslash
        this.parseInlineWhitespaceStrict();
        if(this.reader.empty || (
            this.reader.front != '\n' && this.reader.front != ';'
        )) {
            this.addStatusSkipLine(
                this.endLocation(location),
                Status.InvalidLineContinuationSyntax
            );
            return false;
        }
        // Consume whitespace or comments after the backslash
        assert(!this.reader.empty);
        if(this.reader.front == '\n') {
            this.reader.popFront();
        }
        else {
            assert(this.reader.front == ';');
            this.parseComment();
        }
        // Consume inline whitespace and make sure this isn't EOF
        this.parseInlineWhitespaceStrict();
        if(this.reader.empty) {
            this.addStatus(
                this.endLocation(location),
                Status.InvalidLineContinuationSyntax
            );
            return false;
        }
        // All done
        return true;
    }
    
    auto parseIdentifier() {
        alias Result = CapsuleAsmParseResult!string;
        const location = this.reader.location;
        while(!this.reader.empty && isCapsuleAsmIdentifierCharacter(this.reader.front)) {
            this.reader.popFront();
        }
        const endIndex = this.reader.index;
        const name = this.reader.content[location.startIndex .. endIndex];
        return Result.Ok(this.endLocation(location), name);
    }
    
    /// Assuming the reader is positioned at the beginning of a string
    /// literal (starting with a double quote '"') parse the given string.
    auto parseStringLiteral() {
        alias Result = CapsuleAsmParseResult!string;
        const location = this.reader.location;
        assert(!this.reader.empty && this.reader.front == '"');
        this.reader.popFront();
        const startIndex = this.reader.index;
        bool escape = false;
        while(!this.reader.empty && (escape || this.reader.front != '"')) {
            escape = false;
            if(this.reader.front == '\\') {
                escape = true;
            }
            this.reader.popFront();
        }
        if(escape || this.reader.empty || this.reader.front != '"') {
            return Result.Error(
                this.endLocation(location), Status.UnterminatedStringLiteral
            );
        }
        const endIndex = this.reader.index;
        assert(this.reader.front == '"');
        this.reader.popFront();
        const escaped = this.reader.content[startIndex .. endIndex];
        const text = cast(string) unescapeCapsuleText(escaped).toArray();
        return Result.Ok(this.endLocation(location), text);
    }
    
    /// Assuming the reader is positioned at the beginning of a decimal integer
    /// integer literal, parse the given literal value.
    /// This function always returns an unsigned integer representation of
    /// the data, even if there was a negative sign.
    auto parseUnsignedIntegerLiteral() {
        alias Result = CapsuleAsmParseResult!uint;
        const location = this.reader.location;
        // Parse some digits
        uint value = 0;
        size_t index = 0;
        while(!this.reader.empty && (this.reader.front == '_' || (
            this.reader.front >= '0' && this.reader.front <= '9'
        ))) {
            if(this.reader.front == '_') {
                this.reader.popFront();
                continue;
            }
            const oldValue = value;
            value = (value * 10) + (this.reader.front - '0');
            if(value < oldValue) return Result.Error(
                this.endLocation(location), Status.InvalidDecimalLiteral
            );
            this.reader.popFront();
            index++;
        }
        // Wrap it up
        if(index == 0) return Result.Error(
            this.endLocation(location), Status.InvalidDecimalLiteral
        );
        return Result.Ok(this.endLocation(location), value);
    }
    
    /// Assuming the reader is positioned at the beginning of a hexadecimal
    /// integer literal (after the "0x") parse the given literal value.
    auto parseHexLiteral() {
        alias Result = CapsuleAsmParseResult!uint;
        const location = this.reader.location;
        uint value = 0;
        uint index = 0;
        while(!this.reader.empty && isHexDigit(this.reader.front)) {
            value = (value << 4) | getHexDigitValue(this.reader.front);
            this.reader.popFront();
            if(index++ > 8) return Result.Error(
                this.endLocation(location), Status.InvalidHexLiteralTooLong
            );
        }
        if(index == 0) {
            return Result.Error(
                this.endLocation(location), Status.InvalidHexLiteralPrefix
            );
        }
        else {
            return Result.Ok(this.endLocation(location), value);
        }
    }
    
    auto parseOctalLiteral() {
        alias Result = CapsuleAsmParseResult!uint;
        const location = this.reader.location;
        uint value = 0;
        uint index = 0;
        while(!this.reader.empty && (
            this.reader.front >= '0' && this.reader.front <= '7'
        )) {
            const oldValue = value;
            value = (value << 3) | (this.reader.front - '0');
            this.reader.popFront();
            if(value < oldValue) return Result.Error(
                this.endLocation(location), Status.InvalidOctalLiteralOverflow
            );
        }
        if(index == 0) {
            return Result.Error(
                this.endLocation(location), Status.InvalidOctalLiteral
            );
        }
        else {
            return Result.Ok(this.endLocation(location), value);
        }
    }
    
    auto parseBinaryLiteral() {
        alias Result = CapsuleAsmParseResult!uint;
        const location = this.reader.location;
        uint value = 0;
        uint index = 0;
        while(!this.reader.empty && (
            this.reader.front == '0' || this.reader.front == '1'
        )) {
            const oldValue = value;
            value = (value << 1) | (this.reader.front - '0');
            this.reader.popFront();
            if(value < oldValue) return Result.Error(
                this.endLocation(location), Status.InvalidBinaryLiteralOverflow
            );
        }
        if(index == 0) {
            return Result.Error(
                this.endLocation(location), Status.InvalidBinaryLiteralPrefix
            );
        }
        else {
            return Result.Ok(this.endLocation(location), value);
        }
    }
    
    /// Parse a character literal, e.g. 'x'.
    /// The file reader should be positioned on the opening single quote.
    auto parseCharacterLiteral() {
        alias Result = CapsuleAsmParseResult!uint;
        const location = this.reader.location;
        // Make sure a character literal e.g. 'x' really is starting here
        if(this.reader.empty || this.reader.front != '\'') return Result.Error(
            this.endLocation(location), Status.InvalidCharacterLiteral
        );
        // Pop the opening single quote
        this.reader.popFront();
        // Parse the contained character
        char value = 0;
        // Parse an escape sequence e.g. \x7f
        if(this.reader.front == '\\') {
            size_t escStartIndex = this.reader.index;
            this.reader.popFront();
            bool escape = true;
            while(!this.reader.empty && (escape || this.reader.front != '\'')) {
                this.reader.popFront();
                escape = false;
            }
            if(!this.reader.empty && this.reader.front == '\'') {
                const escapeSequence = this.reader.content[
                    escStartIndex .. this.reader.index
                ];
                auto unescaped = unescapeCapsuleText(escapeSequence);
                if(unescaped.empty) {
                    this.reader.popFront();
                    return Result.Error(
                        this.endLocation(location), Status.InvalidCharacterLiteral
                    );
                }
                value = unescaped.front;
                unescaped.popFront();
                if(!unescaped.empty) {
                    this.reader.popFront();
                    return Result.Error(
                        this.endLocation(location), Status.InvalidCharacterLiteral
                    );
                }
            }
        }
        // Parse a regular, not-an-escape-sequence literal e.g. 'x'
        else {
            value = cast(char) this.reader.front;
            this.reader.popFront();
        }
        // Make sure the parser reached the literal's ending quote
        if(this.reader.empty || this.reader.front != '\'') {
            return Result.Error(
                this.endLocation(location), Status.InvalidCharacterLiteral
            );
        }
        // Pop that end quote, assuming one was found
        this.reader.popFront();
        // All done
        return Result.Ok(this.endLocation(location), cast(uint) value);
    }
    
    /// Parse a number literal.
    /// Literals starting with "0x" or "0X" are parsed as hexadecimal integers.
    /// Literals starting with "0b" or "0B" are parsed as binary integers.
    /// Literals otherwise starting with "0" are parsed as octal integers.
    /// Literals starting with a single quote are parsed as characters.
    /// Literals starting with '+', '-', or a decimal digit are parsed as
    /// decimal integers.
    /// Anything else will produce an error.
    auto parseNumberLiteral() {
        alias Result = CapsuleAsmParseResult!uint;
        const location = this.reader.location;
        if(this.reader.empty) return Result.Error(
            this.reader.location, Status.InvalidNumber
        );
        const bool bitNegate = (this.reader.front == '~');
        const bool intNegate = (this.reader.front == '-');
        const bool intPositive = (this.reader.front == '+');
        if(bitNegate || intNegate || intPositive) {
            this.reader.popFront();
        }
        const result = this.parseUnsignedNumberLiteral();
        if(!result.ok) {
            return result;
        }
        if(bitNegate) {
            return Result.Ok(this.endLocation(location), ~result.value);
        }
        else if(intNegate) {
            return Result.Ok(this.endLocation(location), -result.value);
        }
        else {
            return Result.Ok(this.endLocation(location), result.value);
        }
    }
    
    /// Helper used by the parseNumberLiteral function.
    auto parseUnsignedNumberLiteral() {
        alias Result = CapsuleAsmParseResult!uint;
        const location = this.reader.location;
        if(this.reader.empty) return Result.Error(
            this.reader.location, Status.InvalidNumber
        );
        if(this.reader.front == '0') {
            this.reader.popFront();
            if(this.reader.empty) {
                return Result.Ok(this.endLocation(location), 0);
            }
            else if(this.reader.front == 'x' || this.reader.front == 'X') {
                this.reader.popFront();
                return this.parseHexLiteral();
            }
            else if(this.reader.front == 'b' || this.reader.front == 'B') {
                this.reader.popFront();
                return this.parseBinaryLiteral();
            }
            else if(!isDigit(this.reader.front)) {
                return Result.Ok(this.endLocation(location), 0);
            }
            else {
                return this.parseOctalLiteral();
            }
        }
        else if(this.reader.front == '\'') {
            return this.parseCharacterLiteral();
        }
        else {
            return this.parseUnsignedIntegerLiteral();
        }
    }
    
    /// Parse a number value.
    /// Handles both literals and symbolic references.
    /// The function needs to know how large the data type is
    /// meant to be in bits.
    auto parseNumber(in ReferenceType defaultReferenceType) {
        alias Result = CapsuleAsmParseResult!(Node.Number);
        const location = this.reader.location;
        auto number = Node.Number(0);
        number.referenceType = defaultReferenceType;
        if(this.reader.empty) return Result.Error(
            this.endLocation(location), Status.InvalidNumber
        );
        // Literal - 1234
        const charLiteral = (this.reader.front == '\'');
        const signedLiteral = (
            this.reader.front == '-' ||
            this.reader.front == '+' ||
            this.reader.front == '~'
        );
        if(isDigit(this.reader.front) || charLiteral || signedLiteral) {
            const literal = this.parseNumberLiteral();
            // Special case: "0b" looks like a binary number literal
            if(literal.status is Status.InvalidBinaryLiteralPrefix && (
                this.reader.index >= 2 &&
                this.reader.content[this.reader.index - 2] == '0' &&
                this.reader.content[this.reader.index - 1] == 'b'
            )) {
                number.name = "0";
                number.localType = LocalType.Backward;
                goto FoundSymbolName;
            }
            // Found a literal number value
            else if(signedLiteral || charLiteral || (
                this.reader.front != 'b' && this.reader.front != 'f' &&
                this.reader.front != '.'
            )) {
                number.value = literal.value;
                return Result(
                    literal.status, literal.location, literal.context, number
                );
            }
            // Found a local label reference
            number.name = this.reader.content[
                location.startIndex .. this.reader.index
            ];
            // Found a local label with a '.' in it, as opposed to it being
            // entirely numeric, for example "0.my_local_label.b"
            if(this.reader.front == '.') {
                const rest = this.parseIdentifier();
                if(!rest.ok || rest.value.length < 3 || rest.value[$ - 2] != '.' ||
                    (rest.value[$ - 1] != 'f' && rest.value[$ - 1] != 'b')
                ) {
                    return Result.Error(
                        this.endLocation(location), Status.InvalidNumber
                    );
                }
                number.name ~= rest.value[0 .. $ - 2];
                number.localType = cast(LocalType) rest.value[$ - 1];
            }
            // Found a local label reference that was entirely numeric
            // For example "1234f"
            else {
                number.localType = cast(LocalType) this.reader.front;
                this.reader.popFront();
            }
        }
        // Symbol - my_label
        if(!number.name) {
            const symbol = this.parseIdentifier();
            if(!symbol.ok) return Result.Error(
                this.endLocation(location), Status.InvalidNumber
            );
            number.name = symbol.value;
        }
        FoundSymbolName:
        bool inlineOk = this.parseInlineWhitespace();
        if(!inlineOk) return Result.Error(
            this.endLocation(location), Status.InvalidNumber
        );
        if(this.reader.empty || this.reader.front != '[') {
            return Result.Ok(this.endLocation(location), number);
        }
        // Reference type and/or addend - my_label[pcrel_lo], my_label[16]
        bool hasAddend = false;
        while(!this.reader.empty && this.reader.front == '[') {
            const openBracketLocation = this.reader.location;
            this.reader.popFront();
            inlineOk = this.parseInlineWhitespace();
            if(!inlineOk) return Result.Error(
                this.endLocation(location), Status.InvalidNumber
            );
            // Addend - my_label[16]
            if(isDigit(this.reader.front) ||
                this.reader.front == '-' || this.reader.front == '+'
            ) {
                const addValue = this.parseNumberLiteral();
                number.addend = addValue.value;
                if(hasAddend || !addValue.ok) return Result.Error(
                    addValue.location, addValue.status
                );
                hasAddend = true;
            }
            // Reference/relocation type - my_label[pcrel_lo]
            else {
                const identifier = this.parseIdentifier();
                number.referenceType = (
                    getEnumMemberWithAttribute!ReferenceType(identifier.value)
                );
                if(!identifier.ok || !number.referenceType) return Result.Error(
                    this.endLocation(location),
                    Status.InvalidObjectReferenceType,
                    identifier.value
                );
            }
            inlineOk = this.parseInlineWhitespace();
            if(!inlineOk) return Result.Error(
                this.endLocation(location), Status.InvalidNumber
            );
            if(this.reader.empty || this.reader.front != ']') return Result.Error(
                this.endLocation(openBracketLocation), Status.UnmatchedOpenBracket
            );
            this.reader.popFront();
            inlineOk = this.parseInlineWhitespace();
            if(!inlineOk) return Result.Error(
                this.endLocation(location), Status.InvalidNumber
            );
        }
        // All done
        return Result.Ok(this.endLocation(location), number);
    }
    
    auto parseNumberList(in ReferenceType defaultReferenceType) {
        alias Result = CapsuleAsmParseResult!(Node.Number[]);
        const location = this.reader.location;
        Node.Number[] values;
        while(!this.reader.empty) {
            auto arg = this.parseNumber(defaultReferenceType);
            if(!arg.ok) {
                return Result.Error(arg.location, arg.status);
            }
            values ~= arg.value;
            const sep = this.parseArgSeparator();
            if(!sep) {
                break;
            }
        }
        return Result.Ok(this.endLocation(location), values);
    }
}
