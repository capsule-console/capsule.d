/**

This module implements a range that can be used to lazily decode a
UTF-8 encoded string, producing a list of code points represented
as dchars.

*/

module capsule.utf.utf8decode;

private:

import capsule.range.range : asRange;

public:

/// Get a range that decodes some UTF-8 encoded string and produces
/// a range to enumerate its code points as dchar values.
auto utf8Decode(T)(auto ref T text) {
    return UTF8DecodeRange!(typeof(asRange(text)))(asRange(text));
}

struct UTF8DecodeRange(Source) {
    alias CodePoint = dchar;
    
    /// The string being decoded.
    Source source;
    /// The current code point.
    CodePoint point = 0;
    /// Whether the range has been fully exhausted.
    bool isEmpty = false;
    /// Low index of the most recently outputted code point.
    size_t lowIndex = 0;
    /// High index of the most recently outputted code point.
    size_t highIndex = 0;
    /// Set to true if the input unexpectedly ended in the middle
    /// of a multi-byte code point.
    bool unexpectedEof = false;
    /// Set to true if the input was found to be invalid UTF-8.
    bool invalid = false;
    /// Set to true if the input encoded any surrogate code point.
    /// https://simonsapin.github.io/wtf-8/
    bool wobbly = false;
    
    this(Source source) {
        this.source = source;
        this.isEmpty = this.source.empty;
        if(!this.isEmpty) this.popFront();
    }
    
    this(Source source, CodePoint point, bool isEmpty) {
        this.source = source;
        this.point = point;
        this.isEmpty = isEmpty;
    }
    
    /// Get the index of the current code point in the string being decoded.
    auto pointIndex() const {
        assert(!this.empty);
        return this.lowIndex;
    }
    
    /// Get the length in elements (typically bytes) of the current code point
    /// in the string being decoded.
    auto pointLength() const {
        assert(!this.empty);
        return this.highIndex - this.lowIndex;
    }
    
    bool ok() const {
        return !this.unexpectedEof && !this.invalid && !this.wobbly;
    }
    
    bool empty() const {
        return this.isEmpty;
    }
    
    auto front() const {
        assert(!this.empty);
        return this.point;
    }
    
    void popFront() {
        assert(!this.empty);
        this.lowIndex = this.highIndex;
        if(this.source.empty) {
            this.isEmpty = true;
        }
        else {
            auto continuation() {
                if(this.source.empty) {
                    this.unexpectedEof = true;
                    return 0;
                }
                immutable ch = this.source.front;
                if((ch & 0xc0) != 0x80) {
                    this.invalid = true;
                }
                this.source.popFront();
                this.highIndex++;
                return ch & 0x3f;
            }
            immutable char ch0 = this.source.front;
            this.source.popFront();
            this.highIndex++;
            if((ch0 & 0x80) == 0) {
                this.point = ch0;
            }
            else if((ch0 & 0xe0) == 0xc0) {
                immutable ch1 = continuation();
                this.point = cast(CodePoint) (
                    ((ch0 & 0x1f) << 6) | ch1
                );
                if(this.point < 0x80) {
                    this.invalid = true;
                }
            }
            else if((ch0 & 0xf0) == 0xe0) {
                immutable ch1 = continuation();
                immutable ch2 = continuation();
                this.point = cast(CodePoint) (
                    ((ch0 & 0x0f) << 12) | (ch1 << 6) | ch2
                );
                if(this.point < 0x0800) {
                    this.invalid = true;
                }
                else if(this.point >= 0xd800 && this.point <= 0xdfff) {
                    this.wobbly = true;
                }
            }
            else if((ch0 & 0xf8) == 0xf0) {
                immutable ch1 = continuation();
                immutable ch2 = continuation();
                immutable ch3 = continuation();
                this.point = cast(CodePoint) (
                    ((ch0 & 0x07) << 18) | (ch1 << 12) | (ch2 << 6) | ch3
                );
                if(this.point < 0x010000 || this.point > 0x10ffff) {
                    this.invalid = true;
                }
            }
            else {
                // Invalid initial code point byte
                this.invalid = true;
            }
        }
    }
}

private version(unittest) {
    import capsule.range.range : toArray;
}

unittest {
    // Single-byte
    assert("".utf8Decode.toArray() == ""d);
    assert("test".utf8Decode.toArray() == "test"d);
    assert("hello".utf8Decode.toArray() == "hello"d);
    // Two bytes
    assert("א".utf8Decode.toArray() == "א"d);
    assert("אֲנָנָס".utf8Decode.toArray() == "אֲנָנָס"d);
    // Three bytes
    assert("ツ".utf8Decode.toArray() == "ツ"d);
    assert("ザーザー".utf8Decode.toArray() == "ザーザー"d);
    assert("!אツ".utf8Decode.toArray() == "!אツ"d);
    // Four bytes
    assert("😃".utf8Decode.toArray() == "😃"d);
    assert("?😃?".utf8Decode.toArray() == "?😃?"d);
    assert("!אツ😃".utf8Decode.toArray() == "!אツ😃"d);
}

unittest {
    assert("test".asRange.utf8Decode.toArray() == "test"d);
    assert([cast(ubyte) 'h', cast(ubyte) 'i'].utf8Decode.toArray() == "hi"d);
}

unittest {
    auto a = "\xD7".utf8Decode;
    while(!a.empty) a.popFront();
    assert(!a.ok);
    auto b = "\xF0".utf8Decode;
    while(!b.empty) b.popFront();
    assert(!b.ok);
    auto c = "\xF0\x9F".utf8Decode;
    while(!c.empty) c.popFront();
    assert(!c.ok);
}

unittest {
    auto str = "!\xD7\x90\xE3\x83\x84\xF0\x9F\x98\x83"; // "!אツ😃"
    auto utf = str.utf8Decode;
    assert(utf.pointIndex == 0);
    assert(utf.pointLength == 1);
    utf.popFront();
    assert(utf.pointIndex == 1);
    assert(utf.pointLength == 2);
    utf.popFront();
    assert(utf.pointIndex == 3);
    assert(utf.pointLength == 3);
    utf.popFront();
    assert(utf.pointIndex == 6);
    assert(utf.pointLength == 4);
    utf.popFront();
    assert(utf.empty());
}
