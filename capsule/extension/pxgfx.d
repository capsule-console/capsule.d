/**

This module implements Capsule's pixel graphics extensions (pxgfx)
via the SDL library.

http://www.libsdl.org/

*/

module capsule.extension.pxgfx;

version(CapsuleLibrarySDL2):

private:

import core.stdc.string : memcpy;

import capsule.core.engine : CapsuleEngine, CapsuleExtensionCallResult;
import capsule.meta.enums : getEnumMemberName;
import capsule.io.file : File, FileWriter;
import capsule.string.hex : getHexString;
import capsule.math.ispow2 : isPow2;
import capsule.meta.templates : Aliases;
import capsule.range.range : toArray;
import capsule.string.hex : writeHexDigits;
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
    
    static enum RequiredSDLSubSystems = (
        CapsuleSDL.System.Video
    );
    
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
    /// Title to use for the application window
    string windowTitle = "Capsule";
    /// Reference to an SDL_Window containing the application image data
    Window window;
        
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
}

struct CapsuleSDLPixelGraphicsResolution {
    int width = 0;
    int height = 0;
    int scale = 1; // TODO
}

enum CapsuleSDLPixelGraphicsMode: uint {
    Indexed1Bit = 0x01,
    Indexed2Bit = 0x02,
    Indexed4Bit = 0x03,
    Indexed8Bit = 0x04,
    Truecolor24Bit = 0x80,
}

uint capsuleSDLPixelGraphicsModeBitsPerPixel(
    in CapsuleSDLPixelGraphicsMode mode
) nothrow pure @safe @nogc {
    alias Mode = CapsuleSDLPixelGraphicsMode;
    final switch(mode) {
        case Mode.Indexed1Bit: return 1;
        case Mode.Indexed2Bit: return 2;
        case Mode.Indexed4Bit: return 4;
        case Mode.Indexed8Bit: return 8;
        case Mode.Truecolor24Bit: return 32;
    }
}

struct CapsuleSDLPixelGraphicsInitSettings {
    alias Mode = CapsuleSDLPixelGraphicsMode;
    
    int resolutionX;
    int resolutionY;
    int pitch;
    Mode mode;
    int pixelsPtr;
    int palettePtr;
    uint[2] unused;
    
    bool ok() const {
        return (
            this.resolutionX > 0 &&
            this.resolutionY > 0 &&
            isPow2(this.pitch)
        );
    }
    
    int pixelsLength() const {
        return this.resolutionY * this.pitch;
    }
}

/// Implement pxgfx.init extension.
/// The data pointer must refer to a CapsuleSDLPixelGraphicsModule instance.
CapsuleExtensionCallResult ecall_pxgfx_init(
    void* data, CapsuleEngine* engine, in uint arg
) {
    assert(data);
    // TODO: Return status flag instead of always producing an exception
    // TODO: SDL_Texture and SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "nearest"); 
    alias Mode = CapsuleSDLPixelGraphicsMode;
    alias PixelFormat = CapsuleSDLWindow.PixelFormat;
    alias Settings = CapsuleSDLPixelGraphicsInitSettings;
    auto pxgfx = cast(CapsuleSDLPixelGraphicsModule*) data;
    // Fail if the module was already initialized
    if(pxgfx.window.ok) {
        pxgfx.addErrorMessage("pxgfx.init: Already initialized.");
        return CapsuleExtensionCallResult.Error;
    }
    // Load init information from program memory
    const lResX = engine.mem.loadWord(arg);
    const lResY = engine.mem.loadWord(arg + 4);
    const lPitch = engine.mem.loadWord(arg + 8);
    const lMode = engine.mem.loadWord(arg + 12);
    const lPixelsPtr = engine.mem.loadWord(arg + 16);
    const lPalettePtr = engine.mem.loadWord(arg + 20);
    const lUnused0 = engine.mem.loadWord(arg + 24);
    const lUnused1 = engine.mem.loadWord(arg + 28);
    if(
        !lResX.ok || !lResY.ok || !lPitch.ok || !lMode.ok ||
        !lPixelsPtr.ok || !lPalettePtr.ok || !lUnused0.ok || !lUnused1.ok
    ) {
        pxgfx.addErrorMessage("pxgfx.init: Invalid settings pointer.");
        return CapsuleExtensionCallResult.Error;
    }
    // Put together the pxgfx settings struct
    Settings settings = {
        resolutionX: lResX.value,
        resolutionY: lResY.value,
        pitch: lPitch.value,
        mode: cast(Mode) lMode.value,
        pixelsPtr: lPixelsPtr.value + arg,
        palettePtr: lPalettePtr.value + arg,
        //frameLimit: cast(ushort) lFrameLimit.value,
        unused: [lUnused0.value, lUnused1.value],
    };
    pxgfx.settings = settings;
    if(!settings.ok) {
        pxgfx.addErrorMessage("pxgfx.init: Invalid settings data.");
        return CapsuleExtensionCallResult.Error;
    }
    if(!pxgfxCheckProgramMemory(
        engine.mem.length, pxgfx.settings.pixelsPtr, pxgfx.settings.pixelsLength
    )) {
        const ptrHex = writeHexDigits(pxgfx.settings.pixelsPtr);
        pxgfx.addErrorMessage(
            "pxgfx.init: Invalid pixel data pointer 0x" ~ ptrHex ~ "."
        );
        return CapsuleExtensionCallResult.Error;
    }
    // Make sure the SDL dependency is loaded and initialized
    CapsuleSDL.ensureInitialized();
    // Create application window via SDL
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
    // Initialize the window's graphics data to solid black
    pxgfx.window.fillColor(0, 0, 0);
    pxgfx.window.flipSurface();
    // All done!
    return CapsuleExtensionCallResult.Ok(0);
}

