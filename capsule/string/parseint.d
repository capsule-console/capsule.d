module capsule.string.parseint;

import capsule.string.hex : parseHexString;

pure nothrow @safe @nogc public:

struct ParseIntResult(T) {
    bool ok;
    T value;
    
    auto opCast(X: ParseIntResult!Y, Y)() const {
        return ParseIntResult!Y(this.ok, cast(Y) this.value);
    }
}

auto parseInt(T)(in char[] text) {
    static if(T.sizeof == 1) {
        alias Signed = byte;
        alias Unsigned = ubyte;
    }
    else static if(T.sizeof == 2) {
        alias Signed = short;
        alias Unsigned = ushort;
    }
    else static if(T.sizeof == 4) {
        alias Signed = int;
        alias Unsigned = uint;
    }
    else {
        static assert(false, "Unknown integer type.");
    }
    if(text.length && (text[0] == '-' || text[0] == '+')) {
        return cast(ParseIntResult!T) parseSignedInt!Signed(text);
    }
    else {
        return cast(ParseIntResult!T) parseUnsignedInt!Unsigned(text);
    }
}

auto parseSignedInt(T)(in char[] text) {
    alias Result = ParseIntResult!T;
    if(!text.length) return Result(false);
    T value = 0;
    const negative = (text[0] == '-');
    const size_t start = (text[0] == '-' || text[1] == '+') ? 1 : 0;
    for(size_t i = start; i < text.length; i++) {
        if(text[i] < '0' || text[i] > '9') return Result(false);
        value = (10 * value) + (text[i] - '0');
    }
    return Result(true, negative ? -value : +value);
}

auto parseUnsignedInt(T)(in char[] text) {
    alias Result = ParseIntResult!T;
    if(!text.length) return Result(false);
    if(text.length > 2 && text[0] == '0' && (
        text[1] == 'x' || text[1] == 'X'
    )) {
        const result = parseHexString!T(text[2 .. $]);
        return Result(result.ok, result.value);
    }
    T value = 0;
    for(size_t i = 0; i < text.length; i++) {
        if(text[i] < '0' || text[i] > '9') return Result(false);
        value = (10 * value) + (text[i] - '0');
    }
    return Result(true, value);
}
