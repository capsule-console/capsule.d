/**

This module implements Capsule's "meta" extensions.

*/

module capsule.extension.meta;

private:

import core.stdc.signal : signal, SIGTERM;

import capsule.core.engine : CapsuleEngine, CapsuleExtensionCallResult;
import capsule.core.extension : CapsuleExtension;

import capsule.extension.common : CapsuleModuleMixin;
import capsule.extension.list : CapsuleExtensionListEntry, CapsuleExtensionList;

version(CapsuleLibrarySDL2) {
    import derelict.sdl2.sdl : SDL_Event, SDL_PollEvent;
    import capsule.sdl.sdl : CapsuleSDL;
}

public:

struct CapsuleMetaModule {
    mixin CapsuleModuleMixin;
    
    alias ecall_meta_noop = .ecall_meta_noop;
    alias ecall_meta_exit_ok = .ecall_meta_exit_ok;
    alias ecall_meta_exit_error = .ecall_meta_exit_error;
    alias ecall_meta_check_ext = .ecall_meta_check_ext;
    alias ecall_meta_defer = .ecall_meta_defer;
    alias ecall_meta_error = .ecall_meta_error;
    //alias ecall_meta_host_uuid = .ecall_meta_host_uuid; // TODO
    //alias ecall_meta_host_name = .ecall_meta_host_name; // TODO
    
    alias Extension = CapsuleExtension;
    
    CapsuleExtensionList* extList;
    
    version(CapsuleLibrarySDL2) {
        static enum RequiredSDLSubSystems = (
            CapsuleSDL.System.Events
        );
        
        alias DispatchSDLEvent = void function(
            void* data, CapsuleEngine* engine, in SDL_Event event
        );
        DispatchSDLEvent dispatchSDLEvent = null;
        void* dispatchSDLEventData = null;
        
        void initializeSDLEventDispatch(
            DispatchSDLEvent dispatch, void* data
        ) nothrow @safe @nogc {
            this.dispatchSDLEvent = dispatch;
            this.dispatchSDLEventData = data;
        }
    }
    
    /// This value is set by the signal handler and is checked upon
    /// a program invoking the meta.defer extension.
    shared static int signalValue = -1;
    
    /// Signal handler function.
    extern(C) static void handleSignal(int signal) nothrow @nogc @safe {
        typeof(this).signalValue = signal;
    }
    
    this(MessageCallback onMessage, CapsuleExtensionList* extList) {
        this.onMessage = onMessage;
        this.extList = extList;
    }
    
    void initializeSignalHandler() nothrow @trusted @nogc const {
        signal(SIGTERM, &typeof(this).handleSignal);
    }
    
    void conclude() {
        // Do nothing
    }
    
    CapsuleExtensionListEntry[] getExtensionList() {
        alias Entry = CapsuleExtensionListEntry;
        return [
            Entry(Extension.meta_noop, &ecall_meta_noop, &this),
            Entry(Extension.meta_exit_ok, &ecall_meta_exit_ok, &this),
            Entry(Extension.meta_exit_error, &ecall_meta_exit_error, &this),
            Entry(Extension.meta_check_ext, &ecall_meta_check_ext, &this),
            Entry(Extension.meta_defer, &ecall_meta_defer, &this),
            Entry(Extension.meta_error, &ecall_meta_error, &this),
        ];
    }
}

/// No operation - do nothing.
CapsuleExtensionCallResult ecall_meta_noop(
    void* data, CapsuleEngine* engine, in uint arg
) {
    return CapsuleExtensionCallResult.Ok(0);
}

/// Terminate program execution with a success/ok status.
CapsuleExtensionCallResult ecall_meta_exit_ok(
    void* data, CapsuleEngine* engine, in uint arg
) {
    assert(engine);
    engine.status = CapsuleEngine.Status.ExitOk;
    return CapsuleExtensionCallResult.Ok(0);
}

/// Terminate program execution with an abnormal/error status.
CapsuleExtensionCallResult ecall_meta_exit_error(
    void* data, CapsuleEngine* engine, in uint arg
) {
    assert(engine);
    engine.status = CapsuleEngine.Status.ExitError;
    return CapsuleExtensionCallResult.Ok(0);
}

/// Check whether the VM supports the extension identified by the
/// ecall argument.
CapsuleExtensionCallResult ecall_meta_check_ext(
    void* data, CapsuleEngine* engine, in uint arg
) {
    assert(data);
    auto meta = cast(CapsuleMetaModule*) data;
    auto checkExt = cast(bool) meta.extList.getExtension(arg);
    return CapsuleExtensionCallResult.Ok(checkExt ? 1 : 0);
}

/// Defer control to the virtual machine environment so that it can
/// do potentially important bookkeeping tasks, such as polling an
/// event queue or checking for an exit signal.
CapsuleExtensionCallResult ecall_meta_defer(
    void* data, CapsuleEngine* engine, in uint arg
) {
    assert(data);
    auto meta = cast(CapsuleMetaModule*) data;
    // Check for signals
    if(CapsuleMetaModule.signalValue == SIGTERM) {
        engine.status = CapsuleEngine.Status.Terminated;
        return CapsuleExtensionCallResult.Ok(0);
    }
    // Poll SDL events
    version(CapsuleLibrarySDL2) {
        if(CapsuleSDL.initialized) {
            assert(CapsuleSDL.loaded);
            SDL_Event event;
            while(SDL_PollEvent(&event)) {
                // Dispatch the event so that it can be handled appropriately
                if(meta.dispatchSDLEvent !is null) {
                    meta.dispatchSDLEvent(
                        meta.dispatchSDLEventData, engine, event
                    );
                }
            }
        }
    }
    return CapsuleExtensionCallResult.Ok(0);
}

/// Unconditionally produce an extension error exception.
CapsuleExtensionCallResult ecall_meta_error(
    void* data, CapsuleEngine* engine, in uint arg
) {
    return CapsuleExtensionCallResult.Error;
}
