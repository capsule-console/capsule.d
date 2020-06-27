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
    
    void fillColor(in ubyte red, in ubyte green, in ubyte blue) {
        assert(this.handle);
        const rgb = SDL_MapRGB(this.handle.format, red, green, blue);
        SDL_FillRect(this.handle, null, rgb);
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
