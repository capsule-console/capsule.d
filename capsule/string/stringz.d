/**

This module provides a helper for getting a null-terminated string
from some input D string, such as might be needed to interface with
a C extern function.

*/

module capsule.string.stringz;

public:

/// Get a null-terminated string corresponding to the input string.
auto stringz(T)(in T[] text) {
    return StringZ!T(text);
}

/// Null-terminated string type.
struct StringZ(T) {
    nothrow @safe:
    
    const(T)[] text = null;
    
    this(in const(T)[] text) {
        this.text = text ~ T(0);
    }
    
    bool ok() const @nogc {
        return this.text.length && this.text[$ - 1] == 0;
    }
    
    bool empty() const @nogc {
        return this.text.length <= 1;
    }
    
    size_t length() const @nogc {
        assert(this.text.length);
        return this.text.length - 1;
    }
    
    const(T)* ptr() const @system {
        return this.text.ptr;
    }
    
    string toString() const @nogc @system {
        return cast(string) this.text;
    }
    
    T opIndex(in size_t index) const @nogc {
        assert(index < this.length);
        return this.text[index];
    }
}

/// Test StringZ with an empty string
unittest {
    auto str = StringZ!char("");
    assert(str.length == 0);
    assert(str.ptr[0] == '\0');
}

/// Test StringZ with a non-empty string
unittest {
    auto str = StringZ!char("hello");
    assert(str.length == 5);
    assert(str[0] == 'h');
    assert(str.ptr[0] == 'h');
    assert(str.ptr[5] == '\0');
}

/// Test coverage for stringz
unittest {
    auto str = stringz("hi");
    assert(str.length == 2);
    assert(str[0] == 'h');
    assert(str.ptr[0] == 'h');
    assert(str.ptr[2] == '\0');
}
