/**

This module implements functionality useful for escaping or unescaping
special characters in strings.

https://en.wikipedia.org/wiki/Escape_sequence

*/

module capsule.string.escape;

private:

import capsule.string.hex : getHexDigitValue, LowerHexDigits;

public:

char getCapsuleEscapeChar(in char ch) pure nothrow @safe @nogc {
    switch(ch) {
        case '\\': return '\\';
        case '\"': return '"';
        case '\0': return '0';
        case '\r': return 'r';
        case '\n': return 'n';
        case '\t': return 't';
        case '\f': return 'f';
        case '\v': return 'v';
        default: break;
    }
    if(ch <= 0x1F || ch == 0x7F) {
        return 'x';
    }
    else {
        return 0;
    }
}

char getCapsuleUnescapeChar(in char ch) pure nothrow @safe @nogc {
    switch(ch) {
        case '\\': return '\\';
        case '"': return '\"';
        case '0': return '\0';
        case 'r': return '\r';
        case 'n': return '\n';
        case 't': return '\t';
        case 'f': return '\f';
        case 'v': return '\v';
        default: return ch;
    }
}

auto escapeCapsuleText(in string text) pure nothrow @safe @nogc {
    return CapsuleEscapeTextRange(text);
}

auto unescapeCapsuleText(in string text) pure nothrow @safe @nogc {
    return CapsuleUnescapeTextRange(text);
}

struct CapsuleEscapeTextRange {
    nothrow @safe @nogc:
    
    string text;
    size_t index = 0;
    uint escIndex = 0;
    
    bool empty() const {
        return this.index >= this.text.length;
    }
    
    char front() const {
        const ch = this.text[this.index];
        const esc = getCapsuleEscapeChar(ch);
        if(!esc) {
            return ch;
        }
        if(this.escIndex == 0) {
            return '\\';
        }
        else if(this.escIndex == 1) {
            return esc;
        }
        else {
            const digit = (ch >> (4 * (3 - escIndex))) & 0xF;
            return LowerHexDigits[digit];
        }
    }
    
    void popFront() {
        const ch = this.text[this.index];
        const esc = getCapsuleEscapeChar(ch);
        if(esc) {
            this.escIndex++;
            if(esc == 'x' && this.escIndex > 3) {
                this.escIndex = 0;
            }
            else if(esc != 'x' && this.escIndex > 1) {
                this.escIndex = 0;
            }
            else {
                return;
            }
        }
        this.index++;
    }
    
    void reset() {
        this.index = 0;
        this.escIndex = 0;
    }
}

struct CapsuleUnescapeTextRange {
    nothrow @safe @nogc:
    
    string text;
    size_t index = 0;
    
    bool empty() const {
        return this.index >= this.text.length;
    }
    
    char front() const {
        assert(this.index < this.text.length);
        const ch = this.text[this.index];
        if(ch == '\\' &&
            this.index + 3 < this.text.length &&
            this.text[this.index + 1] == 'x'
        ) {
            const high = getHexDigitValue(this.text[this.index + 2]);
            const low = getHexDigitValue(this.text[this.index + 3]);
            return cast(char) ((high << 4) | low);
        }
        else if(ch == '\\' &&
            this.index + 1 < this.text.length
        ) {
            return getCapsuleUnescapeChar(this.text[this.index + 1]);
        }
        else {
            return ch;
        }
    }
    
    void popFront() {
        assert(this.index < this.text.length);
        const ch = this.text[this.index];
        if(ch == '\\' &&
            this.index + 3 < this.text.length &&
            this.text[this.index + 1] == 'x'
        ) {
            this.index += 4;
        }
        else if(ch == '\\' &&
            this.index + 1 < this.text.length
        ) {
            this.index += 2;
        }
        else {
            this.index++;
        }
    }
    
    void reset() {
        this.index = 0;
    }
}

private version(unittest) {
    import capsule.range.range : toArray;
}

/// Test string escaping
unittest {
    assert(escapeCapsuleText("hello").toArray() == "hello");
    assert(escapeCapsuleText("hello\tworld!").toArray() == `hello\tworld!`);
    assert(escapeCapsuleText("hello\0\0").toArray() == `hello\0\0`);
    assert(escapeCapsuleText("\\\"").toArray() == `\\\"`);
    assert(escapeCapsuleText("\x01").toArray() == `\x01`);
    assert(escapeCapsuleText("==\x01==").toArray() == `==\x01==`);
    assert(escapeCapsuleText("==\x7f==").toArray() == `==\x7f==`);
    assert(escapeCapsuleText("\0\\\"\r\n\t\v\f").toArray() == `\0\\\"\r\n\t\v\f`);
}

/// Test string unescaping
unittest {
    assert(unescapeCapsuleText("hello").toArray() == "hello");
    assert(unescapeCapsuleText(`hello\tworld!`).toArray() == "hello\tworld!");
    assert(unescapeCapsuleText(`hello\0\0`).toArray() == "hello\0\0");
    assert(unescapeCapsuleText(`\\\"`).toArray() == "\\\"");
    assert(unescapeCapsuleText(`\x01`).toArray() == "\x01");
    assert(unescapeCapsuleText(`==\x01==`).toArray() == "==\x01==");
    assert(unescapeCapsuleText(`==\x7f==`).toArray() == "==\x7f==");
    assert(unescapeCapsuleText(`\0\\\"\r\n\t\v\f`).toArray() == "\0\\\"\r\n\t\v\f");
}
