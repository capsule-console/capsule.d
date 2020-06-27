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
import capsule.math.divceil : divceil;
import capsule.math.ispow2 : isPow2;
import capsule.meta.templates : Aliases;
import capsule.range.range : toArray;
import capsule.string.hex : writeHexDigits;
import capsule.string.writeint : writeInt;
import capsule.time.monotonic : monotonicns;

import capsule.core.extension : CapsuleExtension;

import capsule.extension.common : CapsuleModuleMixin;
import capsule.extension.list : CapsuleExtensionListEntry;

import capsule.sdl.events : CapsuleSDLEventQueue, CapsuleSDLEventType;
import capsule.sdl.events : CapsuleSDLWindowEventID;
import capsule.sdl.renderer : CapsuleSDLRenderer;
import capsule.sdl.sdl : CapsuleSDL;
import capsule.sdl.texture : CapsuleSDLTexture;
import capsule.sdl.types : CapsuleSDLPixelFormat;
import capsule.sdl.window : CapsuleSDLWindow;

import derelict.sdl2.sdl;

public:

enum CapsuleSDLPixelGraphicsDisplayMode: uint {
    Indexed1Bit = 0x01,
    Indexed2Bit = 0x02,
    Indexed4Bit = 0x03,
    Indexed8Bit = 0x04,
    Truecolor24Bit = 0x80,
}


/// https://wiki.libsdl.org/SDL_HINT_RENDER_SCALE_QUALITY
enum CapsuleSDLRenderScaleQuality: char {
    Nearest = '0',
    Linear = '1',
    Anisotropic = '2',
}

struct CapsuleSDLPixelGraphicsScalingMode {
    nothrow @safe @nogc:
    
    /// Whether to always display the program's graphics output at a 1:1
    /// scale, even if this leaves a lot of unused space in the render,
    /// or else to allow scaling the image up to fill more of the screen.
    bool allowScalingUp = false;
    /// Whether to allow scaling the program's graphics output down to
    /// a smaller image if it is only able to support resolutions above that
    /// offered by the available settings.
    bool allowScalingDown = false;
    /// Whether to allow scaling to sizes that are not an exact multiple
    /// of the original size, i.e. whether to allow non-pixel-perfect scaling.
    bool allowScalingFractional = false;
    /// Whether to allow scaling by different amounts on the X and Y
    /// axes, versus only ever scaling both axes by the same amount.
    bool allowScalingStreched = false;
    
    bool allowScalingStrechedFractional() pure const {
        return this.allowScalingFractional && this.allowScalingStreched;
    }
}

struct CapsuleSDLPixelGraphicsResolution {
    nothrow @safe @nogc:
    
    int width = 0;
    int height = 0;
    
    bool opCast(T: bool)() pure const {
        return this.width > 0 && this.height > 0;
    }
    
    int getCompatibility(in int resolutionX, in int resolutionY) pure const {
        if(resolutionX <= this.width && resolutionY <= this.height) {
            return (this.width - resolutionX) + (this.height - resolutionY);
        }
        else {
            const dx = resolutionX - this.width;
            const dy = resolutionY - this.height;
            return (dx > 0 ? -dx : dx) + (dy > 0 ? -dy : dy);
        }
    }
}

struct CapsuleSDLPixelGraphicsModule {
    mixin CapsuleModuleMixin;
    
    alias ecall_pxgfx_init = .ecall_pxgfx_init;
    alias ecall_pxgfx_flip = .ecall_pxgfx_flip;
    
    alias Extension = CapsuleExtension;
    alias DisplayMode = CapsuleSDLPixelGraphicsDisplayMode;
    alias PixelFormat = CapsuleSDLPixelFormat;
    alias Renderer = CapsuleSDLRenderer;
    alias Resolution = CapsuleSDLPixelGraphicsResolution;
    alias Settings = CapsuleSDLPixelGraphicsInitSettings;
    alias ScaleQuality = CapsuleSDLRenderScaleQuality;
    alias ScalingMode = CapsuleSDLPixelGraphicsScalingMode;
    alias Texture = CapsuleSDLTexture;
    alias Window = CapsuleSDLWindow;
    
