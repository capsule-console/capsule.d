/**

This module provides functions for writing to stdout and stderr and
for reading from stdin, the standard input and output streams.

https://en.wikipedia.org/wiki/Standard_streams

*/

module capsule.io.stdio;

private:

import core.stdc.stdio : stdin, stdout, stderr;
import core.stdc.stdio : fwrite, fflush, putchar, getchar;

import capsule.range.range : isRange;

public:

struct stdio {
    nothrow @nogc:
    
    static void write(in char text) @trusted {
        putchar(text);
    }
    
    static void write(in char[] text) @trusted {
        fwrite(text.ptr, char.sizeof, text.length, stdout); 
    }
    
    static void write(T)(auto ref T text) if(isRange!T) {
        foreach(ch; text) {
            putchar(ch);
        }
    }
    
    static void write(T, X...)(auto ref T first, auto ref X rest) {
        stdio.write(first);
        foreach(text; rest) {
            stdio.write(text);
        }
    }

    static void writeln(T...)(auto ref T text) {
        stdio.write(text);
        stdio.write('\n');
    }
    
    static void flush() {
        fflush(stdout);
    }

    static int readChar() {
        return getchar();
    }
    
    static size_t readln(char[] buffer) {
        size_t length = 0;
        while(length < buffer.length) {
            const ch = getchar();
            if(ch < 0) break;
            buffer[length++] = cast(char) ch;
            if(ch == '\n') break;
        }
        return length;
    }
}

/// Uncomment for stdio tests
//private version(unittest) {
//    import capsule.core.typestrings;
//}
//unittest {
//    stdio.writeln("Hello world! ", 'x', writeInt(100));
//}
