module capsule.core.stringz;

nothrow @safe public:

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
    
    string toString() const @nogc {
        return this.text;
    }
    
    T opIndex(in size_t index) const @nogc {
        assert(index < this.length);
        return this.text[index];
    }
}

unittest {
    StringZ str = StringZ!char("");
    assert(str.length == 0);
    assert(str.ptr[0] == '\0');
}

unittest {
    StringZ str = StringZ!char("hello");
    assert(str.length == 5);
    assert(str[0] == 'h');
    assert(str.ptr[0] == 'h');
    assert(str.ptr[5] == '\0');
}