    static enum RequiredSDLSubSystems = (
        CapsuleSDL.System.Video
    );
    
    /// TODO: A list of resolutions that the host will permit the
    /// application to run at
    Resolution[] resolutionList;
    /// The settings that were indicated in a pxgfx.init ecall
    Settings settings;
    /// Title to use for the application window
    string windowTitle = "Capsule";
    /// Reference to an SDL_Window containing the application image data
    Window window;
    /// Rendered used when rendering program data.
    Renderer renderer;
    /// Texture used when rendering program image data.
    Texture texture;
    /// Will hold a pointer to an SDL_PixelFormat struct describing the
    /// texture's format, when a texture was created.
    SDL_PixelFormat* texturePixelFormat = null;
    /// Setting to use when scaling the program image to fit.
    ScaleQuality scaleQuality = ScaleQuality.Nearest;
    /// Settings regarding how the program's output image may be scaled
    /// or otherwise distorted in order to better fit the available space.
    ScalingMode scalingMode;
    
    this(MessageCallback onMessage) {
        this.onMessage = onMessage;
        this.resolutionList = [Resolution(256, 256)]; // TODO: Don't hardcode
    }
    
    bool ok() pure const {
        return this.window.ok && this.settings.ok;
    }
    
    void conclude() {
        if(this.texturePixelFormat !is null) {
            SDL_FreeFormat(this.texturePixelFormat);
            this.texturePixelFormat = null;
        }
        this.texture.free();
        this.renderer.free();
        this.window.free();
        if(CapsuleSDL.initialized) {
            CapsuleSDL.quit();
        }
        if(CapsuleSDL.loaded) {
            CapsuleSDL.unload();
        }
    }
    
    SDL_PixelFormat* allocTextureFormat() {
        return (this.texture.ok ?
            SDL_AllocFormat(this.texture.getPixelFormat()) : null
        );
    }
    
    auto getMostCompatibleResolution(
        in int resolutionX, in int resolutionY
    ) pure const {
        struct Result {
            int compatibility;
            Resolution resolution;
        }
        auto bestResolution = Resolution.init;
        int bestCompatibility = int.min;
        foreach(resolution; this.resolutionList) {
            const int compat = resolution.getCompatibility(
                resolutionX, resolutionY
            );
            const isImprovement = (bestCompatibility >= 0 ?
                compat < bestCompatibility : compat > bestCompatibility
            );
            if(isImprovement) {
                bestResolution = resolution;
                bestCompatibility = compat;
            }
        }
        return Result(bestCompatibility, bestResolution);
    }
    
    CapsuleExtensionListEntry[] getExtensionList() {
        alias Entry = CapsuleExtensionListEntry;
        return [
            Entry(Extension.pxgfx_init, &ecall_pxgfx_init, &this),
            Entry(Extension.pxgfx_flip, &ecall_pxgfx_flip, &this),
        ];
    }
}

struct CapsuleSDLPixelGraphicsInitSettings {
    nothrow @safe @nogc:
    
    alias DisplayMode = CapsuleSDLPixelGraphicsDisplayMode;
    alias ScalingMode = CapsuleSDLPixelGraphicsScalingMode;
    
    /// Program's horizontal display resolution.
    int resolutionX;
    /// Program's vertical display resolution.
    int resolutionY;
    /// Number of bytes per row of pixels. Must be a power of two.
    int pitch;
    /// Program pixel data display mode.
    DisplayMode displayMode;
    /// Pointer to pixel data in program memory.
    int pixelsPtr;
    /// Pointer to palette data in program memory, when applicable.
    int palettePtr;
    /// As yet unused padding.
    uint[2] unused;
    
