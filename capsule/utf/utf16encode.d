/**

This module implements a range that can be used to lazily encode a
sequence of Unicode code points as a UTF-16 string.

*/

module capsule.utf.utf16encode;

private:

import capsule.range.range : asRange;

import capsule.utf.encode : UTFEncodeRange;

public:

/// Get a range that encodes a list of unicode code points
/// as a UTF-16 string.
auto utf16Encode(T)(auto ref T text) {
    return UTF16EncodeRange!(typeof(asRange(text)))(asRange(text));
}

template UTF16EncodeRange(Source) {
    alias UTF16EncodeRange = UTFEncodeRange!(UTF16EncodePoint, Source);
}

struct UTF16EncodePoint {
    nothrow @safe @nogc:
    
    dchar codePoint;
    
    bool ok() const {
        return !this.invalid && !this.wobbly;
    }
    
    bool invalid() const {
        return this.codePoint > 0x10ffff;
    }
    
    bool wobbly() const {
        return this.codePoint >= 0xd800 && this.codePoint <= 0xdfff;
    }
    
    size_t length() const {
        if(this.codePoint < 0x10000) {
            return 1;
        }
        else {
            return 2;
        }
    }
    
    wchar opIndex(in size_t index) const {
        assert(index < this.length);
        alias ch = this.codePoint;
        if(this.codePoint < 0x10000) {
            return cast(wchar) ch;
        }
        else {
            return (index == 0 ?
                cast(wchar) (0xd800 | ((ch - 0x10000) >> 10)) :
                cast(wchar) (0xdc00 | ((ch - 0x10000) & 0x3ff))
            );
        }
    }
}

private version(unittest) {
    import capsule.range.range : toArray;
}

/// Encode UTF-32 strings as UTF-8 strings
unittest {
    assert(""d.utf16Encode.toArray() == ""w);
    assert("test"d.utf16Encode.toArray() == "test"w);
    assert("hello"d.utf16Encode.toArray() == "hello"w);
    assert("א"d.utf16Encode.toArray() == "א"w);
    assert("אֲנָנָס"d.utf16Encode.toArray() == "אֲנָנָס"w);
    assert("ツ"d.utf16Encode.toArray() == "ツ"w);
    assert("ザーザー"d.utf16Encode.toArray() == "ザーザー"w);
    assert("!אツ"d.utf16Encode.toArray() == "!אツ"w);
    assert("😃"d.utf16Encode.toArray() == "😃"w);
    assert("?😃?"d.utf16Encode.toArray() == "?😃?"w);
    assert("!אツ😃"d.utf16Encode.toArray() == "!אツ😃"w);
}

/// Encode UTF-32 strings represented as types other than `dstring`
unittest {
    assert("test"d.asRange.utf16Encode.toArray() == "test"w);
    assert([cast(uint) 'x', cast(uint) 'ツ'].utf16Encode.toArray() == "xツ"w);
}

/// Invalid code points
unittest{
    /// Code point outside unicode planes
    auto a = [cast(dchar) 0x110000].utf16Encode;
    while(!a.empty) a.popFront();
    assert(!a.ok);
    assert(a.invalid);
    assert(!a.wobbly);
    /// UTF-16 surrogate
    auto b = [cast(dchar) 0xd8c0].utf16Encode;
    while(!b.empty) b.popFront();
    assert(!b.ok);
    assert(!b.invalid);
    assert(b.wobbly);
}
