module capsule.core.utf.utf8encode;

import capsule.core.utf.encode : UTFEncodeRange;
import capsule.range.range : asRange;

public:

/// Get a range that encodes a list of unicode code points
/// as a UTF-8 string.
auto utf8Encode(T)(auto ref T text) {
    return UTF8EncodeRange!(typeof(asRange(text)))(asRange(text));
}

template UTF8EncodeRange(Source) {
    alias UTF8EncodeRange = UTFEncodeRange!(UTF8EncodePoint, Source);
}

struct UTF8EncodePoint {
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
        if(this.codePoint <= 0x7f) {
            return 1;
        }
        else if(this.codePoint <= 0x7ff) {
            return 2;
        }
        else if(this.codePoint <= 0xffff) {
            return 3;
        }
        else {
            return 4;
        }
    }
    
    char opIndex(in size_t index) const {
        assert(index < this.length);
        alias ch = this.codePoint;
        if(ch <= 0x7f) {
            return cast(char) ch;
        }
        else if(ch <= 0x7ff) {
            return (index == 0 ?
                cast(char) (0xc0 | (ch >> 6)) :
                cast(char) (0x80 | (ch & 0x3f))
            );
        }
        else if(ch <= 0xffff) {
            return (
                index == 0 ? cast(char) (0xe0 | (ch >> 12)) :
                index == 1 ? cast(char) (0x80 | ((ch >> 6) & 0x3f)) :
                cast(char) (0x80 | (ch & 0x3f))
            );
        }
        else if(ch <= 0x10ffff) {
            return (
                index == 0 ? cast(char) (0xf0 | (ch >> 18)) :
                index == 1 ? cast(char) (0x80 | ((ch >> 12) & 0x3f)) :
                index == 2 ? cast(char) (0x80 | ((ch >> 6) & 0x3f)) :
                cast(char) (0x80 | (ch & 0x3f))
            );
        }
        else {
            return 0;
        }
    }
}

private version(unittest) {
    import capsule.range.range : toArray;
}

/// Encode UTF-32 strings as UTF-8 strings
unittest {
    assert(""d.utf8Encode.toArray() == "");
    assert("test"d.utf8Encode.toArray() == "test");
    assert("hello"d.utf8Encode.toArray() == "hello");
    assert("א"d.utf8Encode.toArray() == "א");
    assert("אֲנָנָס"d.utf8Encode.toArray() == "אֲנָנָס");
    assert("ツ"d.utf8Encode.toArray() == "ツ");
    assert("ザーザー"d.utf8Encode.toArray() == "ザーザー");
    assert("!אツ"d.utf8Encode.toArray() == "!אツ");
    assert("😃"d.utf8Encode.toArray() == "😃");
    assert("?😃?"d.utf8Encode.toArray() == "?😃?");
    assert("!אツ😃"d.utf8Encode.toArray() == "!אツ😃");
}

/// Encode UTF-32 strings represented as types other than `dstring`
unittest {
    assert("test"d.asRange.utf8Encode.toArray() == "test");
    assert([cast(uint) 'x', cast(uint) 'ツ'].utf8Encode.toArray() == "xツ");
}

/// Invalid code points
unittest{
    /// Code point outside unicode planes
    auto a = [cast(dchar) 0x110000].utf8Encode;
    while(!a.empty) a.popFront();
    assert(!a.ok);
    assert(a.invalid);
    assert(!a.wobbly);
    /// UTF-16 surrogate
    auto b = [cast(dchar) 0xd8c0].utf8Encode;
    while(!b.empty) b.popFront();
    assert(!b.ok);
    assert(!b.invalid);
    assert(b.wobbly);
}
