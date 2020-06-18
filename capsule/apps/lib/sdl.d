module capsule.apps.lib.sdl;

version(CapsuleSDL2Graphics):

import derelict.sdl2.sdl;
import derelict.util.loader : SharedLibVersion;

import capsule.core.bitflags : BitFlags;
import capsule.core.stringz : StringZ;

public:

/// https://wiki.libsdl.org/SDL_Init
static enum CapsuleSDLSystem: uint {
    None = 0,
    Timer = SDL_INIT_TIMER,
    Audio = SDL_INIT_AUDIO,
    Video = SDL_INIT_VIDEO,
    Joystick = SDL_INIT_JOYSTICK,
    Haptic = SDL_INIT_HAPTIC,
    Controller = SDL_INIT_GAMECONTROLLER,
    Events = SDL_INIT_EVENTS,
    All = SDL_INIT_EVERYTHING,
}

alias CapsuleSDLSystems = BitFlags!(uint, CapsuleSDLSystem);

/// https://wiki.libsdl.org/SDL_WindowFlags
static enum CapsuleSDLWindowFlag: SDL_WindowFlags {
    /// Default is Shown
    Default = Shown,
    /// Window is fullscreen
    Fullscreen = SDL_WINDOW_FULLSCREEN,
    /// Window has Desktop Fullscreen
    Desktop = SDL_WINDOW_FULLSCREEN_DESKTOP,
    /// Window is usable with an OpenGL context
    OpenGL = SDL_WINDOW_OPENGL,
    /// Window is usable with a Vulkan instance
    //Vulkan = SDL_WINDOW_VULKAN,
    /// Show the Window immediately
    Shown = SDL_WINDOW_SHOWN,
    /// Hide the Window immediately
    Hidden = SDL_WINDOW_HIDDEN,
    /// The Window has no border
    Borderless = SDL_WINDOW_BORDERLESS,
    /// Window is resizable
    Resizable = SDL_WINDOW_RESIZABLE,
    /// Maximize the Window immediately
    Maximized = SDL_WINDOW_MAXIMIZED,
    /// Minimize the Window immediately
    Minimized = SDL_WINDOW_MINIMIZED,
    /// Grab the input inside the window
    InputGrabbed = SDL_WINDOW_INPUT_GRABBED,
    /// The Window has input (keyboard) focus
    InputFocus = SDL_WINDOW_INPUT_FOCUS,
    /// The Window has mouse focus
    MouseFocus = SDL_WINDOW_MOUSE_FOCUS,
    /// Window not created by SDL
    Foreign = SDL_WINDOW_FOREIGN,
    /// Window should be created in high-DPI mode if supported
    AllowHighDPI = SDL_WINDOW_ALLOW_HIGHDPI,
    /// window has mouse captured (unrelated to InputGrabbed)
    MouseCapture = SDL_WINDOW_MOUSE_CAPTURE,
    /// Window should always be above others (X11 only)
    //AlwaysOnTopX11 = SDL_WINDOW_ALWAYS_ON_TOP,
    /// Don't add the window to the taskbar (X11 only)
    //SkipTaskbarX11 = SDL_WINDOW_SKIP_TASKBAR,
    /// Treat the window as a utility window (X11 only)
    //UtilityX11 = SDL_WINDOW_UTILITY,
    /// Treat the window as a tooltip (X11 only)
    //TooltipX11 = SDL_WINDOW_TOOLTIP,
    /// Treat the window as a popup menu (X11 only)
    //PopupMenuX11 = SDL_WINDOW_POPUP_MENU,
}

alias CapsuleSDLWindowFlags = BitFlags!(uint, CapsuleSDLWindowFlag);

/// Corresponds to SDL_PixelFormatEnum
/// https://wiki.libsdl.org/SDL_PixelFormatEnum
enum CapsuleSDLPixelFormat {
    Unknown = SDL_PIXELFORMAT_UNKNOWN,
    Index1LSB = SDL_PIXELFORMAT_INDEX1LSB,
    Index1MSB = SDL_PIXELFORMAT_INDEX1MSB,
    Index4LSB = SDL_PIXELFORMAT_INDEX4LSB,
    Index4MSB = SDL_PIXELFORMAT_INDEX4MSB,
    Index8 = SDL_PIXELFORMAT_INDEX8,
    RGB332 = SDL_PIXELFORMAT_RGB332,
    RGB444 = SDL_PIXELFORMAT_RGB444,
    RGB555 = SDL_PIXELFORMAT_RGB555,
    BGR555 = SDL_PIXELFORMAT_BGR555,
    ARGB4444 = SDL_PIXELFORMAT_ARGB4444,
    RGBA4444 = SDL_PIXELFORMAT_RGBA4444,
    ABGR4444 = SDL_PIXELFORMAT_ABGR4444,
    BGRA4444 = SDL_PIXELFORMAT_BGRA4444,
    ARGB1555 = SDL_PIXELFORMAT_ARGB1555,
    RGBA5551 = SDL_PIXELFORMAT_RGBA5551,
    ABGR1555 = SDL_PIXELFORMAT_ABGR1555,
    BGRA5551 = SDL_PIXELFORMAT_BGRA5551,
    RGB565 = SDL_PIXELFORMAT_RGB565,
    BGR565 = SDL_PIXELFORMAT_BGR565,
    RGB24 = SDL_PIXELFORMAT_RGB24,
    BGR24 = SDL_PIXELFORMAT_BGR24,
    RGB888 = SDL_PIXELFORMAT_RGB888,
    RGBX8888 = SDL_PIXELFORMAT_RGBX8888,
    BGR888 = SDL_PIXELFORMAT_BGR888,
    BGRX8888 = SDL_PIXELFORMAT_BGRX8888,
    ARGB8888 = SDL_PIXELFORMAT_ARGB8888,
    RGBA8888 = SDL_PIXELFORMAT_RGBA8888,
    ABGR8888 = SDL_PIXELFORMAT_ABGR8888,
    BGRA8888 = SDL_PIXELFORMAT_BGRA8888,
    ARGB2101010 = SDL_PIXELFORMAT_ARGB2101010,
    YV12 = SDL_PIXELFORMAT_YV12,
    IYUV = SDL_PIXELFORMAT_IYUV,
    YUY2 = SDL_PIXELFORMAT_YUY2,
    UYVY = SDL_PIXELFORMAT_UYVY,
    YVYU = SDL_PIXELFORMAT_YVYU,
}

