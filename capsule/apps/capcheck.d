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
    alias Test = CapsuleCheckTest;
    alias TestCase = CapsuleCheckTestCase;
    
    enum string[] UsageText = [
        "Capsule check (capcheck) version " ~ CapsuleCheckVersionName,
        "Run a suite of tests against a Capsule implementation in",
        "order to verify its behavior.",
        "The first argument must be a path to a capcheck INI",
        "configuration file.",
        "Usage:",
        "  capcheck <ini-file> [<option>...]",
    ];
    
    @(CapsuleConfigAttribute!string("output", "o")
        .setOptional(null)
        .setHelpText([
            "Object and program files built from test sources",
            "will be saved inside this directory, as well as any",
            "logs or other outputted files."
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
            "Command or path to binary to use when compiling Capsule",
            "assembly source code files."
        ])
    )
    string casmCommand;
    
    @(CapsuleConfigAttribute!string("clink")
        .setOptional("clink")
        .setHelpText([
            "Command or path to binary to use when linking compiled",
            "Capsule object files."
        ])
    )
    string clinkCommand;
    
    @(CapsuleConfigAttribute!string("capsule")
        .setOptional("capsule")
        .setHelpText([
            "Command or path to binary to use for executing compiled",
            "Capsule program files."
        ])
    )
    string capsuleCommand;
    
    @(CapsuleConfigAttribute!(string[])("only")
        .setOptional(null)
        .setHelpText([
            "Run only those tests whose name is the same as the one",
            "or more strings given with this option. Do not run tests",
            "whose names are not listed."
        ])
    )
    string[] onlyTestNames;
    
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
            "When set, the checker will log quite a lot more messages",
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
    
    bool shouldRunTest(in Test test) {
        if(!this.onlyTestNames.length) {
            return true;
        }
        foreach(name; this.onlyTestNames) {
            if(test.hasNameMatch(name)) {
                return true;
            }
        }
        return false;
    }
    
    bool shouldRunTestCase(in Test test, in TestCase testCase) {
        if(!this.onlyTestNames.length) {
            return true;
        }
        foreach(name; this.onlyTestNames) {
            if(test.name == name || testCase.name == name) {
                return true;
            }
        }
        return false;
    }
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

void writems(in ulong milliseconds) {
    const seconds = milliseconds / 1000;
    const remainingMs = milliseconds % 1000;
    const msPadding = (
        remainingMs < 10 ? "00" :
        remainingMs < 100 ? "0" : ""
    );
    write(writeInt(seconds), ".", msPadding, writeInt(remainingMs), "s");
}

struct CapsuleCheckTest {
    alias Case = CapsuleCheckTestCase;
    alias Status = CapsuleApplicationStatus;
    
    string name = null;
    string comment = null;
    string[] sources = null;
    string casmArgs = null;
    string clinkArgs = null;
    Case[] cases = null;
    
    bool hasNameMatch(in string name) const {
        if(name == this.name) {
            return true;
        }
        foreach(testCase; this.cases) {
            if(name == testCase.name) {
                return true;
            }
        }
        return false;
    }
}

struct CapsuleCheckTestCase {
    alias Status = CapsuleApplicationStatus;
    
