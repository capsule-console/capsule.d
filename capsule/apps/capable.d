/**

Main file for the Capsule automated builder (capable).

This build utility can be used to automate a project's compilation and
linking steps that might otherwise need to be performed separately using
the Capsule assembler (casm) and linker (clink).

*/

module capsule.apps.capable;

private:

import core.stdc.stdlib : system;

import capsule.parse.config : CapsuleConfigAttribute, CapsuleConfigStatus;
import capsule.parse.config : loadCapsuleConfig, capsuleConfigStatusToString;
import capsule.parse.config : getCapsuleConfigUsageString;

import capsule.io.file : File;
import capsule.io.path : Path;
import capsule.io.stdio : stdio;
import capsule.meta.enums : getEnumMemberAttribute;
import capsule.parse.ini : Ini;
import capsule.string.substring : endsWith;
import capsule.string.writeint : writeInt;
import capsule.system.process : runProcess, getRunProcessString;

import capsule.core.encoding : CapsuleTextEncoding, CapsuleTimeEncoding;
import capsule.core.obj : CapsuleObject;

import capsule.apps.lib.status : CapsuleApplicationStatus;

public:

enum string CapsuleBuildVersionName = "20200514";

enum string CapsuleAssemblyFileExtension = "casm";

enum string CapsuleObjectFileExtension = "cob";

enum string CapsuleProgramFileExtension = "capsule";

struct CapsuleBuildConfig {
    alias SourceEncoding = CapsuleObject.Source.Encoding;
    alias TextEncoding = CapsuleTextEncoding;
    alias TimeEncoding = CapsuleTimeEncoding;
    
    alias TextEncodingName = CapsuleConfigAttribute!TextEncoding.EnumName;
    alias TimeEncodingName = CapsuleConfigAttribute!TimeEncoding.EnumName;
    alias SourceEncodingName = CapsuleConfigAttribute!SourceEncoding.EnumName;
    
    enum string[] UsageText = [
        "Capsule automated builder (capable) version " ~ CapsuleBuildVersionName,
        "Build and link a source or set of sources and all of their",
        "dependencies.",
        "Usage:",
        "  capable <file>... [<option>...]",
    ];
    
    @(CapsuleConfigAttribute!string("project", "p")
        .setOptional(null)
        .setHelpText([
            "Load configuration from an INI project file."
        ])
    )
    string projectPath;
    
    @(CapsuleConfigAttribute!(string[])("input", "i")
        .setOptional(null)
        .setHelpText([
            "Accepts one or more file path strings.",
            "Compile and link the files found at these file paths",
            "as well as all of the sources that they indicate as",
            "dependencies.",
            "Input file type is determined by file extension.",
            "Paths specified with the -i option are added after paths",
            "given at the beginning of the argument list.",
        ])
    )
    string[] inputPaths;
    
    @(CapsuleConfigAttribute!(string[])("asm", "a")
        .setOptional(null)
        .setHelpText([
            "Accepts one or more Capsule assembly file path strings.",
            "Compile and link the files found at these file paths",
            "as well as all of the sources that they indicate as",
            "dependencies.",
        ])
    )
    string[] asmPaths;
    
    @(CapsuleConfigAttribute!(string[])("object", "ob")
        .setOptional(null)
        .setHelpText([
            "Accepts one or more Capsule object file path strings.",
            "Include the files found at these file paths when linking.",
        ])
    )
    string[] linkPaths;
    
    @(CapsuleConfigAttribute!string("output", "o")
        .setOptional(null)
        .setHelpText([
            "Write program file output to this path.",
            "Replaces the first input path file extension with *.capsule",
            "and writes to that destination when not specified."
        ])
    )
    string outputPath;
    
    // TODO: Incremental compilation looks here for files already built
    // with the correct settings
    @(CapsuleConfigAttribute!string("objects-dir", "od")
        .setOptional(null)
        .setHelpText([
            "Intermediate files created during compilation, such as",
            "object files, will be written to this path instead of to",
            "the same directory location as the source files.",
        ])
    )
    string objectsPath;
    
    @(CapsuleConfigAttribute!(string[])("include-dirs", "I")
        .setOptional(null)
        .setHelpText([
            "Accepts one or more directory file path strings.",
            "When an include or import statements is encountered",
            "using a relative file path, first the build process will",
            "look for the file relative to the including file, then",
            "it will look relative to each of these directory paths",
            "from first to last to try to resolve the relative path."
        ])
    )
    string[] includePaths;
    