static enum CapsuleSDLVSync: byte {
    Enabled = 1,
    Disabled = 0,
    LateSwapTearing = -1
}

struct CapsuleSDL {
    alias DisplayMode = CapsuleSDLDisplayMode;
    alias PixelFormat = CapsuleSDLPixelFormat;
    alias System = CapsuleSDLSystem;
    alias Systems = CapsuleSDLSystems;
    alias Window = CapsuleSDLWindow;
    
    static bool loaded = false;
    static bool initialized = false;
    
    static void load() {
        assert(!typeof(this).loaded);
        typeof(this).loaded = true;
        DerelictSDL2.load(SharedLibVersion(2, 0, 2));
    }

    static void unload() {
        assert(typeof(this).loaded);
        DerelictSDL2.unload();
    }
    
    static bool initialize(in uint systems) {
        assert(!typeof(this).initialized);
        typeof(this).initialized = true;
        return SDL_Init(systems) == 0;
    }
    
    static void quit() {
        assert(typeof(this).initialized);
        return SDL_Quit();
    }
    
    auto getDesktopDisplayMode(in int displayIndex = 0) {
        SDL_DisplayMode mode;
        if(SDL_GetDesktopDisplayMode(displayIndex, &mode) != 0){
            return DisplayMode.Error;
        }
        else {
            return DisplayMode.Ok(mode);
        }
    }
}

struct CapsuleSDLWindow {
    alias DisplayMode = CapsuleSDLDisplayMode;
    alias FlagsType = SDL_WindowFlags;
    alias Flag = CapsuleSDLWindowFlag;
    alias Flags = CapsuleSDLWindowFlags;
    alias VSync = CapsuleSDLVSync;
    
    SDL_Window* handle;
    SDL_Surface* surface;
    
    this(
        in string title, in int width, in int height, in FlagsType flags
    ) {
        this.handle = SDL_CreateWindow(
            StringZ(title).ptr,
            SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
            width, height, flags
        );
        if(this.handle) {
            this.surface = SDL_GetWindowSurface(this.handle);
        }
    }
    
    bool ok() const {
        return this.handle !is null && this.surface !is null;
    }
    
    void free() {
        if(this.handle !is null){
            SDL_DestroyWindow(this.handle);
            this.handle = null;
        }
    }
    
    uint getPixelFormat() {
        assert(this.handle);
        return SDL_GetWindowPixelFormat(this.handle);
    }
    
    void flipSurface() {
        assert(this.handle);
        SDL_UpdateWindowSurface(this.handle);
    }
    
    void lockSurface() {
        assert(this.surface);
        SDL_LockSurface(this.surface);
    }
    
    void unlockSurface() {
        assert(this.surface);
        SDL_UnlockSurface(this.surface);
    }
    
    bool setDisplayMode(in DisplayMode mode) {
        const sdlMode = cast(SDL_DisplayMode) mode;
        return this.setDisplayMode(&sdlMode);
    }
    
    bool setDisplayMode(in SDL_DisplayMode* mode) {
        const status = SDL_SetWindowDisplayMode(this.handle, mode);
        return status == 0;
    }
}

static struct CapsuleSDLDisplayMode {
    alias PixelFormat = CapsuleSDLPixelFormat;
    
    static typeof(this) Error;
    
    static typeof(this) Ok(in SDL_DisplayMode mode) {
        return typeof(this)(mode);
    }
    
    int width;
    int height;
    int refreshRate;
    PixelFormat format = PixelFormat.Unknown;
    
    this(in SDL_DisplayMode mode){
        this(mode.w, mode.h, mode.refresh_rate, cast(PixelFormat) mode.format);
    }
    
    this(in int width, in int height, in int refreshRate, in PixelFormat format){
        this.width = width;
        this.height = height;
        this.refreshRate = refreshRate;
        this.format = format;
    }
    
    bool ok() const {
        return this.width && this.height && this.format !is PixelFormat.Unknown;
    }
    
    SDL_DisplayMode opCast(T: SDL_DisplayMode)() const{
        return SDL_DisplayMode(
            this.format, this.width, this.height, this.refreshRate
        );
    }
}
