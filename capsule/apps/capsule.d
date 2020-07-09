/**

Main file for the Capsule virtual machine (capsule).

This application can be used to load and run a Capsule program file.

*/

module capsule.apps.capsule;

private:

import capsule.encode.config : CapsuleConfigAttribute, CapsuleConfigStatus;
import capsule.encode.config : loadCapsuleConfig, capsuleConfigStatusToString;
import capsule.encode.config : getCapsuleConfigUsageString;

import capsule.algorithm.indexof : indexOf;
import capsule.encode.ini : Ini;
import capsule.io.file : File;
import capsule.io.stdio : stdio;
import capsule.math.vector : Vector;
import capsule.meta.enums : getEnumMemberName, getEnumMemberAttribute;
import capsule.string.hex : getHexString, getByteHexString;
import capsule.string.pad : padLeft;
import capsule.string.parseint : parseUnsignedInt;
import capsule.string.writeint : writeInt;
import capsule.time.monotonic : monotonicns;
import capsule.time.sleep : sleepPreciseMilliseconds;

import capsule.core.engine : CapsuleEngine, CapsuleExtensionCallResult;
import capsule.core.engineinit : initializeCapsuleEngine;
import capsule.core.exception : CapsuleExceptionCode;
import capsule.core.exception : getCapsuleExceptionDescription;
import capsule.core.extension : CapsuleExtension;
import capsule.core.opcode : CapsuleOpcode, getCapsuleOpcodeName;
import capsule.core.program : CapsuleProgram;
import capsule.core.programencode : CapsuleProgramDecoder;
import capsule.core.programstring : capsuleProgramToString;

import capsule.extension.common : CapsuleModuleMessageSeverity;
import capsule.extension.list : CapsuleExtensionList;

import capsule.extension.memory : CapsuleMemoryModule;
import capsule.extension.meta : CapsuleMetaModule;
import capsule.extension.stdio : CapsuleStandardIOModule;
import capsule.extension.time : CapsuleTimeModule;

import capsule.apps.lib.modulesettings : CapsuleModulePropertySettings;
import capsule.apps.lib.runprogram : runProgram, debugProgram;
import capsule.apps.lib.status : CapsuleApplicationStatus;

