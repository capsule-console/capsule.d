module capsule.casm.messages;

import capsule.core.ascii : isWhitespace;
import capsule.core.enums : getEnumMemberName, getEnumMemberAttribute;
import capsule.core.messages : CapsuleMessageLog, CapsuleMessageSeverity;
import capsule.core.messages : CapsuleMessageSeverityChars;
import capsule.core.messages : getCapsuleMessageSeverityByChar;

private alias Status = CapsuleAsmMessageStatus;
private alias Severity = CapsuleMessageSeverity;

public:

alias CapsuleAsmMessageLog = CapsuleMessageLog!CapsuleAsmMessageStatus;

struct CapsuleAsmMessageStatusSeverity {
    alias Severity = CapsuleAsmMessageLog.Severity;
    alias Status = CapsuleAsmMessageStatus;
    
    Status status;
    Severity severity;
}

enum CapsuleAsmMessageStatus: uint {
    // Misc
    @('N', "")
    Ok = 0,
    @('N', "Message not specified.")
    Unspecified,
    // Debug/info
    @('D', "Beginning to parse assembly source file.")
    ParseStart,
    @('D', "Finished parsing assembly source file.")
    ParseEnd,
    @('D', "Parser skipping to the next line.")
    ParseSkipToNextLine,
    @('D', "Parser encountered a label definition.")
    ParseLabelDefinition,
    @('D', "Parser encountered a directive.")
    ParseDirective,
    @('D', "Compiler is parsing sources.")
    CompileParseSources,
    @('D', "Compiler is parsing a source file.")
    CompileParseSourceFile,
    @('D', "Compiler is validating .export directives.")
    CompileCheckExportSymbols,
    @('D', "Compiler indexed a global label definition.")
    CompileCreateGlobalMapIndexGlobalLabel,
    @('D', "Compiler indexed an exported label definition.")
    CompileCreateGlobalMapIndexExportLabel,
    @('D', "Compiler indexed a global constant value definition.")
    CompileCreateGlobalMapIndexGlobalConst,
    @('D', "Compiler indexed an exported constant value definition.")
    CompileCreateGlobalMapIndexExportConst,
    @('D', "Compiler indexed a global extern declaration.")
    CompileCreateGlobalMapIndexGlobalExtern,
    @('D', "Compiler is resolving local references.")
    CompileResolveLocalReferences,
    @('D', "Compiler encountered a label definition.")
    CompileLabelDefinition,
    @('D', "Compiler encountered a directive.")
    CompileDirective,
    @('D', "Compiler identified an end offset for a procedure definition.")
    CompileEndProcedureDirective,
    @('D', "Compiler found a .const constant value directive.")
    CompileConstantDirective,
    @('D', "Compiler found an .export directive.")
    CompileExportDirective,
    @('D', "Compiler found an .extern symbol declaration directive.")
    CompileExternDirective,
    @('D', "Compiler is including a binary file via .incbin.")
    CompileIncludeBinary,
    @('D', "Compiler is including a source file via .include.")
    CompileIncludeSource,
    @('D', "Compiler is attempting to resolve a reference.")
    CompileTryResolveReference,
    @('D', "Compiler was able to resolve a reference.")
    CompileResolveReferenceSuccess,
    @('D', "Compiler did not have enough information to resolve a reference.")
    CompileResolveReferenceNotEnoughInfo,
    @('D', "Linker is sorting the section list.")
    LinkSortObjectSections,
    @('D', "Linker is determining the program entry offset.")
    LinkResolveEntryOffset,
    @('D', "Linker found an entry offset.")
    LinkFoundEntryOffset,
    @('D', "Linker is resolving section offsets.")
    LinkResolveSectionOffsets,
    @('D', "Linker is indexing symbol definitions.")
    LinkCreateSymbolMap,
    @('D', "Linker is resolving symbol references.")
    LinkResolveReferences,
    @('D', "Linker resolved a symbol reference.")
    LinkerResolveReferenceSuccess,
    @('D', "Linker is resolving the low half of a PC-relative reference.")
    LinkResolvePCRelLoReference,
    // Errors/warnings
    @('E', "Invalid instruction.")
    InvalidInstruction,
    @('E', "Invalid instruction name.")
    InvalidInstructionName,
    @('E', "Invalid instruction opcode.")
    InvalidInstructionOpcode,
    @('W', "Unknown instruction opcode.")
    UnknownInstructionOpcode,
    @('E', "Duplicate symbol declaration.")
    DuplicateSymbolDeclaration,
    @('E', "Expected a defined symbol but found an undefined symbol.")
    UndefinedSymbol,
    @('E', "Expected a defined symbol to export, but found an undefined symbol.")
    ExportUndefinedSymbol,
    @('E', "Export directive does not match any symbol declaration.")
    ExportUndeclaredSymbol,
    @('E', "Reference to undeclared symbol.")
    UndeclaredSymbolReference,
    @('E', "Directive .endproc must refer to a procedure previously defined in the same section.")
    InvalidCompileEndProcedureName,
    @('E', "Operation must occur within a declared section.")
    OperationInUndeclaredSection,
    @('E', "Assigned initialized data in an uninitialized section.")
    DataInUninitializedSection,
    @('W', "Assigned arbitrary data in an executable section.")
    DataInExecutableSection,
    @('E', "Unresolved reference.")
    UnresolvedReference,
    @('E', "Section alignment value is unusually large.")
    LargeAlignment,
    @('E', "Alignment is not a power of two.")
    AlignmentNotPowTwo,
    @('E', "No entry point.")
    NoEntryPoint,
    @('W', "Multiple entry points.")
    MultipleEntryPoints,
    @('W', "Section has multiple priority values.")
    MultipleSectionPriorities,
    @('E', "Invalid entry point in object.")
    InvalidObjectEntry,
    @('E', "Invalid syntax.")
    InvalidSyntax,
    @('E', "Unterminated string literal.")
    UnterminatedStringLiteral,
    @('E', "Unmatched open bracket.")
    UnmatchedOpenBracket,
    @('E', "Unmatched close bracket.")
    UnmatchedCloseBracket,
    @('E', "Invalid escape sequence.")
    InvalidEscapeSequence,
    @('E', "Invalid string.")
    InvalidString,
    @('E', "Invalid number value.")
    InvalidNumber,
    @('E', "Invalid decimal integer literal.")
    InvalidDecimalLiteral,
    @('E', "Invalid hexadecimal integer literal.")
    InvalidHexLiteral,
    @('E', "Encountered a hexadecimal number literal prefix without a following value.")
    InvalidHexLiteralPrefix,
    @('E', "Hexadecimal number literal is too long. Literals must not exceed eight digits.")
    InvalidHexLiteralTooLong,
    @('E', "Invalid octal integer literal.")
    InvalidOctalLiteral,
    @('E', "Binary literal value cannot fit into a 32-bit word.")
    InvalidOctalLiteralOverflow,
    @('E', "Encountered a binary number literal prefix without a following value.")
    InvalidBinaryLiteralPrefix,
    @('E', "Invalid binary integer literal.")
    InvalidBinaryLiteral,
    @('E', "Binary literal value cannot fit into a 32-bit word.")
    InvalidBinaryLiteralOverflow,
    @('E', "Invalid character literal.")
    InvalidCharacterLiteral,
    @('E', "Invalid identifier.")
    InvalidIdentifier,
    @('E', "Invalid directive.")
    InvalidDirective,
    @('E', "Invalid label.")
    InvalidLabel,
    @('E', "Invalid symbol name.")
    InvalidSymbolName,
    @('E', "Invalid object.")
    InvalidObject,
    @('E', "Invalid symbol.")
    InvalidObjectSymbol,
    @('E', "Invalid symbol type.")
    InvalidObjectSymbolType,
    @('E', "Invalid reference.")
    InvalidObjectReference,
    @('E', "Invalid reference type.")
    InvalidObjectReferenceType,
    @('E', "Invalid local reference type.")
    InvalidObjectReferenceLocalType,
    @('E', "Referenced name does not match any symbol declaration.")
    InvalidObjectReferenceUndeclaredSymbol,
    @('E', "Invalid object section.")
    InvalidObjectSection,
    @('E', "Invalid object section type.")
    InvalidObjectSectionType,
    @('E', "Invalid source locations debug data in object.")
    InvalidObjectSourceLocationData,
    @('E', "Invalid capsule program.")
    InvalidProgram,
    @('E', "Invalid segment.")
    InvalidProgramSegment,
    @('E', "Invalid segment type.")
    InvalidProgramSegmentType,
    @('E', "Wrong arguments for directive.")
    DirectiveWrongArgs,
    @('E', "Wrong arguments for instruction.")
    InstructionWrongArgs,
    @('E', "Instruction argument list contains more registers than expected.")
    InstructionArgsTooManyRegisters,
    @('W', "Instruction argument list contains fewer registers than expected.")
    InstructionArgsTooFewRegisters,
    @('W', "Instruction argument list contains an unexpected immediate value.")
    InstructionArgsUnexpectedImmediate,
    @('W', "Instruction argument list is missing an expected immediate value.")
    InstructionArgsMissingImmediate,
    @('E', "Invalid destination register argument for pseudo-instruction.")
    PseudoInstructionBadDstRegisterArgs,
    @('E', "Pseudo-instruction does not allow using the same register as both source and destination.")
    PseudoInstructionBadSrcDstRegisterArgs,
    @('E', "Wrong checksum.")
    WrongChecksum,
    @('E', "Wrong section checksum.")
    WrongSectionChecksum,
    @('E', "Wrong segment checksum.")
    WrongSegmentChecksum,
    @('E', "Wrong source file checksum.")
    WrongSourceChecksum,
    @('E', "Section is too large.")
    SectionTooLarge,
    @('E', "Segment is too large.")
    SegmentTooLarge,
    @('E', "Program is too large.")
    ProgramTooLarge,
    @('E', "The number of names has exceeded the limit.")
    TooManyNames,
    @('E', "The number of symbols has exceeded the limit.")
    TooManySymbols,
    @('E', "The number of references has exceeded the limit.")
    TooManyReferences,
    @('E', "The number of sections has exceeded the limit.")
    TooManySections,
    @('E', "The number of objects has exceeded the limit.")
    TooManyObjects,
    @('E', "The number of source files has exceeded the limit.")
    TooManySources,
    @('E', "The number of source file locations has exceeded the limit.")
    TooManySourceLocations,
    @('W', "Data is misaligned.")
    MisalignedData,
    @('W', "Half word is not aligned on a half word boundary.")
    MisalignedHalfWord,
    @('W', "Word is not aligned on a word boundary.")
    MisalignedWord,
    @('W', "Instruction is not aligned on a word boundary.")
    MisalignedInstruction,
    @('W', "Found multiple definition type directives before finding an applicable definition.")
    MultipleConsecutiveDefinitionTypeDirectives,
    @('W', "Found a definition type directive without any applicable definition.")
    HangingDefinitionTypeDirective,
    @('E', "Object text encoding mismatch.")
    ObjectTextEncodingMismatch,
    @('E', "Object time encoding mismatch.")
    ObjectTimeEncodingMismatch,
    @('E', "Object architecture mismatch.")
    ObjectArchitectureMismatch,
    @('E', "Object has no architecture.")
    ObjectNoArchitecture,
    @('E', "Program has no architecture.")
    ProgramNoArchitecture,
    @('W', "Referenced value overflows and does not fit in the expected space.")
    ReferenceValueOverflow,
    @('W', "Referenced PC-relative offset overflows and does not fit in the expected space.")
    ReferencePCRelOverflow,
    @('W', "Encountered a reference outside of the section bounds.")
    ReferenceOutOfBounds,
    @('E', "Encountered a reference in an uninitialized section.")
    ReferenceInUninitializedSection,
    @('E', "Reference with pcrel_lo type does not have a corresponding pcrel_hi.")
    ObjectReferenceUnmatchedPCRelLo,
    @('E', "Reference with pcrel_near_lo type does not have a corresponding pcrel_hi.")
    ObjectReferenceUnmatchedPCRelNearLo,
    @('E', "Symbol name is exported by more than one object.")
    DuplicateExportedSymbolName,
    @('E', "Global symbol name appears multiple times in the same object.")
    DuplicateGlobalSymbolName,
    @('E', "Failed to resolve file path.")
    FilePathResolutionError,
    @('E', "Failed to read from file path.")
    FilePathReadError,
    @('E', "Source file include tree goes too deep.")
    IncludeLevelTooDeep,
}

