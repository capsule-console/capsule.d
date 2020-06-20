/**

This module provides utilities for compressing and decompressing data
using an LZ77-derived algorithm. It provides the best compression ratio
for text or text-like data.

The encoding used for this compressed data is a standard created
specifically for Capsule files and applications, designed to be
minimally complicated and as easy as possible to support while still
providing an acceptable level of compression.

*/

module capsule.algorithm.lz77;

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
    nothrow @safe @nogc:
    
    alias Distance = uint;
    alias Length = int;
    
    enum uint MaxTextLength = 127;
    enum uint MaxSubstringLength = 128;
    enum uint MaxDistance = ushort.max;
    
    const(ubyte)[] content;
    Length length;
    Distance distance;
}

/// Used internally by the LZ77Deflate type to represent the result of a
/// substring search.
struct LZ77SubstringResult {
    size_t length;
    size_t index;
}

/// Type used to compress data using an LZ77-derived algorithm.
struct LZ77Deflate {
    nothrow @safe:
    
    alias SubstringResult = LZ77SubstringResult;
    alias Unit = LZ77Unit;
    
    const(ubyte)[] content = null;
    size_t index = 0;
    SubstringResult queuedResult;
    ubyte[] buffer;
    
    void deflate() {
        while(this.index < this.content.length) {
            version(assert) const i = this.index;
            auto unit = this.getNextUnit();
            assert(unit.length || unit.content.length);
            this.addEncodeUnit(unit);
            version(assert) assert(this.index > i);
        }
    }
    
    void addEncodeUnit(in Unit unit) {
        if(unit.content.length) {
            assert(unit.content.length <= Unit.MaxTextLength);
            this.buffer ~= cast(ubyte) unit.content.length;
            this.buffer ~= unit.content;
        }
        else {
            assert(unit.length);
            assert(-unit.length <= Unit.MaxSubstringLength);
            this.buffer ~= cast(ubyte) (cast(byte) unit.length);
            this.buffer ~= cast(ubyte) unit.distance;
            this.buffer ~= cast(ubyte) (unit.distance >> 8);
        }
    }
    
    Unit getNextUnit() @nogc {
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
        while(this.index < this.content.length &&
            (this.index - start) < Unit.MaxTextLength
        ) {
            sub = this.findSubstring(this.index);
            if(sub.length) {
                this.queuedResult = sub;
                break;
            }
            this.index++;
        }
        return Unit(this.content[start .. this.index]);
    }
    
    auto findSubstring(in size_t index) @nogc const {
        const imin = (index > ushort.max ? index - ushort.max : 0);
        const jmax = (
            this.content.length - index < Unit.MaxSubstringLength ?
            this.content.length - index : Unit.MaxSubstringLength
        );
        size_t bestIndex = 0;
        size_t bestLength = 0;
        for(size_t i = imin; i < index; i++) {
            size_t j = 0;
            while(j < jmax && this.content[i + j] == this.content[index + j]) {
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
    nothrow @safe:
    
    alias Status = LZ77InflateStatus;
    alias Unit = LZ77Unit;
    
    const(ubyte)[] buffer = null;
    size_t index = 0;
    Status status = Status.Ok;
    ubyte[] content = null;
    
    void inflate() {
        while(this.index < this.buffer.length && this.status is Status.Ok) {
            version(assert) const i = this.index;
            this.step();
            version(assert) assert(this.status || i < this.index);
        }
    }
    
    bool ok() @nogc const {
        return this.status is Status.Ok;
    }
    
    void step() @trusted {
        assert(this.index < this.buffer.length);
        const length = cast(byte) this.buffer[this.index];
        if(length > 0) {
            if(this.index + 1 + length > this.buffer.length) {
                this.status = Status.UnexpectedEOF;
                return;
            }
            this.content ~= this.buffer[
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
            if(!distance || distance > this.content.length) {
                this.status = Status.InflateError;
                return;
            }
            size_t start = this.content.length - distance;
            const end = start - length;
            size_t contentEnd = (end < this.content.length ? end : this.content.length);
            this.content ~= this.content[start .. contentEnd];
            while(end > contentEnd) {
                start = contentEnd;
                contentEnd = (end < this.content.length ? end : this.content.length);
                this.content ~= this.content[start .. contentEnd];
            }
            this.index += 3;
        }
        else {
            this.status = Status.InflateError;
            return;
        }
    }
}

/// Convenience function to LZ77-compress data.
auto lz77Deflate(T)(in T[] content) nothrow @trusted {
    auto deflate = LZ77Deflate(cast(typeof(LZ77Deflate.content)) content);
    deflate.deflate();
    return deflate.buffer;
}

/// Convenience function to LZ77-decompress data.
auto lz77Inflate(T)(in T[] buffer) nothrow @trusted {
    auto inflate = LZ77Inflate(cast(typeof(LZ77Inflate.buffer)) buffer);
    inflate.inflate();
    return inflate;
}

private version(unittest) {
    import capsule.io.file : File;
}

/// Test coverage for LZ77 compression and decompression
@trusted unittest {
    File file = File.read("../casm/compile.d");
    auto deflate = LZ77Deflate(cast(ubyte[]) file.content);
    deflate.deflate();
    auto inflate = LZ77Inflate(deflate.buffer);
    inflate.inflate();
    assert(inflate.ok);
    assert(inflate.content == deflate.content);
    assert(deflate.buffer.length < deflate.content.length);
}

unittest {
    File file = File.read("../casm/parse.d");
    const buffer = lz77Deflate(file.content);
    const inflate = lz77Inflate(buffer);
    assert(inflate.ok);
    assert(inflate.content == file.content);
    assert(buffer.length < file.content.length);
}

unittest {
    File file = File.read("../../tests/lib/write-stringz.casm");
    const buffer = lz77Deflate(file.content);
    const inflate = lz77Inflate(buffer);
    assert(inflate.ok);
    assert(inflate.content == file.content);
    assert(buffer.length < file.content.length);
}
