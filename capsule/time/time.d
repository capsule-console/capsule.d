module capsule.time.time;

private import core.stdc.time : time;

public nothrow @safe @nogc:

long getUnixSeconds() {
    return cast(long) time(null);
}
