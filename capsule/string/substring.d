/**

This module implements functions for dealing with substrings.

*/

module capsule.string.substring;

public:

/// Check whether a string starts with a substring.
bool startsWith(T)(in T[] text, in T[] sub) nothrow @safe @nogc {
    if(text.length < sub.length) {
        return false;
    }
    return text[0 .. sub.length] == sub;
}

/// Check whether a string ends with a substring.
bool endsWith(T)(in T[] text, in T[] sub) nothrow @safe @nogc {
    if(text.length < sub.length) {
        return false;
    }
    return text[$ - sub.length .. $] == sub;
}

/// Check whether a string contains a substring.
bool containsSubstring(T)(in T[] text, in T[] sub) nothrow @safe @nogc {
    if(text.length < sub.length) {
        return false;
    }
    else if(text.length == 0) {
        return true;
    }
    const imax = text.length - sub.length;
    for(size_t i = 0; i <= imax; i++) {
        if(text[i .. i + sub.length] == sub) {
            return true;
        }
    }
    return false;
}

/// Get the first index of a substring within a given string.
ptrdiff_t indexOfSubstring(T)(in T[] text, in T[] sub) nothrow @safe @nogc {
    if(text.length < sub.length) {
        return -1;
    }
    else if(sub.length == 0) {
        return 0;
    }
    const imax = text.length - sub.length;
    assert(imax <= ptrdiff_t.max);
    for(size_t i = 0; i <= imax; i++) {
        if(text[i .. i + sub.length] == sub) {
            return cast(ptrdiff_t) i;
        }
    }
    return -1;
}

/// Get the last index of a substring within a given string.
ptrdiff_t lastIndexOfSubstring(T)(in T[] text, in T[] sub) nothrow @safe @nogc {
    if(text.length < sub.length) {
        return -1;
    }
    else if(sub.length == 0) {
        return text.length;
    }
    const imax = text.length - sub.length;
    assert(imax <= ptrdiff_t.max);
    for(size_t i = imax + 1; i > 0; i--) {
        if(text[i - 1 .. i + sub.length - 1] == sub) {
            return cast(ptrdiff_t) i - 1;
        }
    }
    return -1;
}

/// Tests for startsWith
unittest {
    // Empty string
    assert("".startsWith(""));
    assert(!"".startsWith("Ok"));
    // Non-empty string
    assert("Hello, world".startsWith(""));
    assert("Hello, world".startsWith("H"));
    assert("Hello, world".startsWith("Hello"));
    assert("Hello, world".startsWith("Hello, world"));
    assert(!"Hello, world".startsWith("!"));
    assert(!"Hello, world".startsWith("d"));
    assert(!"Hello, world".startsWith("Hi"));
    assert(!"Hello, world".startsWith("Hello, world!"));
}

/// Tests for endsWith
unittest {
    // Empty string
    assert("".endsWith(""));
    assert(!"".endsWith("Ok"));
    // Non-empty string
    assert("Hello, world".endsWith(""));
    assert("Hello, world".endsWith("d"));
    assert("Hello, world".endsWith("world"));
    assert("Hello, world".endsWith("Hello, world"));
    assert(!"Hello, world".endsWith("!"));
    assert(!"Hello, world".endsWith("H"));
    assert(!"Hello, world".endsWith("worlds"));
    assert(!"Hello, world".endsWith("Hello, world!"));
}

/// Tests for containsSubstring
unittest {
    // Empty string
    assert("".containsSubstring(""));
    assert(!"".containsSubstring("Ok"));
    // Non-empty string
    assert("Hello, world".containsSubstring(""));
    assert("Hello, world".containsSubstring("H"));
    assert("Hello, world".containsSubstring("l"));
    assert("Hello, world".containsSubstring("d"));
    assert("Hello, world".containsSubstring(", "));
    assert("Hello, world".containsSubstring("Hello"));
    assert("Hello, world".containsSubstring("world"));
    assert("Hello, world".containsSubstring("Hello, world"));
    assert(!"Hello, world".containsSubstring("!"));
    assert(!"Hello, world".containsSubstring("W"));
    assert(!"Hello, world".containsSubstring("worlds"));
    assert(!"Hello, world".containsSubstring("Hello, world!"));
}

/// Tests for indexOfSubstring
unittest {
    // Empty string
    assert("".indexOfSubstring("") == 0);
    assert("".indexOfSubstring("Ok") == -1);
    // Non-empty string
    assert("Hello, world".indexOfSubstring("") == 0);
    assert("Hello, world".indexOfSubstring("H") == 0);
    assert("Hello, world".indexOfSubstring("l") == 2);
    assert("Hello, world".indexOfSubstring("d") == 11);
    assert("Hello, world".indexOfSubstring(", ") == 5);
    assert("Hello, world".indexOfSubstring("Hello") == 0);
    assert("Hello, world".indexOfSubstring("world") == 7);
    assert("Hello, world".indexOfSubstring("Hello, world") == 0);
    assert("Hello, world".indexOfSubstring("!") == -1);
    assert("Hello, world".indexOfSubstring("W") == -1);
    assert("Hello, world".indexOfSubstring("worlds") == -1);
    assert("Hello, world".indexOfSubstring("Hello, world!") == -1);
}

/// Tests for lastIndexOfSubstring
unittest {
    // Empty string
    assert("".lastIndexOfSubstring("") == 0);
    assert("".lastIndexOfSubstring("Ok") == -1);
    // Non-empty string
    assert("Hello, world".lastIndexOfSubstring("") == 12);
    assert("Hello, world".lastIndexOfSubstring("H") == 0);
    assert("Hello, world".lastIndexOfSubstring("l") == 10);
    assert("Hello, world".lastIndexOfSubstring("d") == 11);
    assert("Hello, world".lastIndexOfSubstring(", ") == 5);
    assert("Hello, world".lastIndexOfSubstring("Hello") == 0);
    assert("Hello, world".lastIndexOfSubstring("world") == 7);
    assert("Hello, world".lastIndexOfSubstring("Hello, world") == 0);
    assert("Hello, world".lastIndexOfSubstring("!") == -1);
    assert("Hello, world".lastIndexOfSubstring("W") == -1);
    assert("Hello, world".lastIndexOfSubstring("worlds") == -1);
    assert("Hello, world".lastIndexOfSubstring("Hello, world!") == -1);
}
