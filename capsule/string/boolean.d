/**

This module provides functions for converting booleans to and from strings.

*/

module capsule.string.boolean;

public:

/// Returns "true" for a true value and "false" for a false value.
string writeBooleanValue(in bool value) pure nothrow @safe @nogc {
    return value ? "true" : "false";
}

/// Returns 0 for a false boolean.
/// Returns 1 for a true boolean.
/// Returns -1 for a string that represents neither.
int parseBooleanValue(in string text) pure nothrow @safe @nogc {
    if(text == "0" || text == "f" || text == "false") {
        return false;
    }
    else if(text == "1" || text == "t" || text == "true") {
        return true;
    }
    else {
        return -1;
    }
}

/// Test coverage for writeBooleanValue
unittest {
    assert(writeBooleanValue(true) == "true");
    assert(writeBooleanValue(false) == "false");
}

/// Test coverage for parseBooleanValue
unittest {
    assert(parseBooleanValue("true") == 1);
    assert(parseBooleanValue("t") == 1);
    assert(parseBooleanValue("1") == 1);
    assert(parseBooleanValue("false") == 0);
    assert(parseBooleanValue("f") == 0);
    assert(parseBooleanValue("0") == 0);
    assert(parseBooleanValue("null") == -1);
    assert(parseBooleanValue("?") == -1);
}
