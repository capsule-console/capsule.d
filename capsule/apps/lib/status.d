module capsule.apps.lib.status;

public nothrow @safe @nogc:

enum CapsuleApplicationStatus: int {
    Ok = 0x0000,
    ExecutionExitError = 0x0001,
    // Errors related to config files or CLI configuration arguments
    ConfigError = 0x0100,
    ConfigFileReadError = 0x0101,
    ConfigFileWriteError = 0x0102,
    ConfigFileParseError = 0x0103,
    ConfigOptionError = 0x0104,
    ConfigInvalidOptionNameError = 0x0105,
    ConfigInvalidOptionValueError = 0x0106,
    ConfigMissingRequiredOptionError = 0x0107,
    // Errors related to source code files
    SourceError = 0x0200,
    SourceFileReadError = 0x0201,
    SourceFileWriteError = 0x0202,
    // Errors related to object files
    ObjectError = 0x0300,
    ObjectEncodeError = 0x0301,
    ObjectDecodeError = 0x0302,
    ObjectFileReadError = 0x0303,
    ObjectFileWriteError = 0x0304,
    ObjectInvalidError = 0x0305,
    // Errors related to program files
    ProgramError = 0x0400,
    ProgramEncodeError = 0x0401,
    ProgramDecodeError = 0x0402,
    ProgramFileReadError = 0x0403,
    ProgramFileWriteError = 0x0404,
    ProgramInvalidError = 0x0405,
    // Errors related to compilation
    CompileError = 0x0500,
    // Errors related to linking
    LinkError = 0x0600,
    // Errors related to executing a program
    ExecutionError = 0x0700,
    ExecutionAborted = 0x0702,
    ExecutionTerminated = 0x0703,
    // Errors relating to running tests or checks
    CheckTestError = 0x0800,
    CheckTestFailure = 0x0801,
    CheckTestFailureWrongStatus = 0x0802,
    CheckTestFailureWrongOutput = 0x0803,
}
