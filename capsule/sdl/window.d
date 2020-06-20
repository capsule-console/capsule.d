module capsule.sdl.window;

import derelict.sdl2.sdl;

import capsule.sdl.displaymode : CapsuleSDLDisplayMode;
import capsule.sdl.types : CapsuleSDLPixelFormat;

import capsule.bits.bitflags : BitFlags;
import capsule.string.stringz : stringz;

public:

alias CapsuleSDLWindowFlags = BitFlags!(uint, CapsuleSDLWindowFlag);

/// Enumeration of SDL2 window state/style flags.
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

struct CapsuleSDLWindow {
    alias DisplayMode = CapsuleSDLDisplayMode;
    alias FlagsType = SDL_WindowFlags;
    alias Flag = CapsuleSDLWindowFlag;
    alias Flags = CapsuleSDLWindowFlags;
    alias PixelFormat = CapsuleSDLPixelFormat;
    //alias VSync = CapsuleSDLVSync; // TODO: Support this maybe?
    
    SDL_Window* handle;
    SDL_Surface* surface;
    
    this(
        in string title, in int width, in int height, in FlagsType flags
    ) {
        this.handle = SDL_CreateWindow(
            stringz(title).ptr,
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
    
    PixelFormat getPixelFormat() {
        assert(this.handle);
        return cast(PixelFormat) SDL_GetWindowPixelFormat(this.handle);
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
