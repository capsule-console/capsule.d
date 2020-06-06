module capsule.apps.capcheck;

import core.stdc.stdlib : system;

import capsule.core.config : CapsuleConfigAttribute, CapsuleConfigStatus;
import capsule.core.config : loadCapsuleConfig, capsuleConfigStatusToString;
import capsule.core.config : getCapsuleConfigUsageString;
import capsule.core.enums : getEnumMemberName, getEnumMemberByName;
import capsule.core.file : File;
import capsule.core.hex : getByteHexString;
import capsule.core.indexof : lastIndexOf;
import capsule.core.ini : Ini;
import capsule.core.path : Path;
import capsule.core.stdio : stdio;
import capsule.core.strings : padLeft;
import capsule.core.timer : Timer;
import capsule.core.writeint : writeInt;

import capsule.apps.status : CapsuleApplicationStatus;

public:

enum string CapsuleCheckVersionName = "20200514";

struct CapsuleCheckConfig {
    enum string[] UsageText = [
        "Capsule check (capcheck) version " ~ CapsuleCheckVersionName,
        "Run a suite of tests against a Capsule implementation ",
        "in order to verify its behavior.",
        "Usage:",
        "  capcheck <file> [<option>...]",
    ];
    
    @(CapsuleConfigAttribute!string("output", "o")
        .setOptional(null)
        .setHelpText([
            "Object and program files built from test sources ",
            "will be saved inside this directory."
        ])
    )
    string outputPath;
    
    @(CapsuleConfigAttribute!bool("debug", "db")
        .setOptional(false)
        .setHelpText([
            "When this flag is set, debugging information will be",
            "included in the outputted object and program files."
        ])
    )
    bool writeDebugInfo;
    
    @(CapsuleConfigAttribute!string("casm")
        .setOptional("casm")
        .setHelpText([
            "Command or path to binary to use when compiling Capsule ",
            "assembly source code files."
        ])
    )
    string casmCommand;
    
    @(CapsuleConfigAttribute!string("clink")
        .setOptional("clink")
        .setHelpText([
            "Command or path to binary to use when linking compiled ",
            "Capsule object files."
        ])
    )
    string clinkCommand;
    
    @(CapsuleConfigAttribute!string("capsule")
        .setOptional("capsule")
        .setHelpText([
            "Command or path to binary to use for executing compiled ",
            "Capsule program files."
        ])
    )
    string capsuleCommand;
    
    @(CapsuleConfigAttribute!string("only")
        .setOptional(null)
        .setHelpText([
            "Run the first test case with the specified name, if there ",
            "is one, and don't run any others."
        ])
    )
    string onlyTestName;
    
    @(CapsuleConfigAttribute!bool("verbose", "v")
        .setOptional(false)
        .setHelpText([
            "When set, the checker will log more messages than usual.",
        ])
    )
    bool verbose;
    
    @(CapsuleConfigAttribute!bool("very-verbose", "vv")
        .setOptional(false)
        .setHelpText([
            "When set, the checker will log quite a lot more messages ",
            "than usual.",
        ])
    )
    bool veryVerbose;
    
    @(CapsuleConfigAttribute!bool("silent")
        .setOptional(false)
        .setHelpText([
            "When set, the checker will log no messages.",
        ])
    )
    bool silent;
}

bool verbose = false;
bool silent = false;

void verboseln(T...)(lazy T args) {
    if(silent || !verbose) return;
    stdio.writeln(args);
}

void write(T...)(lazy T args) {
    if(silent) return;
    stdio.write(args);
}

void writeln(T...)(lazy T args) {
    if(silent) return;
    stdio.writeln(args);
}

struct CapsuleCheckTest {
    alias Status = CapsuleApplicationStatus;
    
    Status status = Status.Ok;
    string name = null;
    string comment = null;
    string[] sources = null;
    string stdin = null;
    string stdout = null;
    string casmArgs = null;
    string clinkArgs = null;
    string capsuleArgs = null;
}

/// Helper to escape a string to be used as a command line argument
string escapeArg(in string arg) {
    string escaped = `"`;
    foreach(ch; arg) {
        if(ch == '\"') {
            escaped ~= `\"`;
        }
        else if(ch == '\\') {
            escaped ~= `\\`;
        }
        else {
            escaped ~= ch;
        }
    }
    escaped ~= `"`;
    return escaped;
}

