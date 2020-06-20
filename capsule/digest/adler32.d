/**

This module provides functions for computing the Adler-32
checksum of some data.

The Adler-32 checksum algorithm is most notable for its usage
in zlib compression.

https://en.wikipedia.org/wiki/Adler-32

https://en.wikipedia.org/wiki/Zlib

*/

module capsule.digest.adler32;

public:

/// Implementation for getting an Adler-32 checksum of some data.
struct Adler32 {
    nothrow @safe @nogc:
    
    static enum uint Modulo = 65521;
    
    uint a = 1;
    uint b = 0;
    
    this(in uint start) {
        this.a = start >>> 16;
        this.b = start & 0x0000FFFF;
    }
    
    this(in uint a, in uint b) {
        this.a = a;
        this.b = b;
    }
    
    static uint get(T)(in T[] buffer) {
        Adler32 adler;
        adler.put(buffer);
        return adler.result;
    }
    
    uint result() const {
        return (this.b << 16) | this.a;
    }
    
    void put(T)(in T value) if(T.sizeof == 1) {
        this.a += cast(ubyte) value;
        if(this.a >= Adler32.Modulo) this.a -= Adler32.Modulo;
        this.b += this.a;
        if(this.b >= Adler32.Modulo) this.b -= Adler32.Modulo;
    }
    
    void put(T)(in T[] buffer) @trusted {
        return this.put(cast(ubyte*) buffer.ptr, buffer.length * T.sizeof);
    }
    
    void put(in ubyte* buffer, in size_t length) @trusted {
        for(size_t i = 0; i < length; i++) {
            this.a += cast(ubyte) buffer[i];
            if(this.a >= Adler32.Modulo) this.a -= Adler32.Modulo;
            this.b += this.a;
            if(this.b >= Adler32.Modulo) this.b -= Adler32.Modulo;
        }
    }
}

uint adler32(T)(in T[] buffer) nothrow @safe @nogc {
    return Adler32.get(buffer);
}

uint adler32(T)(in uint start, in T[] buffer) nothrow @safe @nogc {
    Adler32 adler = Adler32(start);
    adler.put(buffer);
    return adler.result;
}

/// Test coverage for Adler-32 checksum algorithm
/// https://en.wikipedia.org/wiki/Adler-32#Example
/// https://hash.online-convert.com/adler32-generator
unittest {
    const string LoremIpsum = (
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, " ~
        "sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. " ~
        "Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris " ~
        "nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor " ~
        "in reprehenderit in voluptate velit esse cillum dolore eu fugiat " ~
        "nulla pariatur. Excepteur sint occaecat cupidatat non proident, " ~
        "sunt in culpa qui officia deserunt mollit anim id est laborum."
    );
    assert(adler32("") == 1);
    assert(adler32("Wikipedia") == 0x11e60398);
    assert(adler32(LoremIpsum) == 0xa05ca509);
}
