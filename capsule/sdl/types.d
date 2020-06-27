module capsule.sdl.types;

import derelict.sdl2.sdl;

import capsule.bits.bitflags : BitFlags;

public:

struct CapsuleSDLSize {
    int width;
    int height;
}

/// Enumeration of SDL2 pixel formats.
/// Corresponds to SDL_PixelFormatEnum.
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

/// Enumeration of possible vsync options.
static enum CapsuleSDLVSync: byte {
    Enabled = 1,
    Disabled = 0,
    LateSwapTearing = -1
}

/// Enumeration of recognized blend modes.
/// https://wiki.libsdl.org/SDL_BlendMode
enum CapsuleSDLBlendMode: SDL_BlendMode {
    /// No blending
    /// dstRGBA = srcRGBA
    None = SDL_BLENDMODE_NONE,
    /// Alpha blending
    /// dstRGB = (srcRGB * srcA) + (dstRGB * (1-srcA))
    /// dstA = srcA + (dstA * (1-srcA))
    Blend = SDL_BLENDMODE_BLEND,
    /// Additive blending
    /// dstRGB = (srcRGB * srcA) + dstRGB
    /// dstA = dstA
    Add = SDL_BLENDMODE_ADD,
    /// Color modulate
    /// dstRGB = srcRGB * dstRGB
    /// dstA = dstA
    Modulate = SDL_BLENDMODE_MOD,
}