CapsuleApplicationStatus check(string[] args) {
    alias Config = CapsuleCheckConfig;
    alias Status = CapsuleApplicationStatus;
    enum string VersionName = CapsuleCheckVersionName;
    // Handle --help or --version
    if(args.length <= 1 || args[1] == "--help") {
        writeln(getCapsuleConfigUsageString!Config());
        return Status.Ok;
    }
    else if(args[1] == "--version") {
        writeln("Capsule check (capcheck) version ", VersionName);
        return Status.Ok;
    }
    // Quick check for the presence of a --silent argument
    foreach(arg; args) {
        if(arg == "--silent") {
            silent = true;
            break;
        }
    }
    // The first argument is expected to give the path to an INI file
    // describing test cases
    const iniPath = args.length > 1 ? args[1] : null;
    if(!iniPath.length) {
        writeln("No test configuration INI file path was specified.");
        writeln("A test configuration INI file path must be given.");
        return Status.ConfigInvalidOptionValueError;
    }
    // Load and parse the INI file
    auto iniFile = File.read(iniPath);
    if(!iniFile.ok) {
        writeln("Error reading test configuration INI file.");
        return Status.ConfigFileReadError;
    }
    auto iniParser = Ini.Parser(iniFile);
    iniParser.parse();
    if(!iniFile.ok) {
        writeln("Error parsing configuration INI file.");
        writeln(iniParser.log.toString());
        return Status.ConfigFileParseError;
    }
    // Get configuration options
    auto ini = iniParser.ini;
    auto configResult = loadCapsuleConfig!Config(args[2 .. $], ini.globals);
    auto config = configResult.config;
    verbose = configResult.config.verbose || configResult.config.veryVerbose;
    silent = configResult.config.silent;
    if(!configResult.ok) {
        writeln(configResult.toString());
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
    // Determine where to put outputted binary files
    const iniDir = Path(iniPath).dirName;
    const outDir = (Path(config.outputPath).isAbsolute ?
        Path(config.outputPath) : Path.join(iniDir, config.outputPath)
    ).toString();
    verboseln("Outputting binary files to directory ", outDir);
    // Run each test case
    verboseln("Running tests.");
    uint testsPassed = 0;
    uint testsFailed = 0;
    foreach(section; ini.sections) {
        // Handle the --only CLI option
        if(config.onlyTestName.length && section.name != config.onlyTestName) {
            continue;
        }
        // Run the test
        const expectStatus = (
            getEnumMemberByName!(CapsuleCheckTest.Status)(section.get("status"))
        );
        CapsuleCheckTest test = {
            name: section.name,
            comment: section.get("comment"),
            sources: section.all("source"),
            stdin: section.get("stdin"),
            stdout: section.get("stdout"),
            casmArgs: section.get("casmargs"),
            clinkArgs: section.get("clinkargs"),
            capsuleArgs: section.get("capsuleargs"),
            status: expectStatus,
        };
        const testResult = runTest(config, outDir, test);
        // Display PASS/FAIL
        if(testResult.status is Status.Ok) {
            write("PASS: ", section.name);
            testsPassed++;
        }
        else {
            const statusName = getEnumMemberName(testResult.status);
            write("FAIL: ", section.name ~ " (" ~ statusName ~ ")");
            testsFailed++;
        }
        // Display the time taken to run the test
        const totalMs = (
            testResult.compileTime.milliseconds +
            testResult.linkTime.milliseconds +
            testResult.runTime.milliseconds
        );
        const totalSeconds = totalMs / 1000;
        const remainingMs = totalMs % 1000;
        const msPadding = (
            remainingMs < 10 ? "00" :
            remainingMs < 100 ? "0" : ""
        );
        writeln(" (",
            writeInt(totalSeconds), ".", msPadding, writeInt(remainingMs),
            "s)"
        );
        // Display expected and actual stdout
        if(verbose) {
            writeln("Expected stdout ", section.name,
                " (", writeInt(test.stdout.length), " bytes):"
            );
            writeln(test.stdout);
            writeln("Actual stdout ", section.name,
                " (", writeInt(testResult.stdout.length), " bytes):"
            );
            writeln(testResult.stdout);
        }
        // More handling for --only
        if(config.onlyTestName.length) {
            assert(section.name == config.onlyTestName);
            break;
        }
    }
    // Write summmary of test results
    verboseln("Finished running tests.");
    writeln(
        "Passed: ", writeInt(testsPassed), " of ", writeInt(ini.sections.length)
    );
    if(testsFailed) {
        writeln("Failed: ", writeInt(testsFailed));
    }
    return testsFailed ? Status.CheckTestFailure : Status.Ok;
}

auto runTest(
    in CapsuleCheckConfig config, in string outDir,
    in CapsuleCheckTest test,
) {
    // Handy data types
    alias Status = CapsuleApplicationStatus;
    struct Result {
        Status status = Status.Ok;
        string stdout = null;
        Timer compileTime;
        Timer linkTime;
        Timer runTime;
    }
    // Initialize some variables
    Result result;
    string objPaths = "";
    const cmdLogFlag = (
        silent ? "" :
        config.veryVerbose ? " -v" :
        !verbose ? " --silent" : ""
    );
    // Compile each source file
    foreach(source; test.sources) {
        const objPath = Path.join(outDir, source).toString() ~ ".cob";
        if(objPaths.length) objPaths ~= " ";
        objPaths ~= escapeArg(objPath);
        string compileCmd = (
            config.casmCommand ~ " " ~ source ~
            " -o " ~ escapeArg(objPath) ~
            (config.writeDebugInfo ? " -db" : "") ~
            cmdLogFlag ~ " " ~ test.casmArgs ~ "\0"
        );
        assert(compileCmd.length && compileCmd[$ - 1] == '\0');
        verboseln(compileCmd[0 .. $ - 1]);
        result.compileTime.start();
        const compileStatus = cast(Status) system(compileCmd.ptr);
        result.compileTime.suspend();
        if(compileStatus !is Status.Ok) {
            result.status = compileStatus;
            return result;
        }
    }
    // Link object files
    const programPath = (
        Path.join(outDir, test.name).toString() ~ ".capsule"
    );
    string linkCmd = (
        config.clinkCommand ~ " " ~ objPaths ~
        " -o " ~ escapeArg(programPath) ~
        (config.writeDebugInfo ? " -db" : "") ~
        cmdLogFlag ~ " " ~ test.clinkArgs
    );
    if(test.comment.length) {
        linkCmd ~= " --program-comment " ~ escapeArg(test.comment);
    }
    linkCmd ~= "\0";
    assert(linkCmd.length && linkCmd[$ - 1] == '\0');
    verboseln(linkCmd[0 .. $ - 1]);
    result.linkTime.start();
    const linkStatus = cast(Status) system(linkCmd.ptr);
    result.linkTime.end();
    if(linkStatus !is Status.Ok) {
        result.status = linkStatus;
        return result;
    }
    // Run the compiled program
    const stdoutPath = (
        Path.join(outDir, test.name).toString() ~ ".stdout.txt"
    );
    string runCmd = (
        config.capsuleCommand ~ " " ~ escapeArg(programPath) ~
        " --stdout-path " ~ escapeArg(stdoutPath) ~
        (config.veryVerbose && !silent ? " -v" : "") ~
        " " ~ test.capsuleArgs
    );
    if(test.stdin.length) {
        runCmd ~= " -in " ~ escapeArg(test.stdin);
    }
    runCmd ~= "\0";
    assert(runCmd.length && runCmd[$ - 1] == '\0');
    verboseln(runCmd[0 .. $ - 1]);
    result.runTime.start();
    const runStatus = cast(Status) system(runCmd.ptr);
    result.runTime.end();
    // Verify the output
    if(runStatus !is test.status) {
        if(test.status is Status.Ok) {
            result.status = runStatus;
            return result;
        }
        else {
            result.status = Status.CheckTestFailureWrongStatus;
            return result;
        }
    }
    const stdoutFile = File.read(stdoutPath);
    result.stdout = stdoutFile.content;
    if((!test.stdout.length && stdoutFile.ok) || (test.stdout.length && 
        (!stdoutFile.ok || stdoutFile.content != test.stdout)
    )) {
        result.status = Status.CheckTestFailureWrongOutput;
        return result;
    }
    // All done
    result.status = Status.Ok;
    return result;
}

version(CapsuleExcludeCheckerMain) {}
else int main(string[] args) {
    const status = check(args);
    return cast(int) status;
}
