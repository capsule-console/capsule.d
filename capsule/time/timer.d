/**

This module implements a timer that can be used to measure the time
elapsed from one point in program execution to another point.

*/

module capsule.time.timer;

private:

import capsule.time.monotonic : monotonicns;

public:

/// Enumeration of possible states that a Timer can be in.
enum TimerState: uint {
    None = 0,
    Active,
    Ended,
    Suspended,
}

/// Type used to implement a monotonic timer.
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
