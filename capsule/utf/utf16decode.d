module capsule.core.utf.utf16decode;

import capsule.range.range : asRange;

public:

/// Get a range that decodes some UTF-16 encoded string and produces
/// a range to enumerate its code points as dchar values.
auto utf16Decode(T)(auto ref T text) {
    return UTF16DecodeRange!(typeof(asRange(text)))(asRange(text));
}

struct UTF16DecodeRange(Source) {
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
        return !this.unexpectedEof && !this.invalid;
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
        // Thrown when an invalid continuation byte is encountered
        this.lowIndex = this.highIndex;
        if(this.source.empty){
            this.isEmpty = true;
        }else{
            immutable wchar ch0 = this.source.front;
            this.source.popFront();
            this.highIndex++;
            if(ch0 < 0xd800 || ch0 > 0xdfff) {
                this.point = ch0;
            }
            // Surrogate pair
            else if(ch0 <= 0xdbff) {
                if(this.source.empty) {
                    this.unexpectedEof = true;
                    return;
                }
                const ch1 = this.source.front;
                if(ch1 < 0xdc00 || ch1 > 0xdfff) {
                    this.invalid = true;
                }
                this.point = 0x10000 + (
                    ((ch0 & 0x7ff) << 10) | (ch1 & 0x3ff)
                );
                this.source.popFront();
                this.highIndex++;
            }
            // Invalid sequence
            else {
                this.invalid = true;
            }
        }
    }
}

private version(unittest) {
    import capsule.range.range : toArray;
}

unittest {
    // Single code units
    assert(""w.utf16Decode.toArray() == ""d);
    assert("test"w.utf16Decode.toArray() == "test"d);
    assert("hello"w.utf16Decode.toArray() == "hello"d);
    assert("א"w.utf16Decode.toArray() == "א"d);
    assert("אֲנָנָס"w.utf16Decode.toArray() == "אֲנָנָס"d);
    assert("ツ"w.utf16Decode.toArray() == "ツ"d);
    assert("ザーザー"w.utf16Decode.toArray() == "ザーザー"d);
    assert("!אツ"w.utf16Decode.toArray() == "!אツ"d);
    // Surrogate pairs
    assert("😃"w.utf16Decode.toArray() == "😃"d);
    assert("?😃?"w.utf16Decode.toArray() == "?😃?"d);
    assert("!אツ😃"w.utf16Decode.toArray() == "!אツ😃"d);
    assert("𤭢"w.utf16Decode.toArray() == "𤭢"d);
    assert("\U0010F000"w.utf16Decode.toArray() == "\U0010F000"d);
}

unittest {
    assert("test"w.asRange.utf16Decode.toArray() == "test"d);
    assert([cast(ushort) 'h', cast(ushort) 'i'].utf16Decode.toArray() == "hi"d);
}

unittest {
    // Invalid start unit
    auto a = [ushort(0xd800)].utf16Decode;
    while(!a.empty) a.popFront();
    assert(!a.ok);
    // Invalid continuation unit
    auto b = [ushort(0xdbfe), ushort(0xe001)].utf16Decode;
    while(!b.empty) b.popFront();
    assert(!b.ok);
}
