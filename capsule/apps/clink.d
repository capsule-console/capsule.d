/**

Main file for the Capsule linker (clink).

This program is used to link together compiled Capsule object files in
order to produce a Capsule program file that can be run by a virtual
machine.

https://en.wikipedia.org/wiki/Linker_(computing)

*/

module capsule.apps.clink;

private:

import capsule.encode.config : CapsuleConfigAttribute, CapsuleConfigStatus;
import capsule.encode.config : loadCapsuleConfig, capsuleConfigStatusToString;
import capsule.encode.config : getCapsuleConfigUsageString;

import capsule.algorithm.indexof : lastIndexOf;
import capsule.io.file : File;
import capsule.io.filesystem : isDirectory, ensureDirectory;
import capsule.io.path : Path;
import capsule.io.stdio : stdio;

import capsule.core.encoding : CapsuleTextEncoding, CapsuleTimeEncoding;
import capsule.core.obj : CapsuleObject;
import capsule.core.objencode : CapsuleObjectDecoder;
import capsule.core.programencode : CapsuleProgramEncoder;
import capsule.core.programstring : capsuleProgramToString;

import capsule.casm.link : CapsuleLinker;

import capsule.apps.lib.status : CapsuleApplicationStatus;

public:

enum string CapsuleLinkerVersionName = "20200514";

enum string CapsuleLinkerConfigFileName = "capsule.ini";

enum string CapsuleProgramFileExtension = "capsule";

enum string CapsuleProgramFileDefaultName = "program.capsule";

struct CapsuleLinkerConfig {
    alias Attribute = CapsuleConfigAttribute;
    alias Status = CapsuleConfigStatus;
    
    alias TextEncoding = CapsuleTextEncoding;
    alias TimeEncoding = CapsuleTimeEncoding;
    
    alias TextEncodingName = CapsuleConfigAttribute!TextEncoding.EnumName;
    alias TimeEncodingName = CapsuleConfigAttribute!TimeEncoding.EnumName;
    
    Status status;
    string statusContext;
    
    enum string[] UsageText = [
        "Capsule linker (clink) version " ~ CapsuleLinkerVersionName,
        "Link Capsule object files together to create a Caspule ",
        "program file.",
        "Usage:",
        "  clink <file>... [<option>...]",
    ];
    
    @(CapsuleConfigAttribute!(string[])("input", "i")
        .setOptional(null)
        .setHelpText([
            "Accepts one or more file path strings.",
            "Link the object files found at these file paths.",
            "Paths specified with the -i option are added after paths",
            "given at the beginning of the argument list.",
        ])
    )
    string[] inputPaths;
    
    @(CapsuleConfigAttribute!string("output", "o")
        .setOptional(null)
        .setHelpText([
            "Write program file output to this path.",
            "Replaces the first input path file extension with *.capsule",
            "and writes to that destination when not specified."
        ])
    )
    string outputPath;
    
    @(CapsuleConfigAttribute!bool("debug", "db")
        .setOptional(false)
        .setHelpText([
            "When this flag is set, debugging information will be",
            "included in the outputted program file."
        ])
    )
    bool writeDebugInfo;
    
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
    
    @(CapsuleConfigAttribute!bool("verbose", "v")
        .setOptional(false)
        .setHelpText([
            "When set, the linker will log more messages than usual.",
        ])
    )
    bool verbose;
    
