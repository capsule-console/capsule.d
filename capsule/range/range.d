module capsule.range.range;

import capsule.meta.tuple : tupleMap;

public:

template isArray(T...){
    enum bool isArray = !is(T[0] == typeof(null)) && is(typeof({
        auto x(X)(X[] y){}
        x(T[0].init);
    }));
}

template isRange(T...) {
    enum bool isRange = is(typeof({
        auto range = T[0].init;
        if(range.empty) {}
        auto element = range.front;
        range.popFront();
    }));
}

template isRangeOf(Element, T...) {
    enum bool isRange = is(typeof({
        auto range = T[0].init;
        if(range.empty) {}
        Element element = range.front;
        range.popFront();
    }));
}

template RangeElementType(T...) {
    alias RangeElementType = typeof((() => (T[0].init.front))());
}

auto asRange(T)(auto ref T value) if(isRange!T) {
    return value;
}

auto asRange(T)(auto ref T value) if(isArray!T) {
    return ArrayRange!T(value);
}

auto asRanges(T...)(auto ref T values) {
    return tupleMap!asRange(values);
}

auto toArray(T)(auto ref T range) if(isRange!T) {
    RangeElementType!T[] array;
    static if(is(typeof(range.length))) {
        array.reserve(range.length);
    }
    foreach(item; range) {
        array ~= item;
    }
    return array;
}

auto toArrayOf(E, T)(auto ref T range) if(isRange!T) {
    E[] array;
    static if(is(typeof(range.length))) {
        array.reserve(range.length);
    }
    foreach(item; range) {
        array ~= cast(E) item;
    }
    return array;
}

bool rangesEqual(T...)(auto ref T ranges) {
    static if(T.length <= 1) {
        return true;
    }
    else {
        size_t numEmpty = 0;
        foreach(i, _; ranges) {
            numEmpty += ranges[i].empty ? 1 : 0;
        }
        if(numEmpty == T.length) {
            return true;
        }
        else if(numEmpty != 0) {
            return false;
        }
        size_t steps = 0;
        while(true) {
            numEmpty = 0;
            auto value = ranges[0].front;
            foreach(i, _; ranges) {
                static if(i > 0) {
                    if(ranges[i].front != value) {
                        return false;
                    }
                }
            }
            foreach(i, _; ranges) {
                ranges[i].popFront();
                numEmpty += ranges[i].empty ? 1 : 0;
            }
            if(numEmpty == T.length) {
                return true;
            }
            else if(numEmpty != 0) {
                return false;
            }
        }
        return false;
    }
}

struct ArrayRange(T) {
    nothrow @safe @nogc:
    
    T source;
    size_t index = 0;
    
    size_t length() pure const {
        return this.source.length;
    }
    
    bool empty() pure const {
        return this.index >= this.source.length;
    }
    
    auto front() pure const {
        assert(this.index < this.source.length);
        return this.source[this.index];
    }
    
    void popFront() {
        assert(this.index < this.source.length);
        this.index++;
    }
    
    void reset() {
        this.index = 0;
    }
}

/// Test coverage for range functions
unittest {
    int[] a = [1, 2, 3, 4];
    int[4] b = [1, 2, 3, 4];
    uint[] c = [1, 2, 3, 4];
    int[] d = [1, 2, 3, 8];
    int[] e = [1, 2, 3];
    const string hello = "hello";
    assert(rangesEqual());
    assert(rangesEqual(asRange(a)));
    assert(rangesEqual(asRange(a), asRange(c)));
    assert(rangesEqual(asRange(a), asRange(b), asRange(c)));
    assert(!rangesEqual(asRange(a), asRange(d)));
    assert(!rangesEqual(asRange(b), asRange(e)));
    assert(rangesEqual(asRange(hello), asRange(hello)));
}

/// Test coverage for toArrayOf
unittest {
    uint[] a = [0x01, 0x7f, 0xfff, 0xff80];
    ubyte[] b = [0x01, 0x7f, 0xff, 0x80];
    assert(toArrayOf!ubyte(asRange(a)) == b);
}