// Helper function to make sure that the pixel data address and size
// are entirely within the bounds of valid program memory.
static bool pxgfxCheckProgramMemory(
    in uint memoryLength, in int address, in int length
) {
    return (
        address >= 0 && length >= 0 &&
        address <= int.max && length <= int.max &&
        (int.max - address) >= length &&
        (address + length) <= memoryLength
    );
}

// Used by the pxgfx.flip extension implementation.
// Uses template parameters and conditional compilation to make the
// hot inner loop as optimized as possible for the most common cases,
// and reasonably well optimized for all others.
private void pxgfxFlip(
    CapsuleSDLPixelGraphicsMode ProgramGraphicsMode,
    ubyte SurfaceBytesPerPixel, bool AnyLoss
)(
    in int rows, in int width,
    in SDL_PixelFormat* surfacePixelFormat,
    ubyte* surfacePixelsPtr, in int surfacePixelsPitch,
    const(ubyte)* programPixelsPtr, in int programPixelsPitch,
) {
    alias Mode = CapsuleSDLPixelGraphicsMode;
    alias format = surfacePixelFormat;
    // Outer loop
    for(int i = 0; i < rows; i++) {
        // Initialize extra variable used to optimize 3-byte pixel formats
        static if(SurfaceBytesPerPixel == 3) int j3 = 0;
        // Hot inner loop
        for(int j = 0; j < width; j++) {
            // Get program's RGB for this pixel
            static if(ProgramGraphicsMode is Mode.Truecolor24Bit) {
                const uint src = (cast(const(uint)*) programPixelsPtr)[j];
            }
            else {
                static assert(false, "Unsupported pxgfx display mode.");
            }
            // For truecolor pixel formats, transform the program RGB value
            // into a surface RGB value
            static if(SurfaceBytesPerPixel > 1) {
                // Common pixel formats will not need a loss shift operation
                // so cut out those shifts entirely if possible
                static if(!AnyLoss) const uint dst = cast(uint) (format.Amask | (
                    (((src >> 16) & 0xff) << format.Rshift) |
                    (((src >> 8) & 0xff) << format.Gshift) |
                    (((src) & 0xff) << format.Bshift)
                ));
                // Otherwise just do the shifts
                static if(AnyLoss) const uint dst = cast(uint) (format.Amask | (
                    ((((src >> 16) & 0xff) >> format.Rloss) << format.Rshift) |
                    ((((src >> 8) & 0xff) >> format.Gloss) << format.Gshift) |
                    ((((src) & 0xff) >> format.Bloss) << format.Bshift)
                ));
            }
            // Write truecolor value for different byte lengths
            static if(SurfaceBytesPerPixel == 4) {
                (cast(uint*) surfacePixelsPtr)[j] = dst;
            }
            else static if(SurfaceBytesPerPixel == 3) {
                surfacePixelsPtr[j3 + 0] = cast(ubyte) dst;
                surfacePixelsPtr[j3 + 1] = cast(ubyte) (dst >> 8);
                surfacePixelsPtr[j3 + 2] = cast(ubyte) (dst >> 16);
                j3 += 3;
            }
            else static if(SurfaceBytesPerPixel == 2) {
                (cast(ushort*) surfacePixelsPtr)[j] = cast(ushort) dst;
            }
            // Find and write the index of the nearest palette match
            // for indexed pixel formats. Uses a perceptual color distance
            // rather than absolute color distance - though if anyone is
            // actually running Capsule on a display with indexed colors,
            // there should probably be an option to choose from some
            // color distance calculations.
            // https://wiki.libsdl.org/SDL_Palette
            else static if(SurfaceBytesPerPixel == 1) {
                // Find the nearest palette color
                uint nearestIndex = 0;
                uint nearestDistance = uint.max;
                const int sr = cast(int) ((src >> 16) & 0xff);
                const int sg = cast(int) ((src >> 8) & 0xff);
                const int sb = cast(int) ((src) & 0xff);
                for(uint x = 0; x < format.palette.ncolors; x++) {
                    const color = format.palette.colors[x];
                    const dr = (color.r >= sr ? color.r - sr : sr - color.r);
                    const dg = (color.g >= sg ? color.g - sg : sg - color.g);
                    const db = (color.b >= sb ? color.b - sb : sb - color.b);
                    // 7G + 2R + 1B is close to typical luma coefficients
                    // https://en.wikipedia.org/wiki/Luma_(video)
                    const distance = (dg << 3) - dg + (dr << 1) + db;
                    if(distance < nearestDistance) {
                        nearestDistance = distance;
                        nearestIndex = x;
                    }
                }
                // Assign it to this surface pixel
                surfacePixelsPtr[j] = cast(ubyte) nearestIndex;
            }
            // Shouldn't happen; SDL docs say BytesPerPixel is
            // either 1, 2, 3, or 4.
            // https://wiki.libsdl.org/SDL_PixelFormat
            else {
                static assert(false, "Invalid number of bytes per pixel.");
            }
        }
        // Move pointers to the next row of pixels
        programPixelsPtr += programPixelsPitch;
        surfacePixelsPtr += surfacePixelsPitch;
    }
}

