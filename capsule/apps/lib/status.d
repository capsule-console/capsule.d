module capsule.apps.lib.status;

public nothrow @safe @nogc:

/// Enumeration of exit status codes used by Capsule applications,
/// including the Capsule assembler (casm), linker (clink), and
/// virtual machine (capsule).
enum CapsuleApplicationStatus: int {
    Ok = 0x00,
    ExecutionExitError = 0x01,
    // Errors related to config files or CLI configuration arguments
    ConfigError = 0x10,
    ConfigFileReadError = 0x11,
    ConfigFileWriteError = 0x12,
    ConfigFileParseError = 0x13,
    ConfigOptionError = 0x14,
    ConfigInvalidOptionNameError = 0x15,
    ConfigInvalidOptionValueError = 0x16,
    ConfigMissingRequiredOptionError = 0x17,
    // Errors related to source code files
    SourceError = 0x20,
    SourceFileReadError = 0x21,
    SourceFileWriteError = 0x22,
    // Errors related to object files
    ObjectError = 0x30,
    ObjectEncodeError = 0x31,
    ObjectDecodeError = 0x32,
    ObjectFileReadError = 0x33,
    ObjectFileWriteError = 0x34,
    ObjectInvalidError = 0x35,
    // Errors related to program files
    ProgramError = 0x40,
    ProgramEncodeError = 0x41,
    ProgramDecodeError = 0x42,
    ProgramFileReadError = 0x43,
    ProgramFileWriteError = 0x44,
    ProgramInvalidError = 0x45,
    // Errors related to compilation
    CompileError = 0x50,
    // Errors related to linking
    LinkError = 0x60,
    // Errors related to executing a program
    ExecutionError = 0x70,
    ExecutionAborted = 0x72,
    ExecutionTerminated = 0x73,
    // Errors relating to running tests or checks
    CheckTestError = 0x80,
    CheckTestFailure = 0x81,
    CheckTestFailureWrongStatus = 0x82,
    CheckTestFailureWrongOutput = 0x83,
    // Errors related to an automated build process
    BuildError = 0x90,
}
