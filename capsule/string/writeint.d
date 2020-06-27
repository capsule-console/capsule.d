/**

This module provides functionality for converting an integer
to a decimal (base 10) string representation.

*/

module capsule.string.writeint;

public pure nothrow @safe @nogc:

/// Writes up to 10 characters for an unsigned 32-bit integer.
/// Writes up to 11 characters for a signed 32-bit integer.
/// Always writes at least one character.
/// Returns the number of characters written.
uint writeIntToBuffer(T)(in T value, char* buffer) @system {
    // Handle the case where the input is zero
    if(value == 0) {
        buffer[0] = '0';
        return 1;
    }
    // Write the digits (in reverse order)
    uint i = 0;
    T x = value;
    if(value > 0) {
        while(x > 0) {
            buffer[i++] = cast(char) ('0' + x % 10);
            x /= 10;
        }
    }
    else {
        while(x < 0) {
            buffer[i++] = cast(char) ('0' - x % 10);
            x /= 10;
        }
        buffer[i++] = '-';
    }
    // Reverse the digits written
    const half = i / 2;
    for(uint j = 0; j < half; j++) {
        const t = buffer[j];
        const k = i - j - 1;
        buffer[j] = buffer[k];
        buffer[k] = t;
    }
    // All done
    return i;
}

auto writeInt(T)(in T value) {
    return WriteIntRange!T(value);
}

struct WriteIntRange(T) {
    nothrow @safe @nogc:
    
    static if(T.sizeof <= 2) enum size_t BufferLength = 8;
    else static if(T.sizeof <= 4) enum size_t BufferLength = 12;
    else enum size_t BufferLength = 24;
    
    alias Buffer = char[BufferLength];
    
    uint length;
    uint index;
    Buffer buffer;
    
    this(in T value) @trusted {
        this.length = writeIntToBuffer(value, this.buffer.ptr);
    }
    
    auto getChars() const {
        return this.buffer[0 .. this.length];
    }
    
    bool empty() const {
        return this.index >= this.length;
    }
    
    char front() const {
        assert(this.index < this.length && this.index < this.buffer.length);
        return this.buffer[this.index];
    }
    
    void popFront() {
        assert(this.index < this.length && this.index < this.buffer.length);
        this.index++;
    }
    
    void reset() {
        this.index = 0;
    }
}

/// Tests for writeIntToBuffer
@trusted unittest {
    char[16] buffer;
    // Positive numbers
    for(uint i = 0; i < 16; i++) buffer[i] = 0;
    writeIntToBuffer(0, cast(char*) &buffer);
    assert(buffer[0 .. 2] == "0\0");
    writeIntToBuffer(1, cast(char*) &buffer);
    assert(buffer[0 .. 2] == "1\0");
    writeIntToBuffer(10, cast(char*) &buffer);
    assert(buffer[0 .. 3] == "10\0");
    writeIntToBuffer(12, cast(char*) &buffer);
    assert(buffer[0 .. 3] == "12\0");
    writeIntToBuffer(15, cast(char*) &buffer);
    assert(buffer[0 .. 3] == "15\0");
    writeIntToBuffer(27, cast(char*) &buffer);
    assert(buffer[0 .. 3] == "27\0");
    writeIntToBuffer(56, cast(char*) &buffer);
    assert(buffer[0 .. 3] == "56\0");
    writeIntToBuffer(79, cast(char*) &buffer);
    assert(buffer[0 .. 3] == "79\0");
    writeIntToBuffer(80, cast(char*) &buffer);
    assert(buffer[0 .. 3] == "80\0");
    writeIntToBuffer(93, cast(char*) &buffer);
    assert(buffer[0 .. 3] == "93\0");
    writeIntToBuffer(100, cast(char*) &buffer);
    assert(buffer[0 .. 4] == "100\0");
    writeIntToBuffer(1234, cast(char*) &buffer);
    assert(buffer[0 .. 5] == "1234\0");
    writeIntToBuffer(65535, cast(char*) &buffer);
    assert(buffer[0 .. 6] == "65535\0");
    writeIntToBuffer(4294967295, cast(char*) &buffer);
    assert(buffer[0 .. 11] == "4294967295\0");
    // Negative numbers
    for(uint i = 0; i < 16; i++) buffer[i] = 0;
    writeIntToBuffer(-1, cast(char*) &buffer);
    assert(buffer[0 .. 3] == "-1\0");
    writeIntToBuffer(-8, cast(char*) &buffer);
    assert(buffer[0 .. 3] == "-8\0");
    writeIntToBuffer(-9, cast(char*) &buffer);
    assert(buffer[0 .. 3] == "-9\0");
    writeIntToBuffer(-10, cast(char*) &buffer);
    assert(buffer[0 .. 4] == "-10\0");
    writeIntToBuffer(-16, cast(char*) &buffer);
    assert(buffer[0 .. 4] == "-16\0");
    writeIntToBuffer(-75, cast(char*) &buffer);
    assert(buffer[0 .. 4] == "-75\0");
    writeIntToBuffer(-255, cast(char*) &buffer);
    assert(buffer[0 .. 5] == "-255\0");
    writeIntToBuffer(-4321, cast(char*) &buffer);
    assert(buffer[0 .. 6] == "-4321\0");
    writeIntToBuffer(-95000, cast(char*) &buffer);
    assert(buffer[0 .. 7] == "-95000\0");
    writeIntToBuffer(-2147483648, cast(char*) &buffer);
    assert(buffer[0 .. 12] == "-2147483648\0");
}
