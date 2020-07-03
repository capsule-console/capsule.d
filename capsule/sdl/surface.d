/**

This module defines a type wrapping an SDL_Surface handle with
helpful methods and enumerations.

*/

module capsule.sdl.surface;

private:

import derelict.sdl2.sdl;

import capsule.sdl.types : CapsuleSDLPixelFormat;

public:

struct CapsuleSDLSurface {
    nothrow @trusted @nogc:
    
    alias PixelFormat = CapsuleSDLPixelFormat;
    
    SDL_Surface* handle;
    
    static typeof(this) Create(
        in int width, in int height, in int bitDepth,
        in uint Rmask, in uint Gmask, in uint Bmask, in uint Amask
    ) {
        SDL_Surface* handle = SDL_CreateRGBSurface(
            0, width, height, bitDepth, Rmask, Gmask, Bmask, Amask
        );
        return typeof(this)(handle);
    }
    
    /// SDL 2.0.5 and later
    static typeof(this) CreateWithFormat(
        in int width, in int height,
        in int bitDepth, in PixelFormat format
    ) {
        SDL_Surface* handle = SDL_CreateRGBSurfaceWithFormat(
            0, width, height, bitDepth, cast(uint) format
        );
        return typeof(this)(handle);
    }
    
    SDL_Surface* opCast(T: SDL_Surface*)() {
        return this.handle;
    }
    
    bool ok() pure const {
        return this.handle !is null;
    }
    
    void free() {
        if(this.handle !is null){
            SDL_FreeSurface(this.handle);
            this.handle = null;
        }
    }
    
    bool fillColor(in ubyte red, in ubyte green, in ubyte blue, in ubyte alpha) {
        assert(this.handle);
        const color = SDL_MapRGBA(this.handle.format, red, green, blue, alpha);
        return SDL_FillRect(this.handle, null, color) == 0;
    }
    
    bool fillRect(in SDL_Rect* rect, in uint color) {
        assert(this.handle);
        return SDL_FillRect(this.handle, rect, color) == 0;
    }
    
    uint mapColor(in ubyte red, in ubyte green, in ubyte blue, in ubyte alpha) {
        assert(this.handle);
        return SDL_MapRGBA(this.handle.format, red, green, blue, alpha);
    }
    
    bool lock() {
        assert(this.handle);
        return SDL_LockSurface(this.handle) == 0;
    }
    
    void unlock() {
        assert(this.handle);
        SDL_UnlockSurface(this.handle);
    }
}
