/*

This module contains extern declarations for MacOS mach kernel time-related
functionality that may be missing from the druntime's core.sys libraries.

Some important time-related functions in the POSIX specification were
not added to MacOS until 10.12 (Sierra), so for compatibility with MacOS
versions older than 10.12 it is necessary to use mach functions instead
of POSIX functions in some cases.

https://en.wikipedia.org/wiki/Mach_(kernel)

https://stackoverflow.com/questions/5167269/clock-gettime-alternative-in-mac-os-x

*/

module capsule.time.mach;

version(OSX):

public import core.sys.darwin.mach.kern_return : kern_return_t;

public extern(C) nothrow @nogc:

/// https://developer.apple.com/documentation/kernel/mach_timebase_info_data_t
struct mach_timebase_info_data_t {
    uint numer;
    uint denom;
}

/// https://developer.apple.com/documentation/kernel/mach_timebase_info_t
alias mach_timebase_info_data_t* mach_timebase_info_t;

/// https://developer.apple.com/documentation/driverkit/3433733-mach_timebase_info
kern_return_t mach_timebase_info(mach_timebase_info_t);

/// https://developer.apple.com/documentation/driverkit/3438076-mach_absolute_time
ulong mach_absolute_time();
