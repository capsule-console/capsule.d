/**

This module implements Capsule's pixel graphics extensions (pxgfx)
via the SDL library.

http://www.libsdl.org/

*/

module capsule.extension.pxgfx;

version(CapsuleSDL2Graphics):

private:

import core.stdc.string : memcpy;

import capsule.core.engine : CapsuleEngine, CapsuleExtensionCallResult;
import capsule.meta.enums : getEnumMemberName;
import capsule.io.file : File, FileWriter;
import capsule.string.hex : getHexString;
import capsule.math.ispow2 : isPow2;
import capsule.range.range : toArray;
import capsule.time.monotonic : monotonicns;

import capsule.core.extension : CapsuleExtension;

import capsule.extension.common : CapsuleModuleMixin;
import capsule.extension.list : CapsuleExtensionListEntry;

import capsule.sdl.events : CapsuleSDLEventQueue, CapsuleSDLEventType;
import capsule.sdl.events : CapsuleSDLWindowEventID;
import capsule.sdl.sdl : CapsuleSDL;
import capsule.sdl.window : CapsuleSDLWindow;

import derelict.sdl2.sdl;

public:

struct CapsuleSDLPixelGraphicsModule {
    mixin CapsuleModuleMixin;
    
    alias ecall_pxgfx_init = .ecall_pxgfx_init;
    alias ecall_pxgfx_flip = .ecall_pxgfx_flip;
    
    alias Extension = CapsuleExtension;
    alias Mode = CapsuleSDLPixelGraphicsMode;
    alias PixelFormat = CapsuleSDLWindow.PixelFormat;
    alias Resolution = CapsuleSDLPixelGraphicsResolution;
    alias Settings = CapsuleSDLPixelGraphicsInitSettings;
    alias Window = CapsuleSDLWindow;
    
    /// TODO: A list of resolutions that the host will permit the
    /// application to run at
    Resolution[] resolutionList;
    /// The settings that were indicated in a pxgfx.init ecall
    Settings settings;
    /// TODO: X offset within full window to display image data
    int offsetX = 0;
    /// TODO: Y offset within full window to display image data
    int offsetY = 0;
    /// TODO: Width within full window at which to display image data
    int width = 1;
    /// TODO: Height within full window at which to display image data
    int height = 1;
    /// Current frame/tick
    uint ticks = 0;
    /// Monotonic time of last pxgfx.flip ecall
    long lastFlipNanoseconds = 0;
    /// Title to use for the application window
    string windowTitle = "Capsule";
    /// Reference to an SDL_Window containing the application image data
    Window window;
    
    import capsule.io.stdio;
    import capsule.meta.enums;
    
    extern(C) static int onEvent(void* data, SDL_Event* event) nothrow {
        // TODO: Ask the user to confirm
        assert(data);
        stdio.writeln("EVENT: ", getEnumMemberName(event.type));
        if(event.type == SDL_WINDOWEVENT) {
            stdio.writeln("WINDOW: ", getEnumMemberName(event.window.event));
        }
        if(event && (event.type == SDL_QUIT || (
            event.type == SDL_WINDOWEVENT &&
            event.window.event == SDL_WINDOWEVENT_CLOSE
        ))) {
            auto engine = cast(CapsuleEngine*) data;
            engine.status = CapsuleEngine.Status.Terminated;
            assert(false);
        }
        return 0;
    }
    
    static bool isSupportedWindowPixelFormat(in PixelFormat format) {
        switch(format) {
            case PixelFormat.RGB24: goto case;
            case PixelFormat.RGB888: goto case;
            case PixelFormat.RGBA8888: goto case;
            case PixelFormat.ARGB8888: return true;
            default: return false;
        }
    }
    
    this(ErrorMessageCallback onErrorMessage) {
        this.onErrorMessage = onErrorMessage;
    }
    
    bool ok() const {
        return this.window.ok && this.settings.ok;
    }
    
    void conclude() {
        if(this.window.ok) {
            this.window.free();
        }
        if(CapsuleSDL.initialized) {
            CapsuleSDL.quit();
        }
        if(CapsuleSDL.loaded) {
            CapsuleSDL.unload();
        }
    }
    
    CapsuleExtensionListEntry[] getExtensionList() {
        alias Entry = CapsuleExtensionListEntry;
        return [
            Entry(Extension.pxgfx_init, &ecall_pxgfx_init, &this),
            Entry(Extension.pxgfx_flip, &ecall_pxgfx_flip, &this),
        ];
    }
    
