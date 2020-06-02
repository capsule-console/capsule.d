module capsule.core.timer;

import capsule.core.monotonic : monotonicns;

public nothrow @safe @nogc:

enum TimerState: uint {
    None = 0,
    Active,
    Ended,
    Suspended,
}

struct Timer {
    nothrow @safe @nogc:
    
    alias State = TimerState;
    
    State state;
    long startTime;
    long endTime;
    long suspendTime;
    
    void restart() {
        this.state = State.Active;
        this.startTime = monotonicns();
        this.endTime = this.startTime;
    }
    
    void start() {
        if(this.state is State.Suspended) {
            this.resume();
        }
        else {
            this.restart();
        }
    }
    
    void end() {
        if(this.state is State.Suspended) this.resume();
        assert(this.state is State.Active);
        this.state = State.Ended;
        this.endTime = monotonicns();
    }
    
    void suspend() {
        assert(this.state is State.Active);
        this.suspendTime = monotonicns();
        this.state = State.Suspended;
    }
    
    void resume() {
        assert(this.state is State.Suspended);
        const resumeTime = monotonicns();
        this.startTime += (resumeTime - this.suspendTime);
        this.state = State.Active;
    }
    
    long nanoseconds() const {
        if(this.state is State.Suspended) {
            return this.suspendTime - this.startTime;
        }
        else {
            return this.endTime - this.startTime; 
        }
    }
    
    long seconds() const {
        return this.nanoseconds / 1_000_000_000L;
    }
    
    long milliseconds() const {
        return this.nanoseconds / 1_000_000L;
    }
}