    @(CapsuleConfigAttribute!bool("debug", "db")
        .setOptional(false)
        .setHelpText([
            "When this flag is set, debugging information will be",
            "included in the outputted object and program files."
        ])
    )
    bool writeDebugInfo;
    
    @(CapsuleConfigAttribute!TextEncoding("text-encoding")
        .setOptional(TextEncoding.UTF8)
        .setHelpText([
            "Source files will be handled using this text encoding",
            "and the outputted object and program files will indicate",
            "that the text in it uses this text encoding."
        ])
        .setEnumNames([
            TextEncodingName(
                TextEncoding.None,
                getEnumMemberAttribute!string(TextEncoding.None)
            ),
            TextEncodingName(
                TextEncoding.Ascii,
                getEnumMemberAttribute!string(TextEncoding.Ascii)
            ),
            TextEncodingName(
                TextEncoding.UTF8,
                getEnumMemberAttribute!string(TextEncoding.UTF8)
            ),
        ])
    )
    TextEncoding textEncoding = TextEncoding.None;
    
    @(CapsuleConfigAttribute!TimeEncoding("time-encoding")
        .setOptional(TimeEncoding.UnixEpochSeconds)
        .setHelpText([
            "Output object and program files will use this timestamp",
            "encoding."
        ])
        .setEnumNames([
            TimeEncodingName(
                TimeEncoding.None,
                getEnumMemberAttribute!string(TimeEncoding.None)
            ),
            TimeEncodingName(
                TimeEncoding.UnixEpochSeconds,
                getEnumMemberAttribute!string(TimeEncoding.UnixEpochSeconds)
            ),
        ])
    )
    TimeEncoding timeEncoding = TimeEncoding.None;
    
    @(CapsuleConfigAttribute!SourceEncoding("source-encoding")
        .setOptional(SourceEncoding.CapsuleLZ77)
        .setHelpText([
            "When sources are included, output object file will",
            "use this encoding or compression scheme for compiled",
            "source code.",
        ])
        .setEnumNames([
            SourceEncodingName(
                SourceEncoding.None,
                getEnumMemberAttribute!string(SourceEncoding.None)
            ),
            SourceEncodingName(
                SourceEncoding.CapsuleLZ77,
                getEnumMemberAttribute!string(SourceEncoding.CapsuleLZ77)
            ),
        ])
    )
    SourceEncoding objectSourceEncoding = SourceEncoding.CapsuleLZ77;
    
    @(CapsuleConfigAttribute!string("program-title")
        .setOptional(null)
        .setHelpText([
            "Canonical program title to be saved in the program file. ",
            "Ideally, no two programs should share the same canonical title. ",
            "Program authors are encouraged to include attribution, date, ",
            "and version information in their program title."
        ])
    )
    string programTitle = null;
    
    @(CapsuleConfigAttribute!string("program-credit")
        .setOptional(null)
        .setHelpText([
            "Describe the author, copyright, or any other related",
            "information crediting those responsible for the program."
        ])
    )
    string programCredit = null;
    
    @(CapsuleConfigAttribute!string("program-comment")
        .setOptional(null)
        .setHelpText([
            "Comment to include in the program data.",
            "The comment is intended for other applications to store",
            "and retrieve freeform metadata regarding the program file."
        ])
    )
    string programComment = null;
    
    @(CapsuleConfigAttribute!string("asm-command")
        .setOptional("casm")
        .setHelpText([
            "Command or path to binary to use when compiling Capsule",
            "assembly source code files."
        ])
    )
    string asmCommand;
    
