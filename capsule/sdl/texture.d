/**

This module defines a type wrapping an SDL_Texture handle with
helpful methods and enumerations.

*/

module capsule.sdl.texture;

private:

import derelict.sdl2.sdl;

import capsule.sdl.types : CapsuleSDLBlendMode, CapsuleSDLPixelFormat;

public:

/// https://wiki.libsdl.org/SDL_CreateTexture
enum CapsuleSDLTextureAccess: SDL_TextureAccess {
    /// Changes rarely, not lockable
    Static = SDL_TEXTUREACCESS_STATIC,
    /// Changes frequently, lockable
    Streaming = SDL_TEXTUREACCESS_STREAMING,
    /// /// Can be used as a render target
    Target = SDL_TEXTUREACCESS_TARGET,
}

struct CapsuleSDLTextureLock {
    nothrow @safe @nogc:
    
    void* pixels = null;
    int pitch = 0;
    
    bool ok() pure const {
        return this.pixels !is null;
    }
}

struct CapsuleSDLTextureQuery {
    nothrow @safe @nogc:
    
    alias Access = CapsuleSDLTextureAccess;
    alias PixelFormat = CapsuleSDLPixelFormat;
    
    PixelFormat format;
    Access access;
    int width;
    int height;
    
    bool ok() pure const {
        return this.width > 0 && this.height > 0;
    }
}

struct CapsuleSDLTexture {
    nothrow @trusted @nogc:
    
    alias BlendMode = CapsuleSDLBlendMode;
    alias Lock = CapsuleSDLTextureLock;
    alias PixelFormat = CapsuleSDLPixelFormat;
    alias Query = CapsuleSDLTextureQuery;
    alias Access = CapsuleSDLTextureAccess;
    
    SDL_Texture* handle;
    
    static typeof(this) Create(
        SDL_Renderer* renderer,
        in PixelFormat format, in Access access,
        in int width, in int height,
    ) {
        assert(renderer);
        SDL_Texture* texture = SDL_CreateTexture(
            renderer, cast(uint) format, access,
            cast(int) width, cast(int) height
        );
        return typeof(this)(texture);
    }
    
    static typeof(this) CreateFromSurface(
        SDL_Renderer* renderer, SDL_Surface* surface
    ) {
        assert(renderer);
        assert(surface);
        SDL_Texture* texture = SDL_CreateTextureFromSurface(renderer, surface);
        return typeof(this)(texture);
    }
    
    SDL_Texture* opCast(T: SDL_Texture*)() {
        return this.handle;
    }
    
    bool ok() pure const {
        return this.handle !is null;
    }
    
    void free() {
        if(this.handle !is null){
            SDL_DestroyTexture(this.handle);
            this.handle = null;
        }
    }
    
    bool setBlendMode(in BlendMode blendMode) {
        assert(this.handle);
        const status = SDL_SetTextureBlendMode(
            this.handle, cast(SDL_BlendMode) blendMode
        );
        return status == 0;
    }
    
    Lock lock() {
        assert(this.handle);
        Lock lock;
        SDL_LockTexture(this.handle, null, &lock.pixels, &lock.pitch);
        return lock;
    }
    
    void unlock() {
        assert(this.handle);
        SDL_UnlockTexture(this.handle);
    }
    
    /// Get information about the texture, including its width,
    /// height, pixel format, and access setting.
    /// https://wiki.libsdl.org/SDL_QueryTexture
    Query query() {
        assert(this.handle);
        Query query;
        SDL_QueryTexture(
            this.handle,
            cast(uint*) &query.format,
            cast(int*) &query.access,
            &query.width, &query.height
        );
        return query;
    }
    
    PixelFormat getPixelFormat() {
        uint format;
        SDL_QueryTexture(this.handle, &format, null, null, null);
        return cast(PixelFormat) format;
    }
}