    /// Width at which to display the program's image data within the
    /// render target.
    int imageWidth;
    /// Height at which to display the program's image data within the
    /// render target.
    int imageHeight;
    
    bool ok() pure const {
        return (
            this.resolutionX > 0 &&
            this.resolutionY > 0 &&
            isPow2(this.pitch)
        );
    }
    
    int pixelsLength() pure const {
        return this.resolutionY * this.pitch;
    }
}

uint capsuleSDLPixelGraphicsDisplayModeBitsPerPixel(
    in CapsuleSDLPixelGraphicsDisplayMode displayMode
) nothrow pure @safe @nogc {
    alias DisplayMode = CapsuleSDLPixelGraphicsDisplayMode;
    final switch(displayMode) {
        case DisplayMode.Indexed1Bit: return 1;
        case DisplayMode.Indexed2Bit: return 2;
        case DisplayMode.Indexed4Bit: return 4;
        case DisplayMode.Indexed8Bit: return 8;
        case DisplayMode.Truecolor24Bit: return 32;
    }
}

// Helper function to make sure that the pixel data address and size
// are entirely within the bounds of valid program memory.
static bool pxgfxCheckProgramMemory(
    in uint memoryLength, in int address, in int length
) pure nothrow @safe @nogc {
    return (
        address >= 0 && length >= 0 &&
        address <= int.max && length <= int.max &&
        (int.max - address) >= length &&
        (address + length) <= memoryLength
    );
}

/// Get an appropriate image target size given a program's
/// pxgfx resolution, the console's display width and height, and some
/// given image scaling settings.
auto getCapsulePixelGraphicsImageSize(
    in CapsuleSDLPixelGraphicsScalingMode scalingMode,
    in int displayWidth, in int displayHeight,
    in int resolutionX, in int resolutionY,
) pure nothrow @safe @nogc {
    // Define the function's return type
    struct Result {
        int width;
        int height;
    }
    // Handle cases where scaling settings are not compatible with
    // this display size and program image resolution combination
    const imageBigger = (
        resolutionX > displayWidth || resolutionY > displayHeight
    );
    const imageSmaller = (
        resolutionX < displayWidth && resolutionY < displayHeight
    );
    if((imageBigger && !scalingMode.allowScalingDown) ||
        (imageSmaller && !scalingMode.allowScalingUp)
    ) {
        return Result(resolutionX, resolutionY);
    }
    // Easiest case: stretch to fit
    if(scalingMode.allowScalingStrechedFractional) {
        return Result(displayWidth, displayHeight);
    }
    // Otherwise the aspect ratio will be maintained
    const int dx = resolutionX - displayWidth;
    const int dy = resolutionY - displayHeight;
    int imageWidth;
    int imageHeight;
    // Scale up/down to fit while maintaining image aspect ratio
    if(scalingMode.allowScalingFractional) {
        if(dx >= dy) {
            imageWidth = displayWidth;
            imageHeight = (displayWidth * resolutionY) / resolutionX;
        }
        else {
            imageHeight = displayHeight;
            imageWidth = (resolutionX * displayHeight) / resolutionY;
        }
    }
    // Scale down by an integer factor, maintaining image aspect ratio
    else if(imageBigger) {
        if(dx >= dy) {
            const int scale = divceil(resolutionX, displayWidth);
            assert(scale >= 1);
            imageWidth = resolutionX / scale;
            imageHeight = resolutionY / scale;
        }
        else {
            const int scale = divceil(resolutionY, displayHeight);
            assert(scale >= 1);
            imageWidth = resolutionX / scale;
            imageHeight = resolutionY / scale;
        }
    }
    // Scale up by an integer factor, maintaining image aspect ratio
    else {
        if(dx >= dy) {
            const int scale = displayWidth / resolutionX;
            assert(scale >= 1);
            imageWidth = resolutionX * scale;
            imageHeight = resolutionY * scale;
        }
        else {
            const int scale = displayHeight / resolutionY;
            assert(scale >= 1);
            imageWidth = resolutionX * scale;
            imageHeight = resolutionY * scale;
        }
    }
    // All done
    assert(imageWidth <= displayWidth);
    assert(imageHeight <= displayHeight);
    return Result(imageWidth, imageHeight);
}

