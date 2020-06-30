/**

Main file for the Capsule implementation check utility (capcheck).

The check utility can be used to verify the integrity of a Capsule
toolchain and virtual machine by compiling and linking a number of
test programs from their sources, running them in a Capsule virtual
machine, and then verifying that the program's behavior and output
matched what was expected for that program.

*/

module capsule.apps.capcheck;

private:

import capsule.encode.config : CapsuleConfigAttribute, CapsuleConfigStatus;
import capsule.encode.config : loadCapsuleConfig, capsuleConfigStatusToString;
import capsule.encode.config : getCapsuleConfigUsageString;

import capsule.algorithm.indexof : lastIndexOf;
import capsule.encode.ini : Ini;
import capsule.io.file : File;
import capsule.io.path : Path;
import capsule.io.stdio : stdio;
import capsule.meta.enums : getEnumMemberName, getEnumMemberByName;
import capsule.string.hex : getByteHexString;
import capsule.string.writeint : writeInt;
import capsule.system.process : runProcess, getRunProcessString;
import capsule.time.timer : Timer;

import capsule.apps.lib.status : CapsuleApplicationStatus;

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
            "logs or other outputted files.",
        ])
    )
    string outputPath;
    
    @(CapsuleConfigAttribute!bool("debug", "db")
        .setOptional(false)
        .setHelpText([
            "When this flag is set, debugging information will be",
            "included in the outputted object and program files.",
        ])
    )
    bool writeDebugInfo;
    
    @(CapsuleConfigAttribute!string("asm-command")
        .setOptional("casm")
        .setHelpText([
            "Command or path to binary to use when compiling Capsule",
            "assembly source code files.",
        ])
    )
    string asmCommand;
    
    @(CapsuleConfigAttribute!string("link-command")
        .setOptional("clink")
        .setHelpText([
            "Command or path to binary to use when linking compiled",
            "Capsule object files.",
        ])
    )
    string linkCommand;
    
    @(CapsuleConfigAttribute!string("run-command")
        .setOptional("capsule")
        .setHelpText([
            "Command or path to binary to use for executing compiled",
            "Capsule program files.",
        ])
    )
    string runCommand;
    
    @(CapsuleConfigAttribute!(string[])("only")
        .setOptional(null)
        .setHelpText([
            "Run only those tests whose name is the same as the one",
            "or more strings given with this option. Do not run tests",
            "whose names are not listed.",
        ])
    )
    string[] onlyTestNames;
    
    @(CapsuleConfigAttribute!bool("list")
        .setOptional(false)
        .setHelpText([
            "When this flag is set, the program will list the tests",
            "given in the loaded configuration file without actually",
            "running any of them.",
        ])
    )
    bool listTests;
    
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
    string[] asmArgs = null;
    string[] linkArgs = null;
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
    // Set up a logger for use during INI config file loading
    void onLogMessage(in Ini.Parser.Log.Message message) {
        if(verbose || message.severity > Ini.Parser.Log.Severity.Debug) {
            writeln(message.toString());
        }
    }
    auto log = Ini.Parser.Log(&onLogMessage);
    // Load and parse the INI file
    auto iniFile = File.read(iniPath);
    if(!iniFile.ok) {
        writeln("Error reading test configuration INI file.");
        return Status.ConfigFileReadError;
    }
    auto iniParser = Ini.Parser(&log, iniFile);
    iniParser.parse();
    if(!iniParser.ok) {
        writeln("Error parsing test configuration INI file.");
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
        // Sections marked "case-of" get added to Test objects
        if(section.get("case-of").length) {
            bool foundTest = false;
            foreach(ref test; tests) {
                if(test.name == section.get("case-of")) {
                    const expectStatus = (
                        getEnumMemberByName!Status(section.get("status"))
                    );
                    CapsuleCheckTestCase testCase = {
                        name: section.name,
                        stdin: section.get("stdin"),
                        stdout: section.get("stdout"),
                        capsuleArgs: section.get("capsule-args"),
                        status: expectStatus,
                    };
                    foundTest = true;
                    test.cases ~= testCase;
                    totalTestCases++;
                    break;
                }
            }
            if(!foundTest) {
                writeln("Unmatched \"case-of\" setting in section: ", section.name);
            }
            continue;
        }
        // Otherwise add to the test list
        CapsuleCheckTest test = {
            name: section.name,
            comment: section.get("comment"),
            sources: section.all("source"),
            asmArgs: section.all("casm-args"),
            linkArgs: section.all("clink-args"),
        };
        if(section.get("stdin") || section.get("stdout") || section.get("status")) {
            const expectStatus = (
                getEnumMemberByName!Status(section.get("status"))
            );
            CapsuleCheckTestCase testCase = {
                name: section.name,
                stdin: section.get("stdin"),
                stdout: section.get("stdout"),
                capsuleArgs: section.get("capsule-args"),
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
        // Handle the --list-tests CLI option which displays all the
        // tests without actually running any of them
        if(config.listTests) {
            if(test.cases.length == 1 && test.cases[0].name == test.name) {
                writeln(test.name);
            }
            else {
                foreach(testCase; test.cases) {
                    writeln(test.name, "/", testCase.name);
                }
            }
            continue;
        }
        // Build the test program
        CapsuleCheckTestBuilder builder = {
            test: test,
            config: config,
            iniDir: iniDir,
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
            else if(testCase.status is Status.Ok) {
                const statusName = getEnumMemberName(runner.status);
                write("TEST FAIL: ", testCase.name, " (Error status: ",
                    getByteHexString(cast(ubyte) runner.status)
                );
                if(statusName.length) {
                    write(", ", statusName);
                }
                write(") (");
                testsFailed++;
            }
            else {
                const statusName = getEnumMemberName(runner.runStatus);
                write("TEST FAIL: ", testCase.name, " (Wrong status: ",
                    getByteHexString(cast(ubyte) runner.runStatus), ", ",
                    statusName,
                ") (");
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
    if(!config.listTests) {
        verboseln("Finished running tests.");
        writeln(
            "Passed: ", writeInt(testsPassed), " of ", writeInt(totalTestCases)
        );
        if(testsFailed) {
            writeln("Failed: ", writeInt(testsFailed));
        }
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
    string iniDir;
    string outDir;
    
    Status compileStatus = Status.Ok;
    Status linkStatus = Status.Ok;
    string programPath = null;
    Timer compileTime;
    Timer linkTime;
    
    bool ok() const {
        return this.compileStatus is Status.Ok && this.linkStatus is Status.Ok;
    }
    
    Runner getRunner(TestCase testCase) {
        Runner runner = {
            test: this.test,
            testCase: testCase,
            config: this.config,
            iniDir: this.iniDir,
            outDir: this.outDir,
            programPath: this.programPath,
        };
        return runner;
    }
    
    void build() {
        string[] objPaths;
        const cmdLogFlag = (
            silent ? "--silent" :
            this.config.veryVerbose ? "-v" :
            verbose ? null : "--silent"
        );
        // Compile each source file
        foreach(source; this.test.sources) {
            const srcPath = Path.join(this.iniDir, source).toString();
            const objPath = Path.join(this.outDir, source).toString() ~ ".cob";
            objPaths ~= objPath;
            string[] compileArgs = [
                srcPath,
                "-o", objPath,
                cmdLogFlag,
                (this.config.writeDebugInfo ? "-db" : null),
            ] ~ this.test.asmArgs;
            verboseln(getRunProcessString(
                this.config.asmCommand, compileArgs
            ));
            this.compileTime.start();
            this.compileStatus = cast(Status) runProcess(
                this.config.asmCommand, compileArgs
            );
            this.compileTime.suspend();
            if(compileStatus !is Status.Ok) {
                return;
            }
        }
        // Link object files
        this.programPath = (
            Path.join(this.outDir, this.test.name).toString() ~ ".capsule"
        );
        string[] linkArgs = objPaths ~ [
            "-o", this.programPath,
            (this.config.writeDebugInfo ? "-db" : null),
            cmdLogFlag,
        ];
        if(this.test.comment.length) {
            linkArgs ~= ["--program-comment", this.test.comment];
        }
        linkArgs ~= this.test.linkArgs;
        verboseln(getRunProcessString(
            this.config.linkCommand, linkArgs
        ));
        this.linkTime.start();
        this.linkStatus = cast(Status) runProcess(
            this.config.linkCommand, linkArgs
        );
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
    string iniDir;
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
        // this.config.capsuleCommand
        string[] runArgs = [
            programPath,
            "--stdout-path", stdoutPath,
            (this.config.veryVerbose && !silent ? "-v" : null),
        ];
        if(this.testCase.stdin.length) {
            runArgs ~= ["-in", this.testCase.stdin];
        }
        runArgs ~= this.testCase.capsuleArgs;
        verboseln(getRunProcessString(
            this.config.runCommand, runArgs
        ));
        this.runTime.start();
        this.runStatus = cast(Status) runProcess(
            this.config.runCommand, runArgs
        );
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