    void handleSDLEvent(CapsuleEngine* engine, in SDL_Event event) {
        stdio.writeln("EVENT: ", getEnumMemberName(event.type));
        if(event.type == SDL_WINDOWEVENT) {
            stdio.writeln("WINDOW: ", getEnumMemberName(event.window.event));
        }
        if(event.type == SDL_QUIT || (
            event.type == SDL_WINDOWEVENT &&
            event.window.event == SDL_WINDOWEVENT_CLOSE
        )) {
            engine.status = CapsuleEngine.Status.Terminated;
            assert(false, "Terminated!!!");
        }
    }
}

struct CapsuleSDLPixelGraphicsResolution {
    int width = 0;
    int height = 0;
    int scale = 1; // TODO
}

enum CapsuleSDLPixelGraphicsMode: uint {
    Indexed2Bit = 0x01,
    Indexed4Bit = 0x02,
    Indexed8Bit = 0x03,
    Truecolor24Bit = 0x80,
}

struct CapsuleSDLPixelGraphicsInitSettings {
    alias Mode = CapsuleSDLPixelGraphicsMode;
    
    int resolutionX;
    int resolutionY;
    int pitch;
    Mode mode;
    int palettePtr;
    int pixelsPtr;
    ushort frameLimit;
    short[3] unused;
    
    bool ok() const {
        return (
            this.resolutionX > 0 &&
            this.resolutionY > 0 &&
            isPow2(this.pitch)
        );
    }
    
    /// Return the number of microseconds that each frame is expected
    /// to take at minimum, given the frameLimit FPS value.
    uint frameLimitMicroseconds() const {
        return this.frameLimit == 0 ? 0 : 1_000_000 / this.frameLimit;
    }
}

/// Implement pxgfx.init extension.
/// The data pointer must refer to a CapsuleSDLPixelGraphicsModule instance.
CapsuleExtensionCallResult ecall_pxgfx_init(
    void* data, CapsuleEngine* engine, in uint arg
) {
    assert(data);
    // TODO: Return status flag instead of always producing an exception
    // TODO: Should pixel and palette ptrs be absolute? (I think no..?)
    // TODO: Should ptrs be relative to the beginning of the struct?
    // TODO: SDL_Texture and SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "nearest"); 
    alias Mode = CapsuleSDLPixelGraphicsMode;
    alias PixelFormat = CapsuleSDLWindow.PixelFormat;
    alias Settings = CapsuleSDLPixelGraphicsInitSettings;
    auto pxgfx = cast(CapsuleSDLPixelGraphicsModule*) data;
    if(pxgfx.window.ok) {
        pxgfx.addErrorMessage("pxgfx.init: Already initialized.");
        return CapsuleExtensionCallResult.Error;
    }
    if(!CapsuleSDL.loaded) {
        CapsuleSDL.load();
    }
    if(!CapsuleSDL.initialized) {
        CapsuleSDL.initialize(
            cast(uint) CapsuleSDL.System.Video |
            cast(uint) CapsuleSDL.System.Events
        );
        //CapsuleSDLEventQueue.addWatch(
        //    &CapsuleSDLPixelGraphicsModule.onEvent, engine
        //);
    }
    const lResX = engine.mem.loadWord(arg);
    const lResY = engine.mem.loadWord(arg + 4);
    const lPitch = engine.mem.loadWord(arg + 8);
    const lMode = engine.mem.loadWord(arg + 12);
    const lPalettePtr = engine.mem.loadWord(arg + 16);
    const lPixelsPtr = engine.mem.loadWord(arg + 20);
    const lFrameLimit = engine.mem.loadHalfWordUnsigned(arg + 24);
    const lUnusedHalf = engine.mem.loadHalfWordSigned(arg + 26);
    const lUnusedWord = engine.mem.loadWord(arg + 28);
    if(
        !lResX.ok || !lResY.ok || !lPitch.ok || !lMode.ok ||
        !lPalettePtr.ok || !lPixelsPtr.ok || !lFrameLimit.ok ||
        !lUnusedHalf.ok || !lUnusedWord.ok
    ) {
        pxgfx.addErrorMessage("pxgfx.init: Invalid settings pointer.");
        return CapsuleExtensionCallResult.Error;
    }
    Settings settings = {
        resolutionX: lResX.value,
        resolutionY: lResY.value,
        pitch: lPitch.value,
        mode: cast(Mode) lMode.value,
        palettePtr: lPalettePtr.value + (arg + 16),
        pixelsPtr: lPixelsPtr.value + (arg + 20),
        frameLimit: cast(ushort) lFrameLimit.value,
    };
    pxgfx.settings = settings;
    if(!settings.ok) {
        pxgfx.addErrorMessage("pxgfx.init: Invalid settings data.");
        return CapsuleExtensionCallResult.Error;
    }
    pxgfx.window = CapsuleSDLWindow(
        pxgfx.windowTitle,
        settings.resolutionX,
        settings.resolutionY,
        CapsuleSDLWindow.Flag.Shown
    );
    if(!pxgfx.window.ok) {
        pxgfx.addErrorMessage("pxgfx.init: Failed to create window.");
        return CapsuleExtensionCallResult.Error;
    }
    else if(!CapsuleSDLPixelGraphicsModule.isSupportedWindowPixelFormat(
        cast(PixelFormat) pxgfx.window.surface.format.format
    )) {
        const format = pxgfx.window.surface.format.format;
        const formatName = getEnumMemberName(cast(PixelFormat) format);
        pxgfx.addErrorMessage(
            "pxgfx.init: Unsupported window pixel format " ~
            toArray(getHexString(format)) ~
            (formatName.length ? " " ~ formatName : "")
        );
        return CapsuleExtensionCallResult.Error;
    }
    else {
        return CapsuleExtensionCallResult.Ok(0);
    }
}

