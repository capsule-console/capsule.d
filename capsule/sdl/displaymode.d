module capsule.sdl.displaymode;

import derelict.sdl2.sdl;

import capsule.sdl.types : CapsuleSDLPixelFormat;

public:

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
    
    static typeof(this) getDesktopDisplayMode(in int displayIndex = 0) {
        SDL_DisplayMode mode;
        if(SDL_GetDesktopDisplayMode(displayIndex, &mode) != 0){
            return typeof(this).Error;
        }
        else {
            return typeof(this).Ok(mode);
        }
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
