module capsule.sdl.events;

private:

import derelict.sdl2.sdl;

public:

/// Enumeration of SDL event types.
/// https://wiki.libsdl.org/SDL_Event
enum CapsuleSDLEventType: SDL_EventType {
    FirstEvent = SDL_FIRSTEVENT, First = FirstEvent,
    // Normal stuff
    WindowEvent = SDL_WINDOWEVENT, Window = WindowEvent,
    KeyUp = SDL_KEYUP,
    KeyDown = SDL_KEYDOWN,
    TextEditing = SDL_TEXTEDITING,
    TextInput = SDL_TEXTINPUT,
    MouseMotion = SDL_MOUSEMOTION,
    MouseButtonUp = SDL_MOUSEBUTTONUP,
    MouseButtonDown = SDL_MOUSEBUTTONDOWN,
    MouseWheel = SDL_MOUSEWHEEL,
    JoyAxisMotion = SDL_JOYAXISMOTION,
    JoyBallMotion = SDL_JOYBALLMOTION,
    JoyHatMotion = SDL_JOYHATMOTION,
    JoyButtonUp = SDL_JOYBUTTONUP,
    JoyButtonDown = SDL_JOYBUTTONDOWN,
    JoyDeviceAdded = SDL_JOYDEVICEADDED,
    JoyDeviceRemoved = SDL_JOYDEVICEREMOVED,
    ControllerAxisMotion = SDL_CONTROLLERAXISMOTION,
    ControllerButtonUp = SDL_CONTROLLERBUTTONUP,
    ControllerButtonDown = SDL_CONTROLLERBUTTONDOWN,
    ControllerDeviceAdded = SDL_CONTROLLERDEVICEADDED,
    ControllerDeviceRemoved = SDL_CONTROLLERDEVICEREMOVED,
    ControllerDeviceRemapped = SDL_CONTROLLERDEVICEREMAPPED,
    AudioDeviceAdded = SDL_AUDIODEVICEADDED,
    AudioDeviceRemoved = SDL_AUDIODEVICEREMOVED,
    Quit = SDL_QUIT,
    User = SDL_USEREVENT, UserEvent = User,
    SysWindowManager = SDL_SYSWMEVENT, SysWindowManagerEvent = SysWindowManager,
    FingerUp = SDL_FINGERUP,
    FingerDown = SDL_FINGERDOWN,
    FingerMotion = SDL_FINGERMOTION,
    MultiGesture = SDL_MULTIGESTURE,
    DollarGesture = SDL_DOLLARGESTURE,
    DollarRecord = SDL_DOLLARRECORD,
    DropFile = SDL_DROPFILE,
    //
    KeymapChanged = SDL_KEYMAPCHANGED,
    ClipboardUpdate = SDL_CLIPBOARDUPDATE,
    RenderTargetsReset = SDL_RENDER_TARGETS_RESET,
    RenderDeviceReset = SDL_RENDER_DEVICE_RESET,
    // Specific to mobile and embedded devices
    AppTerminating = SDL_APP_TERMINATING,
    AppLowMemory = SDL_APP_LOWMEMORY,
    AppWillEnterBackground = SDL_APP_WILLENTERBACKGROUND,
    AppDidEnterBackground = SDL_APP_DIDENTERBACKGROUND,
    AppWillEnterForeground = SDL_APP_WILLENTERFOREGROUND,
    AppDidEnterForeground = SDL_APP_DIDENTERFOREGROUND,
    //
    LastEvent = SDL_LASTEVENT, Last = LastEvent,
}