    @(CapsuleConfigAttribute!bool("silent")
        .setOptional(false)
        .setHelpText([
            "When set, the linker will log no messages.",
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

string getDefaultOutputPath(in string inputPath) {
    if(!inputPath.length) {
        return CapsuleProgramFileDefaultName;
    }
    const dotIndex = lastIndexOf(inputPath, '.');
    if(dotIndex > 0) {
        return inputPath[0 .. 1 + dotIndex] ~ CapsuleProgramFileExtension;
    }
    else {
        return inputPath ~ "." ~ CapsuleProgramFileExtension;
    }
}

CapsuleApplicationStatus link(string[] args) {
    alias Config = CapsuleLinkerConfig;
    alias Status = CapsuleApplicationStatus;
    enum string ConfigFileName = CapsuleLinkerConfigFileName;
    enum string VersionName = CapsuleLinkerVersionName;
    // Handle --help or --version
    if(args.length <= 1 || args[1] == "--help") {
        writeln(getCapsuleConfigUsageString!Config());
        return Status.Ok;
    }
    else if(args[1] == "--version") {
        writeln("Capsule linker (clink) version ", VersionName);
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
    // Read and decode object files
    verboseln("Reading from input file paths.");
    inputPaths ~= config.inputPaths;
    if(!inputPaths.length) {
        writeln("No input file paths were specified.");
        writeln("At least one input file path must be given.");
        return Status.ConfigInvalidOptionValueError;
    }
    CapsuleObject[] objects = new CapsuleObject[inputPaths.length];
    const(string)* encodedObject = null;
    size_t encodedObjectLength = 0;
    size_t encodedObjectIndex = 0;
    int readByte() nothrow @trusted @nogc {
        assert(encodedObject !is null);
        return (encodedObjectIndex >= encodedObjectLength ? -1 :
            cast(int) (*encodedObject)[encodedObjectIndex++]
        );
    }
    for(size_t i = 0; i < objects.length; i++) {
        const string inputPath = inputPaths[i];
        const objectFile = File.read(inputPath);
        if(!objectFile.ok) {
            writeln("Error reading object from path ", inputPath);
            return Status.ObjectFileReadError;
        }
        encodedObject = &objectFile.content;
        encodedObjectLength = objectFile.content.length;
        encodedObjectIndex = 0;
        auto decode = CapsuleObjectDecoder(&readByte).read();
        if(!decode.ok) {
            writeln("Error decoding object file at path ", inputPath);
            return Status.ObjectDecodeError;
        }
        objects[i] = decode.object;
        objects[i].filePath = inputPath;
    }
    // Set up a logger for use during linking
    void onLogMessage(in CapsuleLinker.Log.Message message) {
        if(verbose || message.severity > CapsuleLinker.Log.Severity.Debug) {
            writeln(message.toString());
        }
    }
    auto log = CapsuleLinker.Log(&onLogMessage);
    // Link the object files
    verboseln("Linking object files.");
    auto linker = CapsuleLinker(&log, objects);
    linker.programTitle = config.programTitle;
    linker.programCredit = config.programCredit;
    linker.programComment = config.programComment;
    linker.includeDebugSymbols = config.writeDebugInfo;
    linker.includeDebugSources = config.writeDebugInfo;
    linker.link();
    if(!linker.ok) {
        writeln("Linking error.");
        return Status.LinkError;
    }
    // Encode the resulting program data
    verboseln("Encoding the compiled and linked program data.");
    ubyte[] encodedProgram;
    encodedProgram.reserve(1024 +
        linker.program.dataSegment.length +
        linker.program.readOnlyDataSegment.length +
        linker.program.textSegment.length
    );
    void writeByte(in ubyte value) {
        encodedProgram ~= value;
    }
    auto programEncoder = CapsuleProgramEncoder(&writeByte);
    programEncoder.write(linker.program);
    if(!programEncoder.ok) {
        writeln("Error encoding program file data.");
        return Status.ProgramEncodeError;
    }
    // Determine program file path
    string outputPath;
    if(config.outputPath && config.outputPath.length) {
        outputPath = config.outputPath;
    }
    else {
        assert(inputPaths.length);
        outputPath = getDefaultOutputPath(inputPaths.length ? inputPaths[0] : "");
    }
    // Ensure the program file directory exists
    verboseln("Ensuring program file output directory exists.");
    const outputDir = Path(outputPath).dirName;
    if(!isDirectory(outputDir)) {
        verboseln("Creating output directory ", outputDir);
        const dirStatus = ensureDirectory(outputDir);
        if(!dirStatus) {
            writeln("Failed to create output directory ", outputDir);
            return Status.ObjectFileWriteError;
        }
    }
    // Write the program data to the output file path
    verboseln("Writing program file to the output path.");
    auto outputFile = File(outputPath, cast(string) encodedProgram);
    const outputFileStatus = outputFile.write();
    if(outputFileStatus) {
        writeln("Failed to write program data to file path ", outputPath);
        return Status.ProgramFileWriteError;
    }
    if(config.writeDebugInfo) {
        writeln("Wrote program data with debug info to ", outputPath);
    }
    else {
        writeln("Wrote program data to ", outputPath);
    }
    // If the verbose flag was set, write a stringification of the
    // program file to stdout
    if(verbose) {
        writeln("String representation of written program file:");
        writeln(capsuleProgramToString(linker.program));
    }
    // All done
    return Status.Ok;
}

version(CapsuleExcludeLinkerMain) {}
else int main(string[] args) {
    const status = link(args);
    return cast(int) status;
}
