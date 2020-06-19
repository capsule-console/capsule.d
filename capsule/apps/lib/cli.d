module capsule.apps.lib.cli;

public:

/// Helper to escape a string to be used as a command line argument.
/// e.g. `hello "world"` -> `"hello \"world\""`
string escapeCliArg(in string arg) {
    string escaped = `"`;
    foreach(ch; arg) {
        if(ch == '\"') {
            escaped ~= `\"`;
        }
        else if(ch == '\\') {
            escaped ~= `\\`;
        }
        else {
            escaped ~= ch;
        }
    }
    escaped ~= `"`;
    return escaped;
}

ubyte getSystemExitStatusCode(in int code) {
    version(Windows) {
        return cast(ubyte) code;
    }
    else {
        return cast(ubyte) (code >> 8);
    }
}
