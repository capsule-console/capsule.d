/**

Main file for the Capsule virtual machine (capsule).

This application can be used to load and run a Capsule program file.

*/

module capsule.apps.capsule;

private:

import core.thread.osthread : Thread;

import capsule.parse.config : CapsuleConfigAttribute, CapsuleConfigStatus;
import capsule.parse.config : loadCapsuleConfig, capsuleConfigStatusToString;
import capsule.parse.config : getCapsuleConfigUsageString;

import capsule.io.file : File;
import capsule.io.stdio : stdio;
import capsule.meta.enums : getEnumMemberName;
import capsule.string.hex : getHexString;
import capsule.string.writeint : writeInt;

import capsule.core.engine : CapsuleEngine, CapsuleExtensionCallResult;
import capsule.core.engineinit : initializeCapsuleEngine;
import capsule.core.extension : CapsuleExtension;
import capsule.core.program : CapsuleProgram;
import capsule.core.programencode : CapsuleProgramDecoder;
import capsule.core.programstring : capsuleProgramToString;
import capsule.core.types : CapsuleExceptionCode;
import capsule.core.typestrings : getCapsuleExceptionDescription;

import capsule.extension.list : CapsuleExtensionList;

import capsule.extension.meta : CapsuleMetaModule;
import capsule.extension.stdio : CapsuleStandardIOModule;

import capsule.apps.lib.runprogram : runProgram, debugProgram;
import capsule.apps.lib.status : CapsuleApplicationStatus;

version(CapsuleSDL2Graphics) {
    import derelict.sdl2.sdl : SDL_Event, SDL_PollEvent;
    import capsule.sdl.events : CapsuleSDLEventQueue;
    import capsule.extension.pxgfx : CapsuleSDLPixelGraphicsModule;
}

public:

enum string CapsuleEngineVersionName = "20200514";

