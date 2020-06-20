module capsule.sdl.sdl;

import derelict.sdl2.sdl : DerelictSDL2;
import derelict.util.loader : SharedLibVersion;

import derelict.sdl2.sdl;

import capsule.bits.bitflags : BitFlags;

public:

alias CapsuleSDLSystems = BitFlags!(uint, CapsuleSDLSystem);

/// Possible SDL2 systems that can be initialized.
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

struct CapsuleSDL {
    alias System = CapsuleSDLSystem;
    alias Systems = CapsuleSDLSystems;
    
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
}
