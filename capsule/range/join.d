module capsule.range.join;

import capsule.range.range : asRange;

public:

auto join(Sep, T)(auto ref Sep separator, auto ref T values) {
    return JoinRange!(
        typeof(asRange(separator)), typeof(asRange(values))
    )(
        asRange(separator), asRange(values)
    );
}

struct JoinRange(Sep, T) {
    Sep separator;
    T values;
    typeof(asRange(T.front)) currentValue;
    
    this(Sep separator, T values) {
        this.separator = separator;
        this.values = values;
        if(!this.values.empty) {
            this.currentValue = asRange(this.values.front);
        }
        if(!this.values.empty) {
            this.values.popFront();
        }
    }
    
    bool empty() const {
        return (
            this.values.empty &&
            this.currentValue.empty
        );
    }
    
    auto front() const {
        if(this.currentValue.empty) {
            return this.separator.front;
        }
        else {
            return this.currentValue.front;
        }
    }
    
    void popFront() {
        if(this.currentValue.empty) {
            this.separator.popFront();
            if(this.separator.empty) {
                this.separator.reset();
                this.currentValue = asRange(this.values.front);
                this.values.popFront();
            }
            return;
        }
        else {
            this.currentValue.popFront();
        }
    }
    
    void reset() {
        this.separator.reset();
        this.values.reset();
        if(!this.values.empty) {
            this.currentValue = asRange(this.values.front);
        }
        if(!this.values.empty) {
            this.values.popFront();
        }
    }
}

private version(unittest) {
    import capsule.range.map : map;
    import capsule.range.range : asRange, rangesEqual;
}

/// Test range joining with a separator
unittest {
    assert(rangesEqual(
        asRange(""),
        join(", ", new string[0])
    ));
    assert(rangesEqual(
        asRange("hello, , there, world"),
        join(", ", ["hello", "", "there", "world"])
    ));
    assert(rangesEqual(
        asRange("hello!, world!"),
        join(", ", ["hello", "world"].map!(s => s ~ "!"))
    ));
}