void pxgfxFlipSurfaceImpl(alias getColor, alias setColor)(
    in int rows, in int width,
    in int programPitch, in int surfacePitch,
    const(ubyte)* programPtr, void* surfacePtr,
) {
    for(int i = 0; i < rows; i++) {
        const(ubyte*) nextProgramRow = programPtr + programPitch;
        void* nextSurfaceRow = surfacePtr + surfacePitch;
        for(int j = 0; j < width; j++) {
            const uint rgb = getColor();
            setColor(rgb);
        }
        programPtr = nextProgramRow;
        surfacePtr = nextSurfaceRow;
    }
}

size_t endi = 0;
import capsule.io.stdio;
import capsule.string.writeint;

CapsuleExtensionCallResult ecall_pxgfx_flip(
    void* data, CapsuleEngine* engine, in uint arg
) {
    if(endi++ > 60) {
        engine.status = CapsuleEngine.Status.Terminated;
        //assert(false);
    }
    assert(data);
    alias Mode = CapsuleSDLPixelGraphicsMode;
    alias PixelFormat = CapsuleSDLWindow.PixelFormat;
    bool checkProgramMemory(in int address, in int length) {
        return (
            address >= 0 && length >= 0 &&
            address <= int.max && length <= int.max &&
            (int.max - address) >= length &&
            (address + length) < engine.mem.length
        );
    }
    auto pxgfx = cast(CapsuleSDLPixelGraphicsModule*) data;
    if(!pxgfx.ok) {
        pxgfx.addErrorMessage("pxgfx.flip: Module not initialized.");
        return CapsuleExtensionCallResult.Error;
    }
    const surfaceFormat = pxgfx.window.surface.format.format;
    const width = pxgfx.window.surface.w;
    const rows = pxgfx.window.surface.h;
    const mode = pxgfx.settings.mode;
    uint length;
    void* surfacePtr = pxgfx.window.surface.pixels;
    if(pxgfx.settings.mode is Mode.Truecolor24Bit) {
        length = cast(uint) rows * pxgfx.settings.pitch;
    }
    else {
        assert(false, "TODO");
    }
    if(!checkProgramMemory(pxgfx.settings.pixelsPtr, length)) {
        pxgfx.addErrorMessage("pxgfx.flip: Invalid pixel data pointer.");
        return CapsuleExtensionCallResult.Error;
    }
    const(ubyte)* programPtr = (
        engine.mem.data + pxgfx.settings.pixelsPtr
    );
    pxgfx.window.lockSurface();
    if(mode is Mode.Truecolor24Bit && (
        surfaceFormat == PixelFormat.RGB888 ||
        surfaceFormat == PixelFormat.RGBA8888
    )) {
        for(int i = 0; i < rows; i++) {
            memcpy(surfacePtr, programPtr, 4 * width);
            surfacePtr += pxgfx.window.surface.pitch;
            programPtr += pxgfx.settings.pitch;
        }
    }
    else if(surfaceFormat == PixelFormat.RGB24 && mode is Mode.Truecolor24Bit) {
        pxgfxFlipSurfaceImpl!(() {
            const uint rgb = *(cast(const(uint)*) programPtr);
            programPtr += 4;
            return rgb;
        },
        (in uint rgb) {
            *(cast(ushort*) surfacePtr) = cast(ushort) rgb;
            *(cast(ubyte*) (surfacePtr + 2)) = cast(ubyte) (rgb >> 16);
            surfacePtr += 3;
        }
            //(const(ubyte)** programPtr) {
            //    const uint rgba = *(cast(const(uint)*) (*programPtr));
            //    *programPtr += 4;
            //    return rgba;
            //},
            //(void** surfacePtr, in uint rgba) {
            //    *(cast(ushort*) (*surfacePtr)) = cast(ushort) rgba;
            //    *(cast(ubyte*) (*(surfacePtr + 2))) = cast(ubyte) (rgba >> 16);
            //    *surfacePtr += 3;
            //}
        )(
            rows, width, pxgfx.settings.pitch, pxgfx.window.surface.pitch,
            programPtr, surfacePtr,
        );
        
        //for(int i = 0; i < rows; i++) {
        //    for(int j = 0, j3 = 0; j < width; j++) {
        //        const rgba = *(cast(const(uint)*) &programPtr[j << 2]);
        //        *(cast(ushort*) &surfacePtr[j3]) = cast(ushort) rgba;
        //        *(cast(ubyte*) &surfacePtr[2 + j3]) = cast(ubyte) (rgba >> 16);
        //        j3 += 3;
        //    }
        //    programPtr += pxgfx.settings.pitch;
        //    surfacePtr += pxgfx.window.surface.pitch;
        //}
    }
    else if(surfaceFormat == PixelFormat.ARGB8888 && mode is Mode.Truecolor24Bit) {
        pxgfxFlipSurfaceImpl!(() {
            const uint rgb = *(cast(const(uint)*) programPtr);
            programPtr += 4;
            return rgb;
        },
        (in uint rgb) {
            *(cast(ubyte*) (surfacePtr + 1)) = cast(ubyte) rgb;
            *(cast(ushort*) (surfacePtr + 2)) = cast(ushort) (rgb >> 8);
            surfacePtr += 4;
        })(
            rows, width, pxgfx.settings.pitch, pxgfx.window.surface.pitch,
            programPtr, surfacePtr,
        );
    }
    else {
        // Shouldn't happen - Should be caught in advance by pxgfx.init
        assert(false, "Unsupported pixel format.");
    }
    pxgfx.window.unlockSurface();
    pxgfx.window.flipSurface();
    if(pxgfx.settings.frameLimit > 0) {
        // Expected microseconds per frame
        const limitMicroseconds = pxgfx.settings.frameLimitMicroseconds;
        // Microseconds since the last pxgfx.flip ecall
        const deltaMicroseconds = (
            (monotonicns() - pxgfx.lastFlipNanoseconds) / 1_000
        );
        if(deltaMicroseconds < limitMicroseconds) {
            const waitMicroseconds = limitMicroseconds - deltaMicroseconds;
            const waitFraction = waitMicroseconds % 1_000;
            uint waitMilliseconds = cast(uint) (waitMicroseconds / 1_000);
            if(waitFraction >= 875) {
                waitMilliseconds += (pxgfx.ticks & 7 ? 1 : 0);
            }
            if(waitFraction >= 750) {
                waitMilliseconds += (pxgfx.ticks & 3 ? 1 : 0);
            }
            if(waitFraction >= 600) {
                // 60 fps -> 16.666 ms/f
                // 24 fps -> 41.666 ms/f
                waitMilliseconds += (pxgfx.ticks % 3 > 0 ? 1 : 0);
            }
            else if(waitFraction >= 500) {
                waitMilliseconds += (pxgfx.ticks & 1 ? 1 : 0);
            }
            else if(waitFraction >= 300) {
                // 120 fps -> 8.333 ms/f
                // 30 fps -> 33.333 ms/f
                waitMilliseconds += (pxgfx.ticks % 3 > 1 ? 1 : 0);
            }
            else if(waitFraction >= 250) {
                waitMilliseconds += ((pxgfx.ticks & 3) == 3 ? 1 : 0);
            }
            else if(waitFraction >= 125) {
                waitMilliseconds += ((pxgfx.ticks & 7) == 7 ? 1 : 0);
            }
            //stdio.writeln(writeInt(endi), " UNDER ms budget: ", writeInt(waitMilliseconds));
            SDL_Delay(waitMilliseconds);
        }
        //else {
        //    stdio.writeln(writeInt(endi), " OVER ms budget: ", writeInt(
        //        cast(uint) ((limitMicroseconds - deltaMicroseconds) / 1_000)
        //    ), " (delta microseconds: ", writeInt(deltaMicroseconds), ")");
        //}
    }
    pxgfx.ticks++;
    pxgfx.lastFlipNanoseconds = monotonicns();
    return CapsuleExtensionCallResult.Ok(0);
}