// Used by the pxgfx.flip extension implementation to render to a locked
// surface or texture. Wraps pxgfxFlipImpl.
private void pxgfxFlip(
    in CapsuleSDLPixelGraphicsDisplayMode displayMode,
    in int width, in int rows,
    in SDL_PixelFormat* targetPixelsFormat, in bool ignoredAlphaChannel,
    ubyte* targetPixelsPtr, in int targetPixelsPitch,
    const(ubyte)* programPixelsPtr, in int programPixelsPitch,
) {
    alias DisplayMode = CapsuleSDLPixelGraphicsDisplayMode;
    alias FlipModes = Aliases!(DisplayMode.Truecolor24Bit);
    const BytesPerPixel = targetPixelsFormat.BytesPerPixel;
    const bool anyLoss = (
        targetPixelsFormat.Rloss ||
        targetPixelsFormat.Gloss ||
        targetPixelsFormat.Bloss
    );
    foreach(FlipMode; FlipModes) {
        foreach(FlipBPP; Aliases!(1, 2, 3, 4)) {
            foreach(FlipAnyLoss; Aliases!(false, true)) {
                if(displayMode is FlipMode &&
                    anyLoss == FlipAnyLoss && BytesPerPixel == FlipBPP
                ) {
                    pxgfxFlipImpl!(FlipMode, FlipBPP, FlipAnyLoss)(
                        rows, width, targetPixelsFormat, ignoredAlphaChannel,
                        targetPixelsPtr, targetPixelsPitch,
                        programPixelsPtr, programPixelsPitch,
                    );
                    return;
                }
            }
        }
    }
    // If execution reached here, it meant that none of the handled
    // template parameter combinations matched this function's runtime
    // program image display mode and surface format information.
    assert(false,
        "Unhandled pxgfx display mode and surface format combination."
    );
}