    @(CapsuleConfigAttribute!string("link-command")
        .setOptional("clink")
        .setHelpText([
            "Command or path to binary to use when linking compiled",
            "Capsule object files."
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
    
    @(CapsuleConfigAttribute!bool("run")
        .setOptional(false)
        .setHelpText([
            "When this flag is set, upon successfully building an",
            "output Capsule program it will immediately be run."
        ])
    )
    bool runOutputProgram;
    
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
}

bool verbose = false;
bool silent = false;

void verboseln(T...)(lazy T args) {
    if(silent || !verbose) return;
    stdio.writeln(args);
}

void writeln(T...)(lazy T args) {
    if(silent) return;
    stdio.writeln(args);
}

CapsuleApplicationStatus build(string[] args) {
    alias Config = CapsuleBuildConfig;
    alias Status = CapsuleApplicationStatus;
    enum string VersionName = CapsuleBuildVersionName;
    // Handle --help or --version
    if(args.length <= 1 || args[1] == "--help") {
        writeln(getCapsuleConfigUsageString!Config());
        return Status.Ok;
    }
    else if(args[1] == "--version") {
        writeln("Capsule automated builder (capable) version ", VersionName);
        return Status.Ok;
    }
    // Starting args without '-' are interpreted as input paths
    // If the first input path ends with ".ini" then it is treated as
    // an INI project file path.
    size_t argIndex = 1;
    while(argIndex < args.length && args[argIndex].length && args[argIndex][0] != '-') {
        argIndex++;
    }
    string projectPath = (
        argIndex > 1 && args[1].endsWith(".ini") ? args[1] : null
    );
    string[] inputPaths = args[(projectPath.length ? 2 : 1) .. argIndex];
    // Quick check for the presence of a --silent or --project argument
    for(size_t i = argIndex; i < args.length; i++) {
        const string arg = args[i];
        if(arg == "--silent") {
            silent = true;
        }
        else if(arg == "--project" && i < args.length - 1) {
            projectPath = args[i + 1];
        }
    }
    // Set up a logger for use during INI project file loading
    void onLogMessage(in Ini.Parser.Log.Message message) {
        if(verbose || message.severity > Ini.Parser.Log.Severity.Debug) {
            writeln(message.toString());
        }
    }
    auto log = Ini.Parser.Log(&onLogMessage);
    // Load project file INI, if one was specified
    File projectIniFile;
    Ini.Parser projectIniParser;
    if(projectPath.length) {
        writeln("Loading project file: ", projectPath);
        projectIniFile = File.read(projectPath);
        if(!projectIniFile.ok) {
            writeln("Error reading project configuration INI file.");
            return Status.ConfigFileReadError;
        }
        projectIniParser = Ini.Parser(&log, projectIniFile);
        projectIniParser.parse();
        if(!projectIniParser.ok) {
            writeln("Error parsing project configuration INI file.");
            return Status.ConfigFileParseError;
        }
    }
    // Get configuration options
    auto configResult = loadCapsuleConfig!Config(
        args[argIndex .. $], projectIniParser.ini.globals
    );
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
    // Do the building
    inputPaths ~= config.inputPaths;
    if(!inputPaths.length &&
        !config.asmPaths.length && !config.linkPaths.length
    ) {
        writeln("No input file paths were specified.");
        writeln("At least one input file path must be given.");
        return Status.ConfigInvalidOptionValueError;
    }
    CapsuleBuilder builder = {
        config: config,
        inputPaths: inputPaths,
    };
    builder.buildAll();
    if(!builder.ok) {
        writeln("Build failed.");
        return builder.status;
    }
    else {
        verboseln("Build completed.");
    }
    if(config.runOutputProgram && builder.status is Status.Ok) {
        stdio.flush();
        return cast(Status) runProcess(
            config.runCommand, [builder.programPath]
        );
    }
    else {
        return builder.status;
    }
}

struct CapsuleBuilder {
    alias Config = CapsuleBuildConfig;
    alias Status = CapsuleApplicationStatus;
    
    enum AssemblyDotExtension = "." ~ CapsuleAssemblyFileExtension;
    enum ObjectDotExtension = "." ~ CapsuleObjectFileExtension;
    enum ProgramDotExtension = "." ~ CapsuleProgramFileExtension;
    
    Status status = Status.Ok;
    Config config;
    string[] inputPaths = null;
    string[] objectPaths = null;
    string programPath = null;
    
    bool ok() const {
        return this.status is Status.Ok;
    }
    
    /// Get the logging flag ("--silent", "--verbose"/"-v", or none)
    /// that should be passed to spawned processes.
    string getLoggingFlag() const {
        return (
            silent ? "--silent" :
            this.config.veryVerbose ? "-v" : null
        );
    }
    
    /// Given a source file path, determine where a compiled object file
    /// should be saved to.
    string getObjectPath(in string sourcePath) const {
        return this.getOutputPath(sourcePath, ObjectDotExtension);
    }
    
    string getOutputPath(in string sourcePath, in string ext) const {
        return (this.config.objectsPath.length ?
            Path.join(this.config.objectsPath, sourcePath ~ ext).toString() :
            sourcePath ~ ext
        );
    }
    
    /// Get the path that the output program should be written to.
    string getProgramPath() const {
        enum Extension = ProgramDotExtension;
        if(this.config.outputPath.length) {
            return this.config.outputPath;
        }
        else if(this.inputPaths.length) {
            const first = this.inputPaths[0];
            return Path(first).stripExt.toString() ~ Extension;
        }
        else if(this.config.asmPaths.length) {
            const first = this.config.asmPaths[0];
            return Path(first).stripExt.toString() ~ Extension;
        }
        else if(this.config.linkPaths.length) {
            const first = this.config.linkPaths[0];
            return Path(first).stripExt.toString() ~ Extension;
        }
        else {
            assert(false);
        }
    }
    
    void buildAll() {
        assert(this.inputPaths.length ||
            this.config.asmPaths.length || this.config.linkPaths.length
        );
        this.programPath = this.getProgramPath();
        this.buildAllInputFiles();
        if(this.ok) {
            this.linkObjectFiles();
        }
    }
    
    void linkObjectFiles() {
        assert(this.ok);
        assert(this.programPath);
        verboseln("Linking ", writeInt(this.objectPaths.length), " object files.");
        string[] linkArgs = this.objectPaths ~ [
            "-o", this.programPath,
            (this.config.writeDebugInfo ? "-db" : null),
            this.getLoggingFlag(),
        ];
        if(this.config.programTitle.length) {
            linkArgs ~= ["--program-title", this.config.programTitle];
        }
        if(this.config.programCredit.length) {
            linkArgs ~= ["--program-credit", this.config.programCredit];
        }
        if(this.config.programComment.length) {
            linkArgs ~= ["--program-comment", this.config.programComment];
        }
        verboseln(getRunProcessString(
            this.config.linkCommand, linkArgs
        ));
        const linkStatus = cast(Status) runProcess(
            this.config.linkCommand, linkArgs
        );
        this.status = linkStatus;
    }
    
    void buildAllInputFiles() {
        assert(this.ok);
        const srcFileCount = (
            this.inputPaths.length +
            this.config.asmPaths.length +
            this.config.linkPaths.length
        );
        verboseln("Building ", writeInt(srcFileCount), " input files.");
        foreach(inputPath; this.inputPaths) {
            if(inputPath.endsWith(AssemblyDotExtension)) {
                this.buildAsmFile(inputPath);
                if(!this.ok) return;
            }
            else if(inputPath.endsWith(ObjectDotExtension)) {
                this.objectPaths ~= inputPath;
            }
            else {
                const ext = Path(inputPath).extName;
                writeln("Unrecognized file extension \"", ext, "\".");
                this.status = CapsuleApplicationStatus.BuildError;
                return;
            }
        }
        foreach(asmPath; this.config.asmPaths) {
            this.buildAsmFile(asmPath);
            if(!this.ok) return;
        }
        foreach(objectPath; this.config.linkPaths) {
            this.objectPaths ~= objectPath;
        }
    }
    
    auto buildAsmFile(in string inputPath) {
        // TODO: .import directives
        verboseln("Compiling assembly source file ", inputPath);
        string objectPath = getObjectPath(inputPath);
        this.objectPaths ~= objectPath;
        const textEncoding = (
            getEnumMemberAttribute!string(this.config.textEncoding)
        );
        const timeEncoding = (
            getEnumMemberAttribute!string(this.config.timeEncoding)
        );
        const sourceEncoding = (
            getEnumMemberAttribute!string(this.config.objectSourceEncoding)
        );
        string[] compileArgs = [
            inputPath,
            "-o", objectPath,
            "--text-encoding", textEncoding,
            "--time-encoding", timeEncoding,
            "--source-encoding", sourceEncoding,
            (this.config.writeDebugInfo ? "-db" : null),
            this.getLoggingFlag(),
        ];
        if(this.config.includePaths.length) {
            compileArgs ~= "-I";
            compileArgs ~= this.config.includePaths;
        }
        verboseln(getRunProcessString(
            this.config.asmCommand, compileArgs
        ));
        const compileStatus = cast(Status) runProcess(
            this.config.asmCommand, compileArgs
        );
        this.status = compileStatus;
    }
}

version(CapsuleExcludeBuilderMain) {}
else int main(string[] args) {
    const status = build(args);
    return cast(int) status;
}
