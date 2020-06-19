module capsule.core.process;

import core.stdc.stdlib : system;

nothrow @safe public:

/// Helper to escape a string to be used as a command line argument.
/// e.g. `hello "world"` -> `"hello \"world\""`
string escapeProcessArg(in string arg) {
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

int getSystemExitStatusCode(in int code) pure @nogc {
    version(Windows) {
        return code;
    }
    else {
        return (code >> 8) & 0xff;
    }
}

string getRunProcessString(in string name, in string[] args) {
    string command = name;
    foreach(arg; args) {
        if(arg !is null) {
            command ~= " " ~ escapeProcessArg(arg);
        }
    }
    return command;
}

/// TODO: Use an API with less negative security implications than system
int runProcess(in string name, in string[] args) @trusted {
    const string command = getRunProcessString(name, args) ~ '\0';
    const status = system(command.ptr);
    return getSystemExitStatusCode(status);
}
