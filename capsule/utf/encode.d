/**

This module implements a type commonly used by the utf8encode
and utf16encode modules to provide a range interface for enumerating
UTF-8 or UTF-16 code units encoding a given UTF-32 encoded string.

*/

module capsule.utf.encode;

public:

/// A range for enumerating the encoded code units of some inputted
/// UTF-32 string.
/// EncodePoint should be either UTF8EncodePoint or UTF16EncodePoint,
/// types which are used to encode a code point as UTF-8 or UTF-16.
struct UTFEncodeRange(alias EncodePoint, Source) {
    alias CodePoint = typeof(EncodePoint(dchar.init));
    
    Source source;
    uint codePointIndex = 0;
    bool invalid = false;
    bool wobbly = false;
    
    this(Source source){
        this.source = source;
    }
    
    bool ok() const {
        return !this.invalid && !this.wobbly;
    }
    
    bool empty() const{
        return this.source.empty;
    }
    
    auto front() const {
        assert(!this.empty);
        const point = EncodePoint(this.source.front);
        assert(this.codePointIndex < point.length);
        return point[this.codePointIndex];
    }
    
    void popFront() {
        assert(!this.empty);
        const front = this.source.front;
        const point = EncodePoint(front);
        this.codePointIndex++;
        if(this.codePointIndex >= point.length) {
            this.source.popFront();
            this.codePointIndex = 0;
            this.invalid = this.invalid || (front > 0x10ffff);
            this.wobbly = this.wobbly || (front >= 0xd800 && front <= 0xdfff);
        }
    }
}
