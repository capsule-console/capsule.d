/**

This module implements functions that deal with monotonic time.

https://www.sourcetoad.com/app-development/use-monotonic-time/

*/

module capsule.time.monotonic;

private:

version(OSX) {
    import core.sys.darwin.mach.kern_return : kern_return_t, KERN_SUCCESS;
    import capsule.time.mach : mach_absolute_time;
    import capsule.time.mach : mach_timebase_info, mach_timebase_info_data_t;
}
else version(Posix) {
    import core.sys.posix.time : timespec, clock_gettime, CLOCK_MONOTONIC;
}
else version(Windows) {
    import core.sys.windows.winbase : QueryPerformanceCounter;
    import core.sys.windows.winbase : QueryPerformanceFrequency;
}

/// Helper to convert a number of ticks to a number of nanoseconds.
/// Used by the Windows implementation of `monotonicns`.
private long tickstons(
    in long ticks, in long ticksPerSecond
) pure nothrow @safe @nogc {
    assert(ticksPerSecond > 0);
    enum NanosecondsPerSecond = 1_000_000_000L;
    const nsPerTick = NanosecondsPerSecond / ticksPerSecond;
    assert(nsPerTick > 0);
    return ticks * nsPerTick;
}

public nothrow @trusted @nogc:

/// Get monotonic time as a number of nanoseconds on OSX.
/// The OSX monotonic clock should be accurate to the nanosecond.
/// The clock counts up from the last reboot time. The clock
/// does not count up while the system is asleep or hibernating.
/// https://developer.apple.com/library/archive/qa/qa1398/_index.html
/// https://stackoverflow.com/questions/1450737/what-is-mach-absolute-time-based-on-on-iphone/4753909#4753909
version(OSX) long monotonicns() {
    const ulong absolute = mach_absolute_time();
    mach_timebase_info_data_t info;
    const kernStatus = mach_timebase_info(&info);
    if(kernStatus != KERN_SUCCESS) assert(false, "Failed to get timebase info.");
    return cast(long) ((absolute * info.numer) / info.denom);
}

/// Get monotonic time as a number of nanoseconds on Posix platforms
/// other than OSX. This encompasses a number of different operating systems,
/// and clock basis and precision can be expected to vary between them.
/// Check the documentation for clock_gettime(CLOCK_MONOTONIC_PRECISE, &t)
/// where available - clock_gettime(CLOCK_MONOTONIC, &t) where not - for a
/// particular platform; the behavior of monotonicns will be the same.
else version(Posix) long monotonicns() {
    timespec time;
    const status = clock_gettime(CLOCK_MONOTONIC, &time);
    if(status) assert(false, "Failed to get clock time.");
    return cast(long) time.tv_sec * 1_000_000_000L + cast(long) time.tv_nsec;
}

/// Get monotonic time as a number of nanoseconds on Windows.
else version(Windows) long monotonicns() {
    // https://msdn.microsoft.com/en-us/library/ms644904(v=VS.85).aspx
    // https://msdn.microsoft.com/en-us/library/ms644905(v=VS.85).aspx
    static long ticksPerSecond = 0;
    // Initialize ticksPerSecond if it hasn't been initialized already
    if(ticksPerSecond == 0){
        const freqstatus = QueryPerformanceFrequency(&ticksPerSecond);
        if(freqstatus == 0 || ticksPerSecond <= 0){
            assert(false, "Monotonic clock not available for this platform.");
        }
    }
    // Get the number of ticks
    long ticks;
    const status = QueryPerformanceCounter(&ticks);
    // Note that if this check would fail, then the one just above should
    // have failed already.
    assert(status != 0, "Monotonic clock not available for this platform.");
    // Convert the number of ticks to a number of nanoseconds
    return tickstons(ticks, ticksPerSecond);
}

/// Test coverage for monotonicns
unittest {
    long[256] ns;
    for(uint i = 0; i < ns.length; i++) {
        ns[i] = monotonicns();
    }
    for(uint i = 1; i < ns.length; i++) {
        assert(ns[i - 1] <= ns[i]);
    }
}
