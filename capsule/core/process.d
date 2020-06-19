module capsule.core.process;

import core.stdc.stdlib : system;

nothrow @safe public:

bool shouldEscapeProcessArg(in const(char)[] arg) {
    foreach(ch; arg) {
        if(ch != '-' && ch != '_' &&
            !(ch >= '0' && ch <= '9') &&
            !(ch >= 'a' && ch <= 'z') &&
            !(ch >= 'A' && ch <= 'Z')
        ) {
            return true;
        }
    }
    return false;
}

/// Helper to escape a string to be used as a command line argument.
/// e.g. `hello "world"` -> `"hello \"world\""`
string escapeProcessArg(in const(char)[] arg) {
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

const(char)[] getRunProcessString(in const(char)[] name, in const(char)[][] args) {
    const(char)[] command = name;
    foreach(arg; args) {
        if(arg !is null) {
            if(shouldEscapeProcessArg(arg)) {
                command ~= " " ~ escapeProcessArg(arg);
            }
            else {
                command ~= " " ~ arg;
            }
        }
    }
    return command;
}

/// TODO: Use an API with less negative security implications than system
int runProcess(in const(char)[] name, in const(char)[][] args) @trusted {
    const command = getRunProcessString(name, args) ~ '\0';
    const status = system(command.ptr);
    return getSystemExitStatusCode(status);
}