    string name = null;
    Status status = Status.Ok;
    string stdin = null;
    string stdout = null;
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
    // Put together a list of tests
    verboseln("Organizing tests and test cases.");
    CapsuleCheckTest[] tests;
    uint totalTestCases = 0;
    foreach(section; ini.sections) {
        // Sections marked "caseof" get added to Test objects
        if(section.get("caseof").length) {
            bool foundTest = false;
            foreach(ref test; tests) {
                if(test.name == section.get("caseof")) {
                    const expectStatus = (
                        getEnumMemberByName!Status(section.get("status"))
                    );
                    CapsuleCheckTestCase testCase = {
                        name: section.name,
                        stdin: section.get("stdin"),
                        stdout: section.get("stdout"),
                        capsuleArgs: section.get("capsuleargs"),
                        status: expectStatus,
                    };
                    foundTest = true;
                    test.cases ~= testCase;
                    totalTestCases++;
                    break;
                }
            }
            if(!foundTest) {
                writeln("Unmatched \"caseof\" setting in section: ", section.name);
            }
            continue;
        }
        // Otherwise add to the test list
        CapsuleCheckTest test = {
            name: section.name,
            comment: section.get("comment"),
            sources: section.all("source"),
            casmArgs: section.get("casmargs"),
            clinkArgs: section.get("clinkargs"),
        };
        if(section.get("stdin") || section.get("stdout") || section.get("status")) {
            const expectStatus = (
                getEnumMemberByName!Status(section.get("status"))
            );
            CapsuleCheckTestCase testCase = {
                name: section.name,
                stdin: section.get("stdin"),
                stdout: section.get("stdout"),
                capsuleArgs: section.get("capsuleargs"),
                status: expectStatus,
            };
            test.cases ~= testCase;
            totalTestCases++;
        }
        tests ~= test;
    }
    // Run the tests
    verboseln("Running tests.");
    uint testsPassed = 0;
    uint testsFailed = 0;
    foreach(test; tests) {
        // Handle tests with no cases
        if(!test.cases.length) {
            stdio.writeln("Test section has no cases: ", test.name);
            continue;
        }
        // Handle the --only CLI option filtering out this entire test
        if(!config.shouldRunTest(test)) {
            continue;
        }
        // Build the test program
        CapsuleCheckTestBuilder builder = {
            test: test,
            config: config,
            outDir: outDir,
        };
        builder.build();
        const buildms = (
            builder.compileTime.milliseconds + builder.linkTime.milliseconds
        );
        if(!builder.ok) {
            testsFailed += test.cases.length;
            const status = (builder.compileStatus ?
                builder.compileStatus : builder.linkStatus
            );
            const statusName = getEnumMemberName(status);
            write("BUILD FAIL: ", test.name ~ " (" ~ statusName ~ ") (");
            writems(buildms);
            writeln(")");
            testsFailed++;
            continue;
        }
        // Run each test program
        foreach(testCase; test.cases) {
            // Handle the --only CLI option filtering out this test case
            if(!config.shouldRunTestCase(test, testCase)) {
                continue;
            }
            // Run the test
            CapsuleCheckTestRunner runner = builder.getRunner(testCase);
            runner.run();
            // Display PASS/FAIL information
            if(runner.ok) {
                write("TEST PASS: ", testCase.name, " (");
                testsPassed++;
            }
            else {
                const statusName = getEnumMemberName(runner.status);
                write("TEST FAIL: ", testCase.name ~ " (" ~ statusName ~ ") (");
                testsFailed++;
            }
            writems(buildms + runner.runTime.milliseconds);
            writeln(")");
            // Display expected and actual stdout
            if(verbose) {
                verboseln("Expected stdout ", testCase.name,
                    " (", writeInt(testCase.stdout.length), " bytes):"
                );
                verboseln(testCase.stdout);
                verboseln("Actual stdout ", testCase.name,
                    " (", writeInt(runner.stdout.length), " bytes):"
                );
                verboseln(runner.stdout);
            }
        }
    }
    // Write summmary of test results
    verboseln("Finished running tests.");
    writeln(
        "Passed: ", writeInt(testsPassed), " of ", writeInt(totalTestCases)
    );
    if(testsFailed) {
        writeln("Failed: ", writeInt(testsFailed));
    }
    return testsFailed ? Status.CheckTestFailure : Status.Ok;
}

struct CapsuleCheckTestBuilder {
    alias Config = CapsuleCheckConfig;
    alias Runner = CapsuleCheckTestRunner;
    alias Status = CapsuleApplicationStatus;
    alias Test = CapsuleCheckTest;
    alias TestCase = CapsuleCheckTestCase;
    
    Test test;
    Config config;
    string outDir;
    
    Status compileStatus = Status.Ok;
    Status linkStatus = Status.Ok;
    string programPath = null;
    Timer compileTime;
    Timer linkTime;
    string linkCmd;
    
    bool ok() const {
        return this.compileStatus is Status.Ok && this.linkStatus is Status.Ok;
    }
    
    Runner getRunner(TestCase testCase) {
        Runner runner = {
            test: this.test,
            testCase: testCase,
            config: this.config,
            outDir: this.outDir,
            programPath: this.programPath,
        };
        return runner;
    }
    