/// Parses a status severity override settings string, for example:
/// UnknownInstructionOpcode:W,AlignmentNotPowTwo:W
auto parseCapsuleStatusSeverityOverrides(Status)(in string text) {
    CapsuleAsmMessageStatusSeverity[] overrides;
    size_t index = 0;
    FoundStatusMatch: while(index < text.length) {
        // Skip whitespace in between entries
        while(index < text.length && isWhitespace(text[index])) {
            index++;
        }
        // Try to match the current entry against a status name
        foreach(member; __traits(allMembers, Status)) {
            if(text.length - index >= 3 + member.length &&
                text[index .. index + member.length] == member &&
                text[index + member.length + 1] == ':' &&
                text[index + member.length + 3] == ','
            ) {
                const severityChar = text[index + member.length];
                const noSeverityChar = CapsuleMessageSeverityChars[0];
                const severity = getCapsuleMessageSeverityByChar(severityChar);
                if(severity is Severity.None && severityChar != noSeverityChar) {
                    index += member.length + 3;
                    continue FoundStatusMatch;
                }
                overrides ~= CapsuleAsmMessageStatusSeverity(
                    __traits(getMember, Status, member), severity
                );
                index += member.length + 3;
                continue FoundStatusMatch;
            }
        }
        // Getting to here means none of the status names matched
        // Skip ahead to and past the next comma
        while(index < text.length && text[index] != ',') {
            index++;
        }
        if(index < text.length && text[index] == ',') {
            index++;
        }
    }
    return overrides;
}

