/**

Main file for the Capsule assembler (casm).

This program is used to compile Capsule assembly source code, producing
a Capsule object file.

Object files produced by the Capsule assembler or some other utility can
be linked togther to produce a Capsule program file using the Capsule
linker (clink).

https://en.wikipedia.org/wiki/Assembly_language

*/

module capsule.apps.casm;

private:

import capsule.encode.config : CapsuleConfigAttribute, CapsuleConfigStatus;
import capsule.encode.config : loadCapsuleConfig, capsuleConfigStatusToString;
import capsule.encode.config : getCapsuleConfigUsageString;

import capsule.algorithm.indexof : lastIndexOf;
import capsule.io.file : File;
import capsule.io.filesystem : isDirectory, ensureDirectory;
import capsule.io.path : Path;
import capsule.io.stdio : stdio;
import capsule.meta.enums : getEnumMemberAttribute;

import capsule.core.encoding : CapsuleTextEncoding, CapsuleTimeEncoding;
import capsule.core.obj : CapsuleObject;
import capsule.core.objencode : CapsuleObjectEncoder;
import capsule.core.objstring : capsuleObjectToString;

import capsule.casm.compile : CapsuleAsmCompiler;
import capsule.casm.syntaxstring : capsuleAsmNodeToString;

import capsule.apps.lib.status : CapsuleApplicationStatus;

public:

enum string CapsuleAssemblerVersionName = "20200514";

enum string CapsuleObjectFileExtension = "cob";

enum string CapsuleObjectFileDefaultName = "object.cob";

struct CapsuleAssemblerConfig {
    alias SourceEncoding = CapsuleObject.Source.Encoding;
    alias TextEncoding = CapsuleTextEncoding;
    alias TimeEncoding = CapsuleTimeEncoding;
    
    alias TextEncodingName = CapsuleConfigAttribute!TextEncoding.EnumName;
    alias TimeEncodingName = CapsuleConfigAttribute!TimeEncoding.EnumName;
    alias SourceEncodingName = CapsuleConfigAttribute!SourceEncoding.EnumName;
    
    enum string[] UsageText = [
        "Capsule assembler (casm) version " ~ CapsuleAssemblerVersionName,
        "Compile Capsule assembly source code to Capsule object files.",
        "Usage:",
        "  casm <file>... [<option>...]",
    ];
    
    @(CapsuleConfigAttribute!(string[])("input", "i")
        .setOptional(null)
        .setHelpText([
            "Accepts one or more file path strings.",
            "Concatenate and compile the assembly source files found",
            "at these paths.",
            "Paths specified with the -i option are added after paths",
            "given at the beginning of the argument list.",
        ])
    )
    string[] inputPaths;
    
    @(CapsuleConfigAttribute!string("output", "o")
        .setOptional(null)
        .setHelpText([
            "Write object file output to this path.",
            "Replaces the first input path file extension with *.cob",
            "and writes to that destination when not specified."
        ])
    )
    string outputPath;
    