/// Enumeration of possible window event IDs.
/// https://wiki.libsdl.org/SDL_WindowEventID
enum CapsuleSDLWindowEventID: ubyte {
    None = SDL_WINDOWEVENT_NONE,
    Shown = SDL_WINDOWEVENT_SHOWN,
    Hidden = SDL_WINDOWEVENT_HIDDEN,
    Exposed = SDL_WINDOWEVENT_EXPOSED,
    Moved = SDL_WINDOWEVENT_MOVED,
    Resized = SDL_WINDOWEVENT_RESIZED,
    SizeChanged = SDL_WINDOWEVENT_SIZE_CHANGED,
    Minimized = SDL_WINDOWEVENT_MINIMIZED,
    Maximized = SDL_WINDOWEVENT_MAXIMIZED,
    Restored = SDL_WINDOWEVENT_RESTORED,
    Enter = SDL_WINDOWEVENT_ENTER,
    Leave = SDL_WINDOWEVENT_LEAVE,
    FocusGained = SDL_WINDOWEVENT_FOCUS_GAINED,
    FocusLost = SDL_WINDOWEVENT_FOCUS_LOST,
    Close = SDL_WINDOWEVENT_CLOSE,
    TakeFocus = SDL_WINDOWEVENT_TAKE_FOCUS,
    HitTest = SDL_WINDOWEVENT_HIT_TEST,
}

struct CapsuleSDLEventQueue {
    alias Event = SDL_Event;
    alias EventType = CapsuleSDLEventType;
    
    static auto asRange() {
        return CapsuleSDLEventQueueRange.init;
    }
    
    static bool empty() {
        return SDL_PollEvent(null) != 1;
    }
    
    static bool hasEvent() {
        return SDL_PollEvent(null) != 0;
    }
    
    /// Wait indefinitely for an event to be added to the queue.
    /// Returns true on success and false on failure.
    /// https://wiki.libsdl.org/SDL_WaitEvent
    static bool waitEvent(){
        return SDL_WaitEvent(null) != 0;
    }
    
    /// Wait for an event to be added to the queue for the given number of
    /// milliseconds.
    /// Returns true if the wait was terminated because an event
    /// was added to the queue, false otherwise.
    /// https://wiki.libsdl.org/SDL_WaitEventTimeout
    static bool waitEvent(int timeoutMilliseconds){
        return SDL_WaitEventTimeout(null, timeoutMilliseconds) != 0;
    }
    
    static SDL_Event waitGetEvent(int timeoutMilliseconds){
        SDL_Event event;
        SDL_WaitEventTimeout(&event, timeoutMilliseconds);
        return event;
    }
    
    /// Remove and return the next event in the queue.
    static SDL_Event nextEvent() {
        SDL_Event event;
        const pollStatus = SDL_PollEvent(&event);
        assert(pollStatus != 1);
        return event;
    }
    
    /// Populate the event queue and update input device state information.
    /// https://wiki.libsdl.org/SDL_PumpEvents
    static void pumpEvent() {
        SDL_PumpEvents();
    }
    
    /// Add an event watch.
    /// https://wiki.libsdl.org/SDL_AddEventWatch
    static void addWatch(SDL_EventFilter watch, void* data) {
        SDL_AddEventWatch(watch, data);
    }
    
    /// Remove an event watch.
    /// https://wiki.libsdl.org/SDL_DelEventWatch
    static void removeWatch(SDL_EventFilter watch, void* data) {
        SDL_DelEventWatch(watch, data);
    }
}

/// Provides a range interface for enumerating events in the
/// SDL event queue.
struct CapsuleSDLEventQueueRange {
    /// https://wiki.libsdl.org/SDL_PollEvent
    bool empty() const {
        return SDL_PollEvent(null) != 1;
    }
    
    /// https://wiki.libsdl.org/SDL_PeepEvents
    auto front() const {
        SDL_Event event;
        const pollStatus = SDL_PeepEvents(
            &event, 1, SDL_PEEKEVENT, SDL_FIRSTEVENT, SDL_LASTEVENT
        );
        assert(pollStatus != 1);
        return event;
    }
    
    /// https://wiki.libsdl.org/SDL_PollEvent
    auto next() const {
        SDL_Event event;
        const pollStatus = SDL_PollEvent(&event);
        assert(pollStatus != 1);
        return event;
    }
    
    /// https://wiki.libsdl.org/SDL_PollEvent
    void popFront() {
        SDL_Event event;
        const pollStatus = SDL_PollEvent(&event);
        assert(pollStatus != 1);
    }
}
