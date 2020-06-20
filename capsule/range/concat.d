module capsule.range.concat;

import capsule.range.range : asRanges;

public:

auto concat(T...)(auto ref T values) {
    return ConcatRange!(typeof(asRanges(values).values))(asRanges(values).values);
}

struct ConcatRange(T...) {
    T sources;
    
    this(T sources) {
        this.sources = sources;
    }
    
    bool empty() const {
        foreach(i, _; this.sources) {
            if(!this.sources[i].empty) {
                return false;
            }
        }
        return true;
    }
    
    char front() const {
        foreach(i, _; this.sources) {
            if(!this.sources[i].empty) {
                return this.sources[i].front;
            }
        }
        assert(false);
    }
    
    void popFront() {
        foreach(i, _; this.sources) {
            if(!this.sources[i].empty) {
                this.sources[i].popFront();
                return;
            }
        }
        assert(false);
    }
    
    void reset() {
        foreach(i, _; this.sources) {
            this.sources[i].reset();
        }
    }
}

private version(unittest) {
    import capsule.range.range : asRange, rangesEqual;
}

/// Test range concatenation
unittest {
    assert(rangesEqual(asRange("hello world"), concat("hello", " ", "world")));
}