template CapsuleAsmMessageMixin() {
    import capsule.core.enums : getEnumMemberAttribute;
    import capsule.core.messages : CapsuleMessageLog;
    import capsule.core.messages : getCapsuleMessageSeverityByChar;
    
    alias Log = CapsuleMessageLog!CapsuleAsmMessageStatus;
    alias Status = CapsuleAsmMessageStatus;
    alias StatusSeverity = CapsuleAsmMessageStatusSeverity;
    
    Log* log;
    StatusSeverity[] statusSeverityOverrides;
    
    bool ok() const {
        return this.log ? !this.log.anyErrors : false;
    }
    
    void addStatus(
        in FileLocation location, in Log.Severity severity,
        in Status status, in string context = null
    ) {
        assert(this.log);
        assert(status !is Status.Ok);
        if(this.log) {
            this.log.add(location, severity, status, context);
        }
    }
    
    void addStatus(
        in FileLocation location, in Status status, in string context = null
    ) {
        auto severityChar = getEnumMemberAttribute!char(status);
        auto severity = getCapsuleMessageSeverityByChar(severityChar);
        foreach(statusSeverity; this.statusSeverityOverrides) {
            if(statusSeverity.status is status) {
                severity = statusSeverity.severity;
                break;
            }
        }
        if(severity is Log.Severity.None) {
            return;
        }
        else {
            this.addStatus(location, severity, status, context);
        }
    }
    
    void addDebug(in FileLocation location, in Status status, in string context = null) {
        this.addStatus(location, Log.Severity.Debug, status, context);
    }
    
    void addInfo(in FileLocation location, in Status status, in string context = null) {
        this.addStatus(location, Log.Severity.Info, status, context);
    }
    
    void addWarning(in FileLocation location, in Status status, in string context = null) {
        this.addStatus(location, Log.Severity.Warning, status, context);
    }
    
    void addError(in FileLocation location, in Status status, in string context = null) {
        this.addStatus(location, Log.Severity.Error, status, context);
    }
}