// Used by the pxgfx.flip extension implementation, via pxgfxFlip.
// Uses template parameters and conditional compilation to make the
// hot inner loop as optimized as possible for the most common cases,
// and reasonably well optimized for all others.
private void pxgfxFlipImpl(
    CapsuleSDLPixelGraphicsDisplayMode ProgramGraphicsDisplayMode,
    ubyte SurfaceBytesPerPixel, bool AnyLoss
)(
    in int width, in int rows,
    in SDL_PixelFormat* targetPixelsFormat, in bool ignoredAlphaChannel,
    ubyte* targetPixelsPtr, in int targetPixelsPitch,
    const(ubyte)* programPixelsPtr, in int programPixelsPitch,
) {
    alias DisplayMode = CapsuleSDLPixelGraphicsDisplayMode;
    alias PixelFormat = CapsuleSDLPixelFormat;
    alias format = targetPixelsFormat;
    // Handle an ideal case for Truecolor24 where the pixel format is either
    // RGB888, or ARGB8888 with the alpha channel ignored, since these
    // formats place the RGB channels in the same places as the Truecolor24
    // pxgfx image display mode.
    static if(ProgramGraphicsDisplayMode is DisplayMode.Truecolor24Bit) {
        if(format.format == PixelFormat.RGB888 ||
            (ignoredAlphaChannel &&  format.format == PixelFormat.ARGB8888)
        ) {
            const rowByteLength = 4 * width;
            for(int i = 0; i < rows; i++) {
                memcpy(targetPixelsPtr, programPixelsPtr, rowByteLength);
                programPixelsPtr += programPixelsPitch;
                targetPixelsPtr += targetPixelsPitch;
            }
            return;
        }
    }
    // Outer loop for cases that must explicitly enumerate every pixel
    for(int i = 0; i < rows; i++) {
        // Initialize extra variable used to optimize 3-byte pixel formats
        static if(SurfaceBytesPerPixel == 3) int j3 = 0;
        // Hot inner loop
        for(int j = 0; j < width; j++) {
            // Get program's RGB for this pixel
            static if(ProgramGraphicsDisplayMode is DisplayMode.Truecolor24Bit) {
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
                (cast(uint*) targetPixelsPtr)[j] = dst;
            }
            else static if(SurfaceBytesPerPixel == 3) {
                targetPixelsPtr[j3 + 0] = cast(ubyte) dst;
                targetPixelsPtr[j3 + 1] = cast(ubyte) (dst >> 8);
                targetPixelsPtr[j3 + 2] = cast(ubyte) (dst >> 16);
                j3 += 3;
            }
            else static if(SurfaceBytesPerPixel == 2) {
                (cast(ushort*) targetPixelsPtr)[j] = cast(ushort) dst;
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
                targetPixelsPtr[j] = cast(ubyte) nearestIndex;
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
        targetPixelsPtr += targetPixelsPitch;
    }
}

/// Implement pxgfx.init extension.
/// The data pointer must refer to a CapsuleSDLPixelGraphicsModule instance.
CapsuleExtensionCallResult ecall_pxgfx_init(
    void* data, CapsuleEngine* engine, in uint arg
) {
    assert(data);
    // TODO: Return a status flag instead of always producing an exception
    alias DisplayMode = CapsuleSDLPixelGraphicsDisplayMode;
    alias PixelFormat = CapsuleSDLPixelFormat;
    alias Renderer = CapsuleSDLRenderer;
    alias Settings = CapsuleSDLPixelGraphicsInitSettings;
    alias Texture = CapsuleSDLTexture;
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
    const lDisplayMode = engine.mem.loadWord(arg + 12);
    const lPixelsPtr = engine.mem.loadWord(arg + 16);
    const lPalettePtr = engine.mem.loadWord(arg + 20);
    const lUnused0 = engine.mem.loadWord(arg + 24);
    const lUnused1 = engine.mem.loadWord(arg + 28);
    if(
        !lResX.ok || !lResY.ok || !lPitch.ok || !lDisplayMode.ok ||
        !lPixelsPtr.ok || !lPalettePtr.ok || !lUnused0.ok || !lUnused1.ok
    ) {
        pxgfx.addErrorMessage("pxgfx.init: Invalid settings pointer.");
        return CapsuleExtensionCallResult.Error;
    }
    // Make sure the requested resolution is compatible with console settings
    auto resMatch = pxgfx.getMostCompatibleResolution(
        lResX.value, lResY.value
    );
    if(!resMatch.resolution) {
        pxgfx.addErrorMessage("pxgfx.init: No compatible display resolution.");
        return CapsuleExtensionCallResult.Error;
    }
    else {
        pxgfx.addDebugMessage(
            "pxgfx.init: Selected display resolution " ~
            writeInt(resMatch.resolution.width).getChars() ~ " x " ~
            writeInt(resMatch.resolution.height).getChars() ~ "."
        );
    }
    // Put together the pxgfx settings struct
    Settings settings = {
        resolutionX: lResX.value,
        resolutionY: lResY.value,
        pitch: lPitch.value,
        displayMode: cast(DisplayMode) lDisplayMode.value,
        pixelsPtr: lPixelsPtr.value + arg,
        palettePtr: lPalettePtr.value + arg,
        unused: [lUnused0.value, lUnused1.value],
    };
    pxgfx.settings = settings;
    pxgfx.addDebugMessage(
        "pxgfx.init: Initializing with display mode " ~
        getEnumMemberName(pxgfx.settings.displayMode)
    );
    pxgfx.addDebugMessage(
        "pxgfx.init: Initializing with resolution " ~
        writeInt(pxgfx.settings.resolutionX).getChars() ~ " x " ~
        writeInt(pxgfx.settings.resolutionY).getChars() ~ " and pitch " ~
        writeInt(pxgfx.settings.pitch).getChars()
    );
    if(!pxgfx.settings.ok) {
        pxgfx.addErrorMessage("pxgfx.init: Invalid or incompatible settings.");
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
        resMatch.resolution.width, resMatch.resolution.height,
        CapsuleSDLWindow.Flag.Shown
    );
    if(!pxgfx.window.ok) {
        pxgfx.window.free();
        pxgfx.addErrorMessage("pxgfx.init: Failed to create window.");
        return CapsuleExtensionCallResult.Error;
    }
    // Initialize a renderer and a texture
    const char[2] scaleQuality = [pxgfx.scaleQuality, 0];
    SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, scaleQuality.ptr);
    // Try to initialize using hardware acceleration
    pxgfx.renderer = Renderer.Create(
        pxgfx.window.handle, -1, Renderer.Flag.Accelerated
    );
    // If successful, also initialize the renderer and create a texture
    if(pxgfx.renderer.ok) {
        // Set renderer properties
        pxgfx.renderer.setBlendMode(Texture.BlendMode.None);
        // Try with RGB888
        pxgfx.texture = pxgfx.renderer.createTexture(
            PixelFormat.RGB888, Texture.Access.Streaming,
            pxgfx.settings.resolutionX, pxgfx.settings.resolutionY
        );
        // If that doesn't work, try again with ARGB8888
        if(!pxgfx.texture.ok) pxgfx.texture = pxgfx.renderer.createTexture(
            PixelFormat.ARGB8888, Texture.Access.Streaming,
            pxgfx.settings.resolutionX, pxgfx.settings.resolutionY
        );
        // Set texture properties
        if(pxgfx.texture.ok) {
            assert(pxgfx.texturePixelFormat is null);
            pxgfx.texture.setBlendMode(Texture.BlendMode.None);
            pxgfx.texturePixelFormat = pxgfx.allocTextureFormat();
        }
        // If none of that worked, give up on using a renderer
        else {
            pxgfx.renderer.free();
        }
    }
    // Initialize the window's graphics data to solid black (renderer)
    if(pxgfx.renderer.ok && pxgfx.texture.ok) {
        pxgfx.renderer.setColor(0, 0, 0);
        pxgfx.renderer.clear();
        pxgfx.renderer.present();
    }
    // Initialize the window's graphics data to solid black (no renderer)
    else {
        auto surface = pxgfx.window.getSurface();
        if(surface.ok) {
            surface.fillColor(0, 0, 0);
            pxgfx.window.flipSurface();
        }
    }
    // Determine program image scaling
    const windowSize = (
        pxgfx.renderer.ok && pxgfx.texture.ok ?
        pxgfx.renderer.getOutputSize() : pxgfx.window.getSize()
    );
    const imageSize = getCapsulePixelGraphicsImageSize(
        pxgfx.scalingMode, windowSize.width, windowSize.height,
        lResX.value, lResY.value
    );
    pxgfx.settings.imageWidth = imageSize.width;
    pxgfx.settings.imageHeight = imageSize.height;
    pxgfx.addDebugMessage(
        "pxgfx.init: Initializing with scaled image size " ~
        writeInt(pxgfx.settings.imageWidth).getChars() ~ " x " ~
        writeInt(pxgfx.settings.imageHeight).getChars() ~ "."
    );
    // All done!
    return CapsuleExtensionCallResult.Ok(0);
}

CapsuleExtensionCallResult ecall_pxgfx_flip(
    void* data, CapsuleEngine* engine, in uint arg
) {
    assert(data);
    // Get module context object
    auto pxgfx = cast(CapsuleSDLPixelGraphicsModule*) data;
    if(!pxgfx.ok) {
        pxgfx.addErrorMessage("pxgfx.flip: Module not initialized.");
        return CapsuleExtensionCallResult.Error;
    }
    // Make sure the expected pixel data span is all in valid program memory
    if(!pxgfxCheckProgramMemory(
        engine.mem.length, pxgfx.settings.pixelsPtr, pxgfx.settings.pixelsLength
    )) {
        pxgfx.addErrorMessage("pxgfx.flip: Invalid pixel data pointer.");
        return CapsuleExtensionCallResult.Error;
    }
    // Actually blit the program's pixel data buffer to the target
    // Blit to a hardware-accelerated texture if one was succesfully
    // initialized by pxgfx.init, otherwise use software rendering to
    // draw directly to the window surface.
    // TODO: Implement scaling and offset when drawing to the window surface
    if(pxgfx.renderer.ok && pxgfx.texture.ok) {
        auto textureLock = pxgfx.texture.lock();
        if(!textureLock.ok) {
            pxgfx.addErrorMessage("pxgfx.flip: Failed to lock texture.");
            return CapsuleExtensionCallResult.Error;
        }
        ubyte* texturePixelsPtr = cast(ubyte*) textureLock.pixels;
        const(ubyte)* programPixelsPtr = cast(const(ubyte)*) (
            engine.mem.data + pxgfx.settings.pixelsPtr
        );
        pxgfxFlip(
            pxgfx.settings.displayMode,
            pxgfx.settings.resolutionX, pxgfx.settings.resolutionY,
            pxgfx.texturePixelFormat, true,
            texturePixelsPtr, textureLock.pitch,
            programPixelsPtr, pxgfx.settings.pitch
        );
        pxgfx.texture.unlock();
        const renderSize = pxgfx.renderer.getOutputSize();
        const int dstX = (pxgfx.settings.imageWidth >= renderSize.width ? 0 :
            (renderSize.width - pxgfx.settings.imageWidth) / 2
        );
        const int dstY = (pxgfx.settings.imageHeight >= renderSize.height ? 0 :
            (renderSize.height - pxgfx.settings.imageHeight) / 2
        );
        const SDL_Rect dstRect = SDL_Rect(
            dstX, dstY, pxgfx.settings.imageWidth, pxgfx.settings.imageHeight
        );
        pxgfx.renderer.setColor(0, 0, 0);
        pxgfx.renderer.clear();
        pxgfx.renderer.copyTexture(pxgfx.texture.handle, null, &dstRect);
        pxgfx.renderer.present();
    }
    else {
        auto surface = pxgfx.window.getSurface();
        if(!surface.ok) {
            pxgfx.addErrorMessage("pxgfx.flip: Failed to get window surface.");
            return CapsuleExtensionCallResult.Error;
        }
        const lockOk = surface.lock();
        if(!lockOk) {
            pxgfx.addErrorMessage("pxgfx.flip: Failed to lock window surface.");
            return CapsuleExtensionCallResult.Error;
        }
        ubyte* surfacePixelsPtr = cast(ubyte*) surface.handle.pixels;
        const(ubyte)* programPixelsPtr = cast(const(ubyte)*) (
            engine.mem.data + pxgfx.settings.pixelsPtr
        );
        // TODO: Can a window's alpha channel be safely filled with junk?
        // https://discourse.libsdl.org/t/27820
        pxgfxFlip(
            pxgfx.settings.displayMode,
            pxgfx.settings.resolutionX, pxgfx.settings.resolutionY,
            surface.handle.format, false, // TODO: See above TODO
            surfacePixelsPtr, surface.handle.pitch,
            programPixelsPtr, pxgfx.settings.pitch
        );
        surface.unlock();
        pxgfx.window.flipSurface();
    }
    // All done
    return CapsuleExtensionCallResult.Ok(0);
}
