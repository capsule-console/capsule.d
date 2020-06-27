/**

This module defines a type wrapping an SDL_Renderer handle with
helpful methods and enumerations.

*/

module capsule.sdl.renderer;

private:

import derelict.sdl2.sdl;

import capsule.sdl.texture : CapsuleSDLTexture;
import capsule.sdl.types : CapsuleSDLBlendMode;
import capsule.sdl.types : CapsuleSDLPixelFormat, CapsuleSDLSize;

public:

/// https://wiki.libsdl.org/SDL_RendererFlags
enum CapsuleSDLRendererFlag: SDL_RendererFlags {
    /// The renderer is a software fallback
    Software = SDL_RENDERER_SOFTWARE,
    /// The renderer uses hardware acceleration
    Accelerated = SDL_RENDERER_ACCELERATED,
    /// Present is synchronized with the refresh rate
    PresentVSync = SDL_RENDERER_PRESENTVSYNC,
    /// The renderer supports rendering to texture
    TargetTexture = SDL_RENDERER_TARGETTEXTURE,
}

struct CapsuleSDLRenderer {
    nothrow @trusted @nogc:
    
    alias BlendMode = CapsuleSDLBlendMode;
    alias Flag = CapsuleSDLRendererFlag;
    alias PixelFormat = CapsuleSDLPixelFormat;
    alias Size = CapsuleSDLSize;
    alias Texture = CapsuleSDLTexture;
    
    SDL_Renderer* handle;
    
    /// https://wiki.libsdl.org/SDL_CreateRenderer
    static typeof(this) Create(
        SDL_Window* window, in int index, in SDL_RendererFlags flags
    ) {
        assert(window);
        SDL_Renderer* renderer = SDL_CreateRenderer(window, index, flags);
        return typeof(this)(renderer);
    }
    
    /// https://wiki.libsdl.org/SDL_CreateSoftwareRenderer
    static typeof(this) CreateSoftware(SDL_Surface* surface) {
        assert(surface);
        SDL_Renderer* renderer = SDL_CreateSoftwareRenderer(surface);
        return typeof(this)(renderer);
    }
    
    SDL_Renderer* opCast(T: SDL_Renderer*)() pure {
        return this.handle;
    }
    
    bool ok() pure const {
        return this.handle !is null;
    }
    
    void free() {
        if(this.handle !is null){
            SDL_DestroyRenderer(this.handle);
            this.handle = null;
        }
    }
    
    Size getOutputSize() {
        Size size;
        SDL_GetRendererOutputSize(this.handle, &size.width, &size.height);
        return size;
    }
    
    Texture createTexture(
        in Texture.PixelFormat format, in Texture.Access access,
        in int width, in int height
    ) {
        assert(this.handle);
        return Texture.Create(this.handle, format, access, width, height);
    }
    
    void present() {
        assert(this.handle);
        SDL_RenderPresent(this.handle);
    }
    
    bool clear() {
        assert(this.handle);
        return SDL_RenderClear(this.handle) == 0;
    }
    
    bool setColor(
        in ubyte red, in ubyte green, in ubyte blue, in ubyte alpha = 0xff
    ) {
        assert(this.handle);
        const status = SDL_SetRenderDrawColor(
            this.handle, red, green, blue, alpha
        );
        return status == 0;
    }
    
    bool setBlendMode(in BlendMode blendMode) {
        assert(this.handle);
        const status = SDL_SetRenderDrawBlendMode(
            this.handle, cast(SDL_BlendMode) blendMode
        );
        return status == 0;
    }
    
    bool setViewport(in SDL_Rect* viewport) {
        assert(this.handle);
        assert(viewport);
        return SDL_RenderSetViewport(this.handle, viewport) == 0;
    }
    
    bool copyTexture(
        SDL_Texture* texture, in SDL_Rect* srcRect, in SDL_Rect* dstRect
    ) {
        assert(this.handle);
        assert(texture);
        const status = SDL_RenderCopy(
            this.handle, texture, srcRect, dstRect
        );
        return status == 0;
    }
}