version(CapsuleLibrarySDL2) {
    import derelict.sdl2.sdl; // : SDL_Event, SDL_PollEvent;
    import capsule.sdl.sdl : CapsuleSDL;
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
    
    @(CapsuleConfigAttribute!(string[])("settings", "s")
        .setOptional(null)
        .setHelpText([
            "A list of paths to read settings files from.",
            "Settings properties given in files later in the list",
            "will take precedence of properties in files that were",
            "earlier in the list.",
        ])
    )
    string[] settingsPaths;
    
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
    
    @(CapsuleConfigAttribute!uint("defer-timeout-ms", "dtms")
        .setOptional(0)
        .setHelpText([
            "If the program fails to call the \"meta.defer\" at least",
            "once per millisecond time interval, then terminate the",
            "program based on this setting."
        ])
    )
    uint deferTimeoutMilliseconds;
    
    @(CapsuleConfigAttribute!uint("limit-hz", "hz")
        .setOptional(0)
        .setHelpText([
            "Artificially cap program performance so that, on average,",
            "approximately only this many instructions may be executed",
            "per second.",
        ])
    )
    uint limitInstructionsPerSecond;
    
    @(CapsuleConfigAttribute!bool("time")
        .setOptional(false)
        .setHelpText([
            "When set, the time it took to execute the program, not",
            "counting time spent loading, decoding, and initializing,",
            "will be written to standard output after program execution",
            "is complete.",
        ])
    )
    bool printTime;
    
    @(CapsuleConfigAttribute!bool("print-program")
        .setOptional(false)
        .setHelpText([
            "When set, a string representation of the loaded program",
            "will be logged to standard output before it is executed.",
        ])
    )
    bool printProgram;
    
    @(CapsuleConfigAttribute!bool("print-metrics")
        .setOptional(false)
        .setHelpText([
            "When set, metrics regarding program execution will be",
            "tracked during runtime and then written to standard output",
            "after the program ends.",
        ])
    )
    bool printMetrics;
    
    @(CapsuleConfigAttribute!bool("show-exit-status", "exs")
        .setOptional(false)
        .setHelpText([
            "When set, information about the final exit status of",
            "the program will be written to standard output after",
            "completion."
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
    alias MessageSeverity = CapsuleModuleMessageSeverity;
    
    version(CapsuleLibrarySDL2) {
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
    /// Context for the "time" extension module
    CapsuleTimeModule timeModule;
    /// Context for the "memory" extension module
    CapsuleMemoryModule memoryModule;
    /// Context for the "pxgfx" extension module
    version(CapsuleLibrarySDL2) {
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
    static void onExtensionMessage(
        in MessageSeverity severity, in char[] text
    ) {
        if(severity is MessageSeverity.Debug && verbose) {
            writeln("Extension debug ", text);
        }
        else if(severity is MessageSeverity.Info) {
            writeln("Extension info ", text);
        }
        else if(severity is MessageSeverity.Warning) {
            writeln("Extension warning ", text);
        }
        else if(severity is MessageSeverity.Error) {
            writeln("Extension error ", text);
        }
    }
    
    /// Initializes all the extension modules supported by this
    /// Capsule virtual machine implementation.
    void initialize(in Config config) {
        // meta
        this.metaModule = CapsuleMetaModule(&onExtensionMessage, &this.extList);
        this.metaModule.initializeSignalHandler();
        this.extList.addExtensionList(this.metaModule.getExtensionList());
        version(CapsuleLibrarySDL2) {
            CapsuleSDL.addRequiredSubSystems(this.metaModule.RequiredSDLSubSystems);
            this.metaModule.initializeSDLEventDispatch(
                &(typeof(this).dispatchSDLEvent), &this
            );
        }
        // stdio
        this.stdioModule = CapsuleStandardIOModule(&onExtensionMessage);
        this.stdioModule.setOutputPath(config.stdoutPath);
        if(config.stdin) {
            this.stdioModule.setInputContent(config.stdin);
        }
        else {
            this.stdioModule.setInputPath(config.stdinPath);
        }
        this.extList.addExtensionList(this.stdioModule.getExtensionList());
        // time
        this.timeModule = CapsuleTimeModule(&onExtensionMessage);
        this.extList.addExtensionList(this.timeModule.getExtensionList());
        // memory
        this.memoryModule = CapsuleMemoryModule(&onExtensionMessage);
        this.extList.addExtensionList(this.memoryModule.getExtensionList());
        // pxgfx
        version(CapsuleLibrarySDL2) {
            this.pxgfxModule = PixelGraphicsModule(&onExtensionMessage);
            this.extList.addExtensionList(this.pxgfxModule.getExtensionList());
            CapsuleSDL.addRequiredSubSystems(this.pxgfxModule.RequiredSDLSubSystems);
        }
    }
    
    static auto parseResolutionSetting(in string text) {
        struct Result {
            int width;
            int height;
        }
        const sep = indexOf(text, 'x');
        if(sep < 0) {
            return Result.init;
        }
        assert(sep < text.length);
        const width = parseUnsignedInt!int(text[0 .. sep]);
        const height = parseUnsignedInt!int(text[1 + sep .. $]);
        if(width.ok && height.ok) {
            return Result(width.value, height.value);
        }
        else {
            return Result.init;
        }
    }
    
    void applySettings(Ini.Group settings) {
        version(CapsuleLibrarySDL2) {
            this.pxgfxApplySettings(settings);
        }
    }
    
    version(CapsuleLibrarySDL2) void pxgfxApplySettings(Ini.Group settings) {
        alias Resolution = PixelGraphicsModule.Resolution;
        const properties = CapsuleModulePropertySettings("pxgfx", settings);
        this.pxgfxModule.scalingMode.allowScalingUp = (
            properties.get!bool("allow-scaling-up")
        );
        this.pxgfxModule.scalingMode.allowScalingDown = (
            properties.get!bool("allow-scaling-down")
        );
        this.pxgfxModule.scalingMode.allowScalingFractional = (
            properties.get!bool("allow-scaling-fractional")
        );
        this.pxgfxModule.scalingMode.allowScalingStretched = (
            properties.get!bool("allow-scaling-stretched")
        );
        this.pxgfxModule.showFpsCounter = (
            properties.get!bool("show-fps-counter")
        );
        this.pxgfxModule.scaleQuality = (
            properties.get!string("scale-quality") == "linear" ?
            PixelGraphicsModule.ScaleQuality.Linear :
            PixelGraphicsModule.ScaleQuality.Nearest
        );
        this.pxgfxModule.windowSize = Resolution(
            properties.get!(Vector!(2, uint))("window-size").values
        );
        this.pxgfxModule.preferredResolution = Resolution(
            properties.get!(Vector!(2, uint))("preferred-resolution").values
        );
    }
    
    /// Free resources or otherwise conclude all the extension
    /// modules that might have been previously initialized for this
    /// extension call handler.
    void conclude() {
        this.metaModule.conclude();
        this.stdioModule.conclude();
        this.timeModule.conclude();
        this.memoryModule.conclude();
        version(CapsuleLibrarySDL2) {
            this.pxgfxModule.conclude();
            if(CapsuleSDL.initialized) {
                CapsuleSDL.quit();
            }
            if(CapsuleSDL.loaded) {
                CapsuleSDL.unload();
            }
        }
    }
    
    version(CapsuleLibrarySDL2) static void dispatchSDLEvent(
        void* data, CapsuleEngine* engine, in Event event
    ) {
        assert(data);
        assert(engine);
        auto handler = cast(typeof(this)*) data;
        if(event.type == SDL_QUIT || (
            event.type == SDL_WINDOWEVENT &&
            event.window.event == SDL_WINDOWEVENT_CLOSE
        )) {
            engine.status = CapsuleEngine.Status.Terminated;
        }
        // TODO
        //handler.pxgfxModule.handleSDLEvent(engine, event);
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
    // Set up a logger for use during INI settings file loading
    void onLogMessage(in Ini.Parser.Log.Message message) {
        if(verbose || message.severity > Ini.Parser.Log.Severity.Debug) {
            writeln(message.toString());
        }
    }
    auto log = Ini.Parser.Log(&onLogMessage);
    // Read settings file or files
    Ini.Group settings;
    foreach(settingsPath; config.settingsPaths) {
        verboseln("Reading settings from path ", settingsPath);
        auto settingsFile = File.read(settingsPath);
        if(!settingsFile.ok) {
            writeln("Failed to read settings from path ", settingsPath);
            continue;
        }
        auto settingsParser = Ini.Parser(&log, settingsFile);
        settingsParser.parse();
        if(!settingsParser.ok) {
            writeln("Error parsing settings INI at path ", settingsPath);
            continue;
        }
        settings.addIni(settingsParser.ini);
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
    if(config.printProgram) {
        writeln("String representation of loaded program file:");
        stdio.writeln(capsuleProgramToString(decode.program));
    }
    // Initialize extensions
    verboseln("Initializing extension modules.");
    CapsuleEngineExtensionHandler extHandler;
    extHandler.initialize(config);
    // Recognized settings loaded from INI files
    verboseln("Applying settings.");
    extHandler.applySettings(settings);
    // Initialize a CapsuleEngine instance to run the program with
    CapsuleEngine engine = initializeCapsuleEngine(
        decode.program, &CapsuleEngineExtensionHandler.ecall, &extHandler
    );
    const beginOk = engine.begin(cast(int) decode.program.entryOffset);
    if(!engine.ok || !beginOk) {
        writeln("Program file is invalid and cannot be executed.");
        return Status.ProgramInvalidError;
    }
    // Assign a program execution interval callback
    const bool programMetrics = (
        config.printMetrics ||
        config.deferTimeoutMilliseconds ||
        config.limitInstructionsPerSecond
    );
    static struct ProgramIntervalCallbackData {
        long lastIntervalTime;
        ulong lastIntervalExecCount;
        uint deferTimeoutMilliseconds;
        uint limitInstructionsPerSecond;
        CapsuleMetaModule* metaModule;
    }
    ProgramIntervalCallbackData intervalCallbackData = {
        lastIntervalTime: 0,
        lastIntervalExecCount: 0,
        deferTimeoutMilliseconds: config.deferTimeoutMilliseconds,
        limitInstructionsPerSecond: config.limitInstructionsPerSecond,
        metaModule: &extHandler.metaModule,
    };
    static void programIntervalCallback(
        void* data, CapsuleEngine* engine
    ) {
        auto cdata = cast(ProgramIntervalCallbackData*) data;
        assert(cdata);
        assert(cdata.metaModule);
        const now = monotonicns();
        const deferTime = now - cdata.metaModule.lastDeferTime;
        const intervalTime = now - cdata.lastIntervalTime;
        const intervalExec = engine.totalExecCount - cdata.lastIntervalExecCount;
        const expectedExec = (
            intervalTime * cdata.limitInstructionsPerSecond / 1_000_000_000L
        );
        if(cdata.deferTimeoutMilliseconds && (
            (deferTime / 1_000_000L) > cdata.deferTimeoutMilliseconds
        )) {
            cdata.metaModule.addErrorMessage(
                "meta.defer: Defer timeout exceeded. Terminating program."
            );
            engine.status = CapsuleEngine.Status.Terminated;
        }
        else if(cdata.limitInstructionsPerSecond && (
            intervalExec > expectedExec
        )) {
            const expectedTime = cast(long) (1_000_000_000L * intervalExec) / (
                 cdata.limitInstructionsPerSecond
            );
            assert(expectedTime >= intervalTime);
            sleepPreciseMilliseconds(cast(int) (
                (expectedTime - intervalTime) / 1_000_000L
            ));
        }
        cdata.lastIntervalTime = now;
        cdata.lastIntervalExecCount = engine.totalExecCount;
    }
    engine.intervalCallbackMask = 0xffff; // Run once per 65536 instructions
    engine.intervalCallbackData = cast(void*) &intervalCallbackData;
    engine.intervalCallback = &programIntervalCallback;
    // Run the program!
    verboseln("Executing program.");
    const programStartTime = monotonicns();
    if(config.debugMode) {
        debugProgram(decode.program, &engine);
    }
    else {
        runProgram(&engine, programMetrics);
    }
    const programEndTime = monotonicns();
    const programDuration = programEndTime - programStartTime;
    // All done, now wrap it up
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
    if(config.printTime || config.printMetrics) {
        const long milliseconds = programDuration / 1_000_000L;
        const msString = padLeft(writeInt(milliseconds).getChars(), '0', 4);
        const secString = msString[0 .. $ - 3] ~ "." ~ msString[$ - 3 .. $];
        stdio.writeln("Execution complete in ", secString, " seconds.");
    }
    if(config.printMetrics) {
        if(!engine.totalExecCount) {
            stdio.writeln("Instruction metrics were not recorded.");
        }
        else {
            const programDurationSeconds = programDuration / 1_000_000_000L;
            const hz = (programDurationSeconds == 0 ?
                engine.totalExecCount :
                engine.totalExecCount / programDurationSeconds
            );
            stdio.writeln(
                "Total instructions executed: ", writeInt(engine.totalExecCount)
            );
            stdio.write(
                "Average instructions executed per second: ", writeInt(hz)
            );
            if(hz >= 1_000_000) {
                stdio.writeln(" (", writeInt(hz / 1_000_000L), " MHz)");
            }
            else {
                stdio.write("\n");
            }
            stdio.writeln("Instructions executed per opcode:");
            for(uint i = 0; i < engine.opExecCount.length; i++) {
                const name = getCapsuleOpcodeName(cast(CapsuleOpcode) i);
                const count = engine.opExecCount[i];
                if(count && name.length) stdio.writeln(
                    getByteHexString(cast(ubyte) i), " ", name, ": ",
                    writeInt(count)
                );
            }
        }
    }
    if(config.showExitStatus || verbose) {
        stdio.writeln("Exiting with status code ", writeInt(exitStatus));
    }
    return exitStatus;
}

version(CapsuleExcludeExecutionMain) {}
else int main(string[] args) {
    const status = execute(args);
    return cast(int) status;
}