struct CapsuleEngineConfig {
    enum string[] UsageText = [
        "Capsule engine version " ~ CapsuleEngineVersionName,
        "Load and execute Capsule program files.",
        "Usage:",
        "  capsule <file> [<option>...]",
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
            "Use the text given with this argument as the program's",
            "standard input."
        ])
    )
    string stdin;
    
    @(CapsuleConfigAttribute!bool("debug", "db")
        .setOptional(false)
        .setHelpText([
            "Run the program in debug mode, with controls such as",
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
    
    @(CapsuleConfigAttribute!bool("show-exit-status", "exs")
        .setOptional(false)
        .setHelpText([
            "When set, information about the final exit status of",
            "the program will be written to stdout after completion."
        ])
    )
    bool showExitStatus;
}

bool verbose = false;

void verboseln(T...)(lazy T args) {
    if(!verbose) return;
    stdio.writeln(args);
}

void writeln(T...)(lazy T args) {
    stdio.writeln(args);
}

CapsuleApplicationStatus getExitStatus(in CapsuleEngine.Status status) {
    alias Status = CapsuleApplicationStatus;
    switch(status) {
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

struct CapsuleEngineExtensionHandler {
    alias CallResult = CapsuleExtensionCallResult;
    alias Config = CapsuleEngineConfig;
    alias ExtensionList = CapsuleExtensionList;
    
    version(CapsuleSDL2Graphics) {
        alias Event = CapsuleSDLEventQueue.Event;
        alias EventQueue = CapsuleSDLEventQueue;
        alias PixelGraphicsModule = CapsuleSDLPixelGraphicsModule;
    }
    
    /// Data structure for storing and accessing extension call
    /// implementation functions by ID
    ExtensionList extList;
    /// Context for the "meta" extension module
    CapsuleMetaModule metaModule;
    /// Context for the "stdio" extension module
    CapsuleStandardIOModule stdioModule;
    /// Context for the "pxgfx" extension module
    version(CapsuleSDL2Graphics) {
        PixelGraphicsModule pxgfxModule;
    }
    
    /// Extension call handler function to be provided to a CapsuleEngine
    /// instance. The ecallData argument must be a pointer to an instance
    /// of this struct type.
    static CallResult ecall(
        void* ecallData, CapsuleEngine* engine, in uint id, in uint arg
    ) {
        assert(ecallData);
        assert(engine);
        auto handler = cast(CapsuleEngineExtensionHandler*) ecallData;
        return handler.extList.callExtension(engine, id, arg);
    }
    
    /// Message logging function to be provided to extension module
    /// context objects, allowing the user to receive more specific
    /// information about extension failures than the mere presence
    /// of an extension error exception code.
    static void onExtensionError(in char[] text) {
        writeln("Extension error: ", text);
    }
    
    /// Initializes all the extension modules supported by this
    /// Capsule virtual machine implementation.
    void initialize(in Config config) {
        // meta
        this.metaModule = CapsuleMetaModule(&onExtensionError, &this.extList);
        this.extList.addExtensionList(metaModule.getExtensionList());
        // stdio
        this.stdioModule = CapsuleStandardIOModule(&onExtensionError);
        this.stdioModule.setOutputPath(config.stdoutPath);
        if(config.stdin) {
            this.stdioModule.setInputContent(config.stdin);
        }
        else {
            this.stdioModule.setInputPath(config.stdinPath);
        }
        this.extList.addExtensionList(stdioModule.getExtensionList());
        // pxgfx
        version(CapsuleSDL2Graphics) {
            this.pxgfxModule = PixelGraphicsModule(&onExtensionError);
            this.extList.addExtensionList(pxgfxModule.getExtensionList());
        }
    }
    
    /// Free resources or otherwise conclude all the extension
    /// modules that might have been previously initialized for this
    /// extension call handler.
    void conclude() {
        this.metaModule.conclude();
        this.stdioModule.conclude();
        version(CapsuleSDL2Graphics) {
            this.pxgfxModule.conclude();
        }
    }
    
    version(CapsuleSDL2Graphics) void dispatchSDLEvent(
        CapsuleEngine* engine, in Event event
    ) {
        assert(engine);
        this.pxgfxModule.handleSDLEvent(engine, event);
    }
}

CapsuleApplicationStatus execute(string[] args) {
    alias Config = CapsuleEngineConfig;
    alias Status = CapsuleApplicationStatus;
    enum string VersionName = CapsuleEngineVersionName;
    // Handle --help, --version, or --list-extensions
    if(args.length <= 1 || args[1] == "--help") {
        writeln(getCapsuleConfigUsageString!Config());
        return Status.Ok;
    }
    else if(args[1] == "--version") {
        writeln("Capsule engine version ", VersionName);
        return Status.Ok;
    }
    else if(args[1] == "--list-extensions") {
        CapsuleEngineExtensionHandler extHandler;
        extHandler.initialize(Config.init);
        foreach(entry; extHandler.extList.entries) {
            const string name = getEnumMemberName(entry.id);
            writeln(
                getHexString(cast(uint) entry.id), (name ? " " ~ name : "")
            );
        }
        return Status.Ok;
    }
    // Get configuration options
    auto configResult = loadCapsuleConfig!Config(args[2 .. $]);
    auto config = configResult.config;
    verbose = configResult.config.verbose;
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
    // Read the input program file 
    verboseln("Reading from program file path.");
    const inputPath = args.length > 1 ? args[1] : null;
    if(!inputPath.length) {
        writeln("No program file path was specified.");
        writeln("A program file path must be given.");
        return Status.ConfigInvalidOptionValueError;
    }
    File programFile = File.read(inputPath);
    if(!programFile.ok) {
        writeln("Error reading program from path ", inputPath);
        return Status.ProgramFileReadError;
    }
    // Decode the input program file
    verboseln("Decoding program file.");
    size_t encodedProgramIndex;
    int readByte() nothrow @trusted @nogc {
        return (encodedProgramIndex >= programFile.content.length ? -1 :
            cast(int) programFile.content[encodedProgramIndex++]
        );
    }
    auto decode = CapsuleProgramDecoder(&readByte).read();
    if(!decode.ok) {
        writeln("Error decoding program file at path ", inputPath);
        return Status.ProgramDecodeError;
    }
    // If the verbose flag was set, write a stringification of the
    // program file to stdout
    if(verbose) {
        writeln("String representation of loaded program file:");
        writeln(capsuleProgramToString(decode.program));
    }
    // Initialize extensions
    verboseln("Initializing extension modules.");
    CapsuleEngineExtensionHandler extHandler;
    extHandler.initialize(config);
    // Initialize a CapsuleEngine instance to run the program with
    CapsuleEngine engine = initializeCapsuleEngine(
        decode.program, &CapsuleEngineExtensionHandler.ecall, &extHandler
    );
    const beginOk = engine.begin(cast(int) decode.program.entryOffset);
    if(!engine.ok || !beginOk) {
        writeln("Program file is invalid and cannot be executed.");
        return Status.ProgramInvalidError;
    }
    // Run the program!
    verboseln("Executing program.");
    void runProgramThread() {
        assert(engine.ok);
        verboseln("Executing program in separate thread.");
        if(config.debugMode) debugProgram(decode.program, &engine);
        else runProgram(&engine);
    }
    auto engineThread = new Thread(&runProgramThread);
    engineThread.start();
    version(CapsuleSDL2Graphics) {
        alias EventQueue = CapsuleSDLEventQueue;
        SDL_Event event;
        while(engine.status is CapsuleEngine.Status.Running) {
            // TODO: Figure out why this is broken
            //if(SDL_PollEvent(&event)) {
                //extHandler.dispatchSDLEvent(&engine, event);
            //}
            //const waitStatus = EventQueue.waitEvent(1_000);
            //if(!waitStatus) {
            //    break;
            //}
            //if(engine.status !is CapsuleEngine.Status.Running) {
            //    break;
            //}
            //extHandler.dispatchSDLEvent(&engine, EventQueue.nextEvent());
        }
    }
    engineThread.join();
    // Wrap it up
    if(verbose) {
        const status = getEnumMemberName(engine.status);
        writeln("Execution complete with status ", status);
    }
    if(engine.exception) {
        writeln("Exception: ",
            getCapsuleExceptionDescription(engine.exception)
        );
        if(engine.exception is CapsuleExceptionCode.ExtensionError ||
            engine.exception is CapsuleExceptionCode.ExtensionMissing
        ) {
            auto id = getHexString(engine.ecallId);
            writeln("Most recent ecall: ", id);
        }
    }
    engine.mem.free();
    extHandler.conclude();
    const exitStatus = getExitStatus(engine.status);
    if(config.showExitStatus || verbose) {
        writeln("Exiting with status code ", writeInt(exitStatus));
    }
    return exitStatus;
}

version(CapsuleExcludeExecutionMain) {}
else int main(string[] args) {
    const status = execute(args);
    return cast(int) status;
}
