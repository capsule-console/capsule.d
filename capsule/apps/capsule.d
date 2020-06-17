module capsule.apps.capsule;

import capsule.core.config : CapsuleConfigAttribute, CapsuleConfigStatus;
import capsule.core.config : loadCapsuleConfig, capsuleConfigStatusToString;
import capsule.core.config : getCapsuleConfigUsageString;
import capsule.core.engine : CapsuleEngine;
import capsule.core.engineinit : initializeCapsuleEngine;
import capsule.core.enums : getEnumMemberName;
import capsule.core.extension : CapsuleExtension;
import capsule.core.file : File;
import capsule.core.program : CapsuleProgram;
import capsule.core.programencode : CapsuleProgramDecoder;
import capsule.core.programstring : capsuleProgramToString;
import capsule.core.stdio : stdio;
import capsule.core.typestrings : getCapsuleExceptionDescription;

import capsule.apps.ecall : ecall, ecallExtList;
import capsule.apps.runprogram : runProgram, debugProgram;
import capsule.apps.status : CapsuleApplicationStatus;
import capsule.apps.lib.stdio : CapsuleStandardIO;

public:

enum string CapsuleEngineVersionName = "20200514";

struct CapsuleEngineConfig {
    enum string[] UsageText = [
        "Capsule engine version " ~ CapsuleEngineVersionName,
        "Load and execute Capsule program files.",
        "Usage:",
        "  casm <file> [<option>...]",
    ];
    
    @(CapsuleConfigAttribute!string("stdout-path")
        .setOptional(null)
        .setHelpText([
            "Send the program's standard output to a file path.",
        ])
    )
    string stdoutPath;
    
    @(CapsuleConfigAttribute!string("stdin-path")
        .setOptional(null)
        .setHelpText([
            "Read the program's standard input from a file path.",
        ])
    )
    string stdinPath;
    
    @(CapsuleConfigAttribute!string("stdin", "in")
        .setOptional(null)
        .setHelpText([
            "Use the text given with this argument as the program's ",
            "standard input."
        ])
    )
    string stdin;
    
    @(CapsuleConfigAttribute!bool("debug", "db")
        .setOptional(false)
        .setHelpText([
            "Run the program in debug mode, with controls such as ",
            "step-by-step execution."
        ])
    )
    bool debugMode;
    
    @(CapsuleConfigAttribute!bool("verbose", "v")
        .setOptional(false)
        .setHelpText([
            "When set, the engine will log more messages than usual.",
        ])
    )
    bool verbose;
}

CapsuleApplicationStatus execute(string[] args) {
    alias Config = CapsuleEngineConfig;
    alias Status = CapsuleApplicationStatus;
    enum string VersionName = CapsuleEngineVersionName;
    // Initialize ecall function pointers
    for(size_t i = 0; i < ecallExtList.length; i++) {
        if(ecallExtList[i].id == CapsuleExtension.stdio_init) {
            ecallExtList[i].func = &CapsuleStandardIO.ecall_stdio_init;
        }
        else if(ecallExtList[i].id == CapsuleExtension.stdio_put_byte) {
            ecallExtList[i].func = &CapsuleStandardIO.ecall_stdio_put_byte;
        }
        else if(ecallExtList[i].id == CapsuleExtension.stdio_get_byte) {
            ecallExtList[i].func = &CapsuleStandardIO.ecall_stdio_get_byte;
        }
    }
    // Handle --help or --version
    if(args.length <= 1 || args[1] == "--help") {
        stdio.writeln(getCapsuleConfigUsageString!Config());
        return Status.Ok;
    }
    else if(args[1] == "--version") {
        stdio.writeln("Capsule engine version ", VersionName);
        return Status.Ok;
    }
    // Get configuration options
    auto configResult = loadCapsuleConfig!Config(args[2 .. $]);
    auto config = configResult.config;
    const verbose = configResult.config.verbose;
    CapsuleStandardIO.global.setOutputPath(config.stdoutPath);
    if(config.stdin) {
        CapsuleStandardIO.global.setInputContent(config.stdin);
    }
    else {
        CapsuleStandardIO.global.setInputPath(config.stdinPath);
    }
    if(!configResult.ok) {
        stdio.writeln(configResult.toString());
        switch(configResult.status) {
            case CapsuleConfigStatus.InvalidOptionNameError:
                return Status.ConfigInvalidOptionNameError;
            case CapsuleConfigStatus.InvalidOptionValueError:
                return Status.ConfigInvalidOptionValueError;
            case CapsuleConfigStatus.MissingRequiredOptionError:
                return Status.ConfigMissingRequiredOptionError;
            default:
                return Status.ConfigOptionError;
        }
    }
    // Read the input program file 
    if(verbose) stdio.writeln("Reading from program file path.");
    const inputPath = args.length > 1 ? args[1] : null;
    if(!inputPath.length) {
        stdio.writeln("No program file path was specified.");
        stdio.writeln("A program file path must be given.");
        return Status.ConfigInvalidOptionValueError;
    }
    File programFile = File.read(inputPath);
    if(!programFile.ok) {
        stdio.writeln("Error reading program from path ", inputPath);
        return Status.ProgramFileReadError;
    }
    // Decode the input program file
    size_t encodedProgramIndex;
    int readByte() nothrow @trusted @nogc {
        return (encodedProgramIndex >= programFile.content.length ? -1 :
            cast(int) programFile.content[encodedProgramIndex++]
        );
    }
    auto decode = CapsuleProgramDecoder(&readByte).read();
    if(!decode.ok) {
        stdio.writeln("Error decoding program file at path ", inputPath);
        return Status.ProgramDecodeError;
    }
    // If the verbose flag was set, write a stringification of the
    // program file to stdout
    if(verbose) {
        stdio.writeln("String representation of loaded program file:");
        stdio.writeln(capsuleProgramToString(decode.program));
    }
    // Initialize a CapsuleEngine instance to run the program with
    CapsuleEngine engine = initializeCapsuleEngine(decode.program, &ecall);
    const beginOk = engine.begin(cast(int) decode.program.entryOffset);
    if(!engine.ok || !beginOk) {
        stdio.writeln("Program file is invalid and cannot be executed.");
        return Status.ProgramInvalidError;
    }
    // Run it!
    if(config.debugMode) debugProgram(decode.program, engine);
    else runProgram(engine);
    // Wrap it up
    if(verbose) {
        const status = getEnumMemberName(engine.status);
        stdio.writeln("Execution complete with status ", status);
    }
    if(engine.exception) {
        stdio.writeln("Exception: ",
            getCapsuleExceptionDescription(engine.exception)
        );
    }
    engine.mem.free();
    switch(engine.status) {
        case CapsuleEngine.Status.None:
            return Status.ExecutionError;
        case CapsuleEngine.Status.ExitError:
            return Status.ExecutionExitError;
        case CapsuleEngine.Status.Aborted:
            return Status.ExecutionAborted;
        case CapsuleEngine.Status.Terminated:
            return Status.ExecutionTerminated;
        default:
            return Status.Ok;
    }
}

version(CapsuleExcludeExecutionMain) {}
else int main(string[] args) {
    const status = execute(args);
    return cast(int) status;
}
