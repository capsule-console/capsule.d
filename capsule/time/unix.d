/**

This module provides functions relating to Unix time, i.e. the amount
of time elapsed since Unix epoch (1970-01-01T00:00:00Z).

https://en.wikipedia.org/wiki/Unix_time

*/

module capsule.time.unix;

private import core.stdc.time : time;

public nothrow @safe @nogc:

/// Get the number of seconds elapsed since Unix epoch.
/// https://en.wikipedia.org/wiki/Unix_time
long getUnixSeconds() {
    return cast(long) time(null);
}
