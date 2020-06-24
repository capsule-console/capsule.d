/**

This module provides functions related to initializing and
uninitializing an SDL2 dependency.

*/

module capsule.sdl.sdl;

private:

import core.atomic : atomicOp;

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

shared struct CapsuleSDL {
    alias System = CapsuleSDLSystem;
    alias Systems = CapsuleSDLSystems;
    
    shared static bool loaded = false;
    shared static bool initialized = false;
    shared static uint initializedSubSystems = 0;
    shared static uint requiredSubSystems = 0;
    
    static void load() {
        assert(!typeof(this).loaded);
        typeof(this).loaded = true;
        // Require SDL v2.0.2 at minimum
        // http://derelictorg.github.io/loading/loader/
        // https://stackoverflow.com/a/37903107/3478907
        DerelictSDL2.load(SharedLibVersion(2, 0, 2));
    }

    static void unload() {
        assert(typeof(this).loaded);
        typeof(this).loaded = false;
        DerelictSDL2.unload();
    }
    
    static bool initialize(in uint systems = 0) {
        assert(typeof(this).loaded);
        assert(!typeof(this).initialized);
        const uint initSystems = systems | typeof(this).requiredSubSystems;
        const status = (SDL_Init(initSystems) == 0);
        if(status) {
            typeof(this).initialized = true;
            atomicOp!"|="(typeof(this).initializedSubSystems, initSystems);
        }
        return status;
    }
    
    static bool initializeSubSystems(in uint systems) {
        assert(typeof(this).loaded);
        assert(typeof(this).initialized);
        const status = SDL_InitSubSystem(systems) == 0;
        if(status) {
            atomicOp!"|="(typeof(this).initializedSubSystems, systems);
        }
        return status;
    }
    
    static void quitSubSystems(in uint systems) {
        assert(typeof(this).loaded);
        assert(typeof(this).initialized);
        SDL_QuitSubSystem(systems);
    }
    
    static void quit() {
        assert(typeof(this).loaded);
        assert(typeof(this).initialized);
        typeof(this).initialized = false;
        return SDL_Quit();
    }
    
    static void ensureLoaded() {
        if(!typeof(this).loaded) {
            typeof(this).load();
        }
    }
    
    static bool ensureInitialized() {
        typeof(this).ensureLoaded();
        if(!typeof(this).initialized) {
            return typeof(this).initialize();
        }
        return typeof(this).initialized;
    }
    
    static void addRequiredSubSystems(in uint systems) {
        atomicOp!"|="(typeof(this).requiredSubSystems, systems);
    }
}