    @(CapsuleConfigAttribute!(string[])("include-dirs", "I")
        .setOptional(null)
        .setHelpText([
            "Accepts one or more directory file path strings.",
            "When an .incbin or .include directive is encountered",
            "using a relative file path, first the assembler will",
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
            "included in the outputted object file."
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
    
    @(CapsuleConfigAttribute!bool("verbose", "v")
        .setOptional(false)
        .setHelpText([
            "When set, the assembler will log more messages than usual.",
        ])
    )
    bool verbose;
    
    @(CapsuleConfigAttribute!bool("silent")
        .setOptional(false)
        .setHelpText([
            "When set, the assembler will log no messages.",
        ])
    )
    bool silent;
    
    @(CapsuleConfigAttribute!bool("print-object")
        .setOptional(false)
        .setHelpText([
            "When set, a string representation of the compiled object",
            "will be logged to standard output before it is written",
            "to an object file.",
        ])
    )
    bool printObject;
    
    @(CapsuleConfigAttribute!bool("print-syntax-nodes")
        .setOptional(false)
        .setHelpText([
            "When set, a string representation of the parsed assembly",
            "source code files will be logged to standard output.",
        ])
    )
    bool printSyntaxNodes;
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

string getDefaultOutputPath(in string inputPath) {
    if(!inputPath.length) {
        return CapsuleObjectFileDefaultName;
    }
    const dotIndex = lastIndexOf(inputPath, '.');
    if(dotIndex > 0) {
        return inputPath[0 .. 1 + dotIndex] ~ CapsuleObjectFileExtension;
    }
    else {
        return inputPath ~ "." ~ CapsuleObjectFileExtension;
    }
}

CapsuleApplicationStatus compile(string[] args) {
    alias Config = CapsuleAssemblerConfig;
    alias Status = CapsuleApplicationStatus;
    enum string VersionName = CapsuleAssemblerVersionName;
    // Handle --help or --version
    if(args.length <= 1 || args[1] == "--help") {
        writeln(getCapsuleConfigUsageString!Config());
        return Status.Ok;
    }
    else if(args[1] == "--version") {
        writeln("Capsule assembler (casm) version ", VersionName);
        return Status.Ok;
    }
    // Starting args without '-' are interpreted as input paths
    size_t argIndex = 1;
    while(argIndex < args.length && args[argIndex].length && args[argIndex][0] != '-') {
        argIndex++;
    }
    string[] inputPaths = args[1 .. argIndex];
    // Get configuration options
    auto configResult = loadCapsuleConfig!Config(args[argIndex .. $]);
    auto config = configResult.config;
    verbose = configResult.config.verbose;
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
    // Read the input files
    verboseln("Reading from input file paths.");
    inputPaths ~= config.inputPaths;
    if(!inputPaths.length) {
        writeln("No input file paths were specified.");
        writeln("At least one input file path must be given.");
        return Status.ConfigInvalidOptionValueError;
    }
    File[] sources = new File[inputPaths.length];
    for(size_t i = 0; i < inputPaths.length; i++) {
        assert(inputPaths[i].length);
        sources[i] = File.read(inputPaths[i]);
        if(!sources[i].ok) {
            writeln("Error reading source from path ", sources[i].path);
            return Status.SourceFileReadError;
        }
    }
    // Set up a logger for use during compilation
    void onLogMessage(in CapsuleAsmCompiler.Log.Message message) {
        if(verbose || message.severity > CapsuleAsmCompiler.Log.Severity.Debug) {
            writeln(message.toString());
        }
    }
    auto log = CapsuleAsmCompiler.Log(&onLogMessage);
    // Do the compiling
    verboseln("Compiling from sources.");
    auto compiler = CapsuleAsmCompiler(&log, sources);
    compiler.doWriteDebugInfo = config.writeDebugInfo;
    compiler.objectSourceEncoding = config.objectSourceEncoding;
    compiler.includePaths = config.includePaths;
    compiler.compile();
    if(!compiler.ok) {
        writeln("Compilation error.");
        return Status.CompileError;
    }
    if(config.printSyntaxNodes) {
        writeln("Listing of parsed syntax nodes:");
        foreach(node; compiler.nodes) {
            writeln(capsuleAsmNodeToString(node));
        }
    }
    // Encode the object data
    verboseln("Encoding the compiled object data.");
    ubyte[] encodedObject;
    void writeByte(in ubyte value) {
        encodedObject ~= value;
    }
    auto objectEncoder = CapsuleObjectEncoder(&writeByte);
    objectEncoder.write(compiler.object);
    if(!objectEncoder.ok) {
        writeln("Error encoding object file data.");
        return Status.ObjectEncodeError;
    }
    // Determine object file path
    string outputPath;
    if(config.outputPath && config.outputPath.length) {
        outputPath = config.outputPath;
    }
    else {
        assert(inputPaths.length);
        outputPath = getDefaultOutputPath(inputPaths.length ? inputPaths[0] : "");
    }
    // Ensure the object file directory exists
    verboseln("Ensuring object file output directory exists.");
    const outputDir = Path(outputPath).dirName;
    if(!isDirectory(outputDir)) {
        verboseln("Creating output directory ", outputDir);
        const dirStatus = ensureDirectory(outputDir);
        if(!dirStatus) {
            writeln("Failed to create output directory ", outputDir);
            return Status.ObjectFileWriteError;
        }
    }
    // Write the object file
    verboseln("Writing object file to the output path.");
    auto outputFile = File(outputPath, cast(string) encodedObject);
    const outputFileStatus = outputFile.write();
    if(outputFileStatus) {
        writeln("Failed to write object data to file path ", outputPath);
        return Status.ObjectFileWriteError;
    }
    if(config.writeDebugInfo) {
        writeln("Wrote object data with debug info to ", outputPath);
    }
    else {
        writeln("Wrote object data to ", outputPath);
    }
    // If the verbose flag was set, write a stringification of the
    // object file to stdout
    if(config.printObject) {
        writeln("String representation of written object file:");
        writeln(capsuleObjectToString(compiler.object));
    }
    // All done
    return Status.Ok;
}

version(CapsuleExcludeAssemblerMain) {}
else int main(string[] args) {
    const status = compile(args);
    return cast(int) status;
}
