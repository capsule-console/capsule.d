/**

This module provides a sleep function for suspending program
execution for an approximate number of milliseconds.

*/

module capsule.time.sleep;

private:

version(Windows) {
    pragma(lib, "winmm");
    import core.sys.windows.winbase : Sleep;
    import core.sys.windows.mmsystem : timeBeginPeriod, timeEndPeriod;
}

version(Posix) {
    import core.stdc.errno : errno, EINTR;
    import core.sys.posix.time: nanosleep, timespec, time_t;
}

/// Get the clock resolution on MacOS. Doesn't use clock_getres
/// because this isn't available prior to MacOS 10.12.
/// Some credit is due to PosixMachTiming:
/// https://github.com/ChisholmKyle/PosixMachTiming
version(OSX) private void monotonic_clock_getres(timespec* res) {
    import core.sys.darwin.mach.kern_return : KERN_SUCCESS;
    import capsule.time.mach : mach_timebase_info, mach_timebase_info_data_t;
    mach_timebase_info_data_t info;
    const kernStatus = mach_timebase_info(&info);
    if(kernStatus != KERN_SUCCESS) {
        assert(false, "Failed to get timebase info.");
    }
    if(res !is null) {
        res.tv_sec = 0;
        res.tv_nsec = info.numer / info.denom;
    }
}

else version(Posix) private void monotonic_clock_getres(timespec* res) {
    import core.sys.posix.time: clock_getres, CLOCK_MONOTONIC;
    const resStatus = clock_getres(CLOCK_MONOTONIC, &res);
    if(resStatus != 0) {
        assert(false, "Failed to get monotonic clock resolution.");
    }
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

version(Windows) int sleepPreciseMilliseconds(in int milliseconds) {
    if(milliseconds > 0) {
        timeBeginPeriod(1);
        Sleep(milliseconds);
        timeEndPeriod(1);
    }
    return 0;
}

version(Posix) int sleepPreciseMilliseconds(in int milliseconds) {
    // It is necessary to get the monotonic clock's resolution so that
    // nanosleep (which rounds up to the nearest resolution interval)
    // does not over-sleep if it is repeatedly interrupted.
    timespec resolution = void;
    monotonic_clock_getres(&resolution);
    // Sleep while the remaining time is greater than the monotonic
    // clock's resolution.
    timespec sleep = {
        tv_sec: cast(time_t) (milliseconds / 1_000),
        tv_nsec: cast(long) ((milliseconds % 1_000) * 1_000_000L),
    };
    while(sleep.tv_sec > 0 || sleep.tv_nsec > resolution.tv_nsec) {
        timespec remaining = void;
        const status = nanosleep(&sleep, &remaining);
        if(status != 0 && errno != EINTR) {
            return -1;
        }
        sleep = remaining;
    }
    // Return any remaining time as an integer number of milliseconds.
    // Realistically, this should probably always be zero.
    return (
        cast(int) (sleep.tv_sec * 1_000) +
        cast(int) (sleep.tv_nsec / 1_000_000L)
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

/// Test coverage for sleepPreciseMilliseconds
unittest {
    const startMilliseconds = monotonicns() / 1_000_000;
    sleepPreciseMilliseconds(100);
    const endMilliseconds = monotonicns() / 1_000_000;
    const deltaMilliseconds = (endMilliseconds - startMilliseconds);
    assert(deltaMilliseconds >= 90 && deltaMilliseconds <= 120);
}
