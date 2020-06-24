/**

This module provides a sleep function for suspending program
execution for an approximate number of milliseconds.

*/

module capsule.time.sleep;

private:

version(Windows) {
    import core.sys.windows.winbase : Sleep;
}

version(Posix) {
    import core.stdc.errno : errno, EINTR;
    import core.sys.posix.time: nanosleep, timespec, time_t;
}

public:

/// Suspend the calling thread for an approximate number
/// of milliseconds.
/// Always returns zero.
version(Windows) int sleepMilliseconds(in int milliseconds) {
    if(milliseconds > 0) {
        Sleep(milliseconds);
    }
    return 0;
}

/// Suspend the calling thread for an approximate number
/// of milliseconds.
/// Returns 0 if the sleep was successful and uninterrupted.
/// Returns a remaining number of milliseconds if the sleep
/// was interrupted partway through.
/// Returns a negative value if the sleep failed outright.
version(Posix) int sleepMilliseconds(in int milliseconds) {
    if(milliseconds <= 0) {
        return 0;
    }
    timespec time = {
        tv_sec: cast(time_t) (milliseconds / 1_000),
        tv_nsec: cast(long) ((milliseconds % 1_000) * 1_000_000L),
    };
    timespec remaining = void;
    const status = nanosleep(&time, &remaining);
    if(status == 0) {
        return 0;
    }
    else if(errno != EINTR) {
        return -1;
    }
    return (
        cast(int) (remaining.tv_sec * 1_000) +
        cast(int) (remaining.tv_nsec / 1_000_000L)
    );
}

private version(unittest) {
    import capsule.time.monotonic : monotonicns;
}

/// Test coverage for sleepMilliseconds
unittest {
    const startMilliseconds = monotonicns() / 1_000_000;
    sleepMilliseconds(100);
    const endMilliseconds = monotonicns() / 1_000_000;
    const deltaMilliseconds = (endMilliseconds - startMilliseconds);
    assert(deltaMilliseconds >= 75 && deltaMilliseconds <= 150);
}
