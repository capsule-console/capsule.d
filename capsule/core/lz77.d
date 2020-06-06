module capsule.core.lz77;

public:

/// Enumeration of possible status values for the LZ77Inflate type.
enum LZ77InflateStatus: uint {
    Ok = 0,
    InflateError = 1,
    UnexpectedEOF = 2,
}

/// Used to represent a single unit of compressed data.
/// Can indicate either a literal string of bytes or a reference to
/// repeated prior data.
struct LZ77Unit {
    alias Distance = uint;
    alias Length = int;
    
    enum uint MaxTextLength = 127;
    enum uint MaxSubstringLength = 128;
    enum uint MaxDistance = ushort.max;
    
    string text;
    Length length;
    Distance distance;
    
    bool opCast(T: bool)() const {
        return this.length || this.text.length;
    }
}

/// Used internally by the LZ77Deflate type to represent the result of a
/// substring search.
struct LZ77SubstringResult {
    size_t length;
    size_t index;
}

/// Type used to compress data using an LZ77-derived algorithm.
struct LZ77Deflate {
    alias SubstringResult = LZ77SubstringResult;
    alias Unit = LZ77Unit;
    
    string text = null;
    size_t index = 0;
    SubstringResult queuedResult;
    ubyte[] buffer;
    
    void deflate() {
        while(this.index < this.text.length) {
            version(assert) const i = this.index;
            auto unit = this.getNextUnit();
            assert(unit.length || unit.text.length);
            this.addEncodeUnit(unit);
            version(assert) assert(this.index > i);
        }
    }
    
    void addEncodeUnit(in Unit unit) {
        if(unit.text.length) {
            assert(unit.text.length < Unit.MaxTextLength);
            this.buffer ~= cast(ubyte) unit.text.length;
            this.buffer ~= unit.text;
        }
        else {
            assert(unit.length);
            assert(-unit.length <= Unit.MaxSubstringLength);
            this.buffer ~= cast(ubyte) (cast(byte) unit.length);
            this.buffer ~= cast(ubyte) unit.distance;
            this.buffer ~= cast(ubyte) (unit.distance >> 8);
        }
    }
    
    Unit getNextUnit() {
        const start = this.index;
        auto sub = (this.queuedResult.length ?
            this.queuedResult : this.findSubstring(this.index)
        );
        if(sub.length) {
            const length = cast(Unit.Length) -(cast(int) sub.length);
            const distance = cast(Unit.Distance) (start - sub.index);
            assert(distance <= this.index);
            this.queuedResult.length = 0;
            this.index += sub.length;
            return Unit(null, length, distance);
        }
        while(this.index < this.text.length) {
            sub = this.findSubstring(this.index);
            if(sub.length) {
                this.queuedResult = sub;
                break;
            }
            this.index++;
        }
        return Unit(this.text[start .. this.index]);
    }
    
    auto findSubstring(in size_t index) const {
        const imin = (index > ushort.max ? index - ushort.max : 0);
        const jmax = (
            this.text.length - index < Unit.MaxSubstringLength ?
            this.text.length - index : Unit.MaxSubstringLength
        );
        size_t bestIndex = 0;
        size_t bestLength = 0;
        for(size_t i = imin; i < index; i++) {
            size_t j = 0;
            while(j < jmax && this.text[i + j] == this.text[index + j]) {
                j++;
            }
            if(j > bestLength && j > 3) {
                bestIndex = i;
                bestLength = j;
            }
        }
        return SubstringResult(bestLength, bestIndex);
    }
}

/// Type used to decompress data using an LZ77-derived algorithm.
struct LZ77Inflate {
    alias Status = LZ77InflateStatus;
    alias Unit = LZ77Unit;
    
    ubyte[] buffer = null;
    size_t index = 0;
    Status status = Status.Ok;
    string text = null;
    
    void inflate() {
        while(this.index < this.buffer.length && this.status is Status.Ok) {
            version(assert) const i = this.index;
            this.step();
            version(assert) assert(this.status || i < this.index);
        }
    }
    
    bool ok() const {
        return this.status is Status.Ok;
    }
    
    void step() {
        assert(this.index < this.buffer.length);
        const length = cast(byte) this.buffer[this.index];
        if(length > 0) {
            if(this.index + 1 + length > this.buffer.length) {
                this.status = Status.UnexpectedEOF;
                return;
            }
            this.text ~= cast(char[]) this.buffer[
                this.index + 1 .. this.index + 1 + length
            ];
            this.index += 1 + length;
        }
        else if(length < 0) {
            if(this.index + 2 >= this.buffer.length) {
                this.status = Status.UnexpectedEOF;
                return;
            }
            const distance = *(cast(ushort*) (&this.buffer[1 + this.index]));
            if(!distance || distance > this.text.length) {
                this.status = Status.InflateError;
                return;
            }
            size_t start = this.text.length - distance;
            const end = start - length;
            size_t textEnd = (end < this.text.length ? end : this.text.length);
            this.text ~= this.text[start .. textEnd];
            while(end > textEnd) {
                start = textEnd;
                textEnd = (end < this.text.length ? end : this.text.length);
                this.text ~= this.text[start .. textEnd];
            }
            this.index += 3;
        }
        else {
            this.status = Status.InflateError;
            return;
        }
    }
}

private version(unittest) {
    import capsule.core.file : File;
}

/// Test coverage for LZ77 compression and decompression
unittest {
    File file = File.read("../casm/compile.d");
    const testSource = file.content;
    auto deflate = LZ77Deflate(testSource);
    deflate.deflate();
    auto inflate = LZ77Inflate(deflate.buffer);
    inflate.inflate();
    assert(inflate.ok);
    assert(inflate.text == deflate.text);
    assert(deflate.buffer.length < deflate.text.length);
}
