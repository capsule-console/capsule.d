module capsule.range.map;

import capsule.range.range : asRange;

public:

auto map(alias transform, T)(auto ref T values) {
    return MapRange!(transform, typeof(asRange(values)))(asRange(values));
}

struct MapRange(alias transform, T) {
    T values;
    
    bool empty() const {
        return this.values.empty;
    }
    
    auto front() const {
        return transform(this.values.front);
    }
    
    void popFront() {
        this.values.popFront();
    }
    
    void reset() {
        this.values.reset();
    }
}

private version(unittest) {
    import capsule.range.range : asRange, rangesEqual;
}

/// Test map range
unittest {
    assert(rangesEqual(
        asRange("12345"),
        map!(i => cast(char) (i + 1))("01234")
    ));
}