    void build() {
        string objPaths = "";
        const cmdLogFlag = (
            silent ? " --silent" :
            this.config.veryVerbose ? " -v" :
            verbose ? "" : " --silent"
        );
        // Compile each source file
        foreach(source; this.test.sources) {
            const objPath = Path.join(this.outDir, source).toString() ~ ".cob";
            if(objPaths.length) objPaths ~= " ";
            objPaths ~= escapeArg(objPath);
            string compileCmd = (
                this.config.casmCommand ~ " " ~ source ~
                " -o " ~ escapeArg(objPath) ~
                (this.config.writeDebugInfo ? " -db" : "") ~
                cmdLogFlag ~ " " ~ this.test.casmArgs ~ "\0"
            );
            assert(compileCmd.length && compileCmd[$ - 1] == '\0');
            verboseln(compileCmd[0 .. $ - 1]);
            this.compileTime.start();
            this.compileStatus = cast(Status) system(compileCmd.ptr);
            this.compileTime.suspend();
            if(compileStatus !is Status.Ok) {
                return;
            }
        }
        // Link object files
        this.programPath = (
            Path.join(this.outDir, this.test.name).toString() ~ ".capsule"
        );
        this.linkCmd = (
            this.config.clinkCommand ~ " " ~ objPaths ~
            " -o " ~ escapeArg(this.programPath) ~
            (this.config.writeDebugInfo ? " -db" : "") ~
            cmdLogFlag ~ " " ~ this.test.clinkArgs
        );
        if(this.test.comment.length) {
            this.linkCmd ~= " --program-comment " ~ escapeArg(this.test.comment);
        }
        this.linkCmd ~= "\0";
        assert(this.linkCmd.length && this.linkCmd[$ - 1] == '\0');
        verboseln(this.linkCmd[0 .. $ - 1]);
        this.linkTime.start();
        this.linkStatus = cast(Status) system(this.linkCmd.ptr);
        this.linkTime.end();
    }
}

struct CapsuleCheckTestRunner {
    alias Builder = CapsuleCheckTestBuilder;
    alias Config = CapsuleCheckConfig;
    alias Status = CapsuleApplicationStatus;
    alias Test = CapsuleCheckTest;
    alias TestCase = CapsuleCheckTestCase;
    
    Test test;
    TestCase testCase;
    Config config;
    string outDir;
    
    Status runStatus = Status.Ok;
    string programPath = null;
    string runCmd;
    Timer runTime;
    File.Status stdoutReadStatus;
    string stdout;
    
    bool ok() const {
        return (
            this.runStatus is this.testCase.status &&
            this.stdout == this.testCase.stdout
        );
    }
    
    Status status() const {
        if(this.runStatus !is this.testCase.status) {
            if(this.runStatus is Status.Ok) {
                return Status.CheckTestFailureWrongStatus;
            }
            else {
                return this.runStatus;
            }
        }
        else if(this.stdout != this.testCase.stdout) {
            return Status.CheckTestFailureWrongOutput;
        }
        else {
            return Status.Ok;
        }
    }
    
    void run() {
        // Run the compiled program
        const stdoutPath = (
            Path.join(this.outDir, this.testCase.name).toString() ~ ".stdout.txt"
        );
        this.runCmd = (
            this.config.capsuleCommand ~ " " ~ escapeArg(programPath) ~
            " --stdout-path " ~ escapeArg(stdoutPath) ~
            (this.config.veryVerbose && !silent ? " -v" : "") ~
            " " ~ this.testCase.capsuleArgs
        );
        if(this.testCase.stdin.length) {
            this.runCmd ~= " -in " ~ escapeArg(this.testCase.stdin);
        }
        this.runCmd ~= "\0";
        assert(this.runCmd.length && this.runCmd[$ - 1] == '\0');
        verboseln(this.runCmd[0 .. $ - 1]);
        this.runTime.start();
        this.runStatus = cast(Status) system(this.runCmd.ptr);
        this.runTime.end();
        // Record the output
        const stdoutFile = File.read(stdoutPath);
        this.stdoutReadStatus = stdoutFile.status;
        this.stdout = stdoutFile.content;
    }
}

version(CapsuleExcludeCheckerMain) {}
else int main(string[] args) {
    const status = check(args);
    return cast(int) status;
}