CapsuleExtensionCallResult ecall_pxgfx_flip(
    void* data, CapsuleEngine* engine, in uint arg
) {
    assert(data);
    alias Mode = CapsuleSDLPixelGraphicsMode;
    alias PixelFormat = CapsuleSDLWindow.PixelFormat;
    // Get module context object
    auto pxgfx = cast(CapsuleSDLPixelGraphicsModule*) data;
    if(!pxgfx.ok) {
        pxgfx.addErrorMessage("pxgfx.flip: Module not initialized.");
        return CapsuleExtensionCallResult.Error;
    }
    // Define a lot of constants
    const format = pxgfx.window.surface.format;
    const BytesPerPixel = format.BytesPerPixel;
    const width = pxgfx.settings.resolutionX;
    const rows = pxgfx.settings.resolutionY;
    const surfacePixelsPitch = pxgfx.window.surface.pitch;
    const mode = pxgfx.settings.mode;
    const anyLoss = (format.Rloss || format.Gloss || format.Bloss);
    // Make sure the expected pixel data span is all in valid program memory
    if(!pxgfxCheckProgramMemory(
        engine.mem.length, pxgfx.settings.pixelsPtr, pxgfx.settings.pixelsLength
    )) {
        pxgfx.addErrorMessage("pxgfx.flip: Invalid pixel data pointer.");
        return CapsuleExtensionCallResult.Error;
    }
    // Actually blit the program's pixel data buffer to the window's surface
    pxgfx.window.lockSurface();
    ubyte* surfacePixelsPtr = cast(ubyte*) pxgfx.window.surface.pixels;
    const(ubyte)* programPixelsPtr = cast(const(ubyte)*) (
        engine.mem.data + pxgfx.settings.pixelsPtr
    );
    alias FlipModes = Aliases!(Mode.Truecolor24Bit);
    foreach(FlipMode; FlipModes) {
        foreach(FlipBPP; Aliases!(1, 2, 3, 4)) {
            foreach(FlipAnyLoss; Aliases!(false, true)) {
                if(mode is FlipMode &&
                    anyLoss == FlipAnyLoss && BytesPerPixel == FlipBPP
                ) {
                    pxgfxFlip!(FlipMode, FlipBPP, FlipAnyLoss)(
                        rows, width, format,
                        surfacePixelsPtr, surfacePixelsPitch,
                        programPixelsPtr, pxgfx.settings.pitch
                    );
                }
            }
        }
    }
    pxgfx.window.unlockSurface();
    // Render the updated surface
    pxgfx.window.flipSurface();
    // All done
    return CapsuleExtensionCallResult.Ok(0);
}
