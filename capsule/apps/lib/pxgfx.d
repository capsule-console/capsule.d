module capsule.apps.lib.pxgfx;

version(CapsuleSDL2Graphics):

import core.stdc.string : memcpy;

import capsule.core.engine : CapsuleEngine, CapsuleExtensionCallResult;
import capsule.core.enums : getEnumMemberName;
import capsule.core.file : File, FileWriter;
import capsule.core.hex : getHexString;
import capsule.core.math : isPow2;
import capsule.core.range : toArray;

import capsule.apps.lib.extcommon : CapsuleExtensionMixin;
import capsule.sdl : CapsuleSDL, CapsuleSDLWindow;

public:

struct CapsuleSDLPixelGraphics {
    mixin CapsuleExtensionMixin;
    
    alias ecall_pxgfx_init = .ecall_pxgfx_init;
    alias ecall_pxgfx_flip = .ecall_pxgfx_flip;
    
    alias Mode = CapsuleSDLPixelGraphicsMode;
    alias PixelFormat = CapsuleSDLWindow.PixelFormat;
    alias Resolution = CapsuleSDLPixelGraphicsResolution;
    alias Settings = CapsuleSDLPixelGraphicsInitSettings;
    alias Window = CapsuleSDLWindow;
    
    /// Global instance shared by ecalls
    static typeof(this) global;
    
    int scale = 1;
    string windowTitle = "Capsule";
    Window window;
    Resolution[] resolutionList;
    Settings settings;
    
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
    
    static bool isSupportedWindowPixelFormat(in PixelFormat format) {
        switch(format) {
            case PixelFormat.RGB24: goto case;
            case PixelFormat.RGB888: goto case;
            case PixelFormat.RGBA8888: goto case;
            case PixelFormat.ARGB8888: return true;
            default: return false;
        }
    }
}

struct CapsuleSDLPixelGraphicsResolution {
    int width;
    int height;
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
}

CapsuleExtensionCallResult ecall_pxgfx_init(
    CapsuleEngine* engine, in uint arg
) {
    // TODO: Return status flag instead of always producing an exception
    // TODO: Should pixel and palette ptrs be absolute? (I think no..?)
    // TODO: Should ptrs be relative to the beginning of the struct?
    alias Mode = CapsuleSDLPixelGraphicsMode;
    alias PixelFormat = CapsuleSDLWindow.PixelFormat;
    alias Settings = CapsuleSDLPixelGraphicsInitSettings;
    alias pxgfx = CapsuleSDLPixelGraphics.global;
    if(pxgfx.window.ok) {
        pxgfx.addErrorMessage("pxgfx.init: Already initialized.");
        return CapsuleExtensionCallResult.ExtError;
    }
    if(!CapsuleSDL.loaded) {
        CapsuleSDL.load();
    }
    if(!CapsuleSDL.initialized) {
        CapsuleSDL.initialize(cast(uint) CapsuleSDL.System.Video);
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
        return CapsuleExtensionCallResult.ExtError;
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
        return CapsuleExtensionCallResult.ExtError;
    }
    pxgfx.window = CapsuleSDLWindow(
        pxgfx.windowTitle,
        pxgfx.scale * settings.resolutionX,
        pxgfx.scale * settings.resolutionY,
        CapsuleSDLWindow.Flag.Shown
    );
    if(!pxgfx.window.ok) {
        pxgfx.addErrorMessage("pxgfx.init: Failed to create window.");
        return CapsuleExtensionCallResult.ExtError;
    }
    else if(!CapsuleSDLPixelGraphics.isSupportedWindowPixelFormat(
        cast(PixelFormat) pxgfx.window.surface.format.format
    )) {
        const format = pxgfx.window.surface.format.format;
        const formatName = getEnumMemberName(cast(PixelFormat) format);
        pxgfx.addErrorMessage(
            "pxgfx.init: Unsupported window pixel format " ~
            toArray(getHexString(format)) ~
            (formatName.length ? " " ~ formatName : "")
        );
        return CapsuleExtensionCallResult.ExtError;
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

CapsuleExtensionCallResult ecall_pxgfx_flip(
    CapsuleEngine* engine, in uint arg
) {
    alias Mode = CapsuleSDLPixelGraphicsMode;
    alias PixelFormat = CapsuleSDLWindow.PixelFormat;
    alias pxgfx = CapsuleSDLPixelGraphics.global;
    bool checkProgramMemory(in int address, in int length) {
        return (
            address >= 0 && length >= 0 &&
            address <= int.max && length <= int.max &&
            (int.max - address) >= length &&
            (address + length) < engine.mem.length
        );
    }
    if(!pxgfx.ok) {
        pxgfx.addErrorMessage("pxgfx.flip: Module not initialized.");
        return CapsuleExtensionCallResult.ExtError;
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
        return CapsuleExtensionCallResult.ExtError;
    }
    const(ubyte)* programPtr = (
        engine.mem.data + pxgfx.settings.pixelsPtr
    );
    pxgfx.window.lockSurface();
    if(mode is Mode.Truecolor24Bit && pxgfx.scale == 1 && (
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
    return CapsuleExtensionCallResult.Ok(0);
}
