module capsule.core.stringz;

nothrow @safe public:

struct StringZ {
    nothrow @safe:
    
    string text = "\0";
    
    this(in string text) {
        this.text = text ~ "\0";
    }
    
    bool empty() const @nogc {
        return this.text.length <= 1;
    }
    
    size_t length() const @nogc {
        assert(this.text.length);
        return this.text.length - 1;
    }
    
    const(char)* ptr() const @system {
        return this.text.ptr;
    }
    
    string toString() const @nogc {
        return this.text;
    }
    
    char opIndex(in size_t index) const @nogc {
        assert(index < this.length);
        return this.text[index];
    }
}

unittest {
    StringZ str = StringZ("");
    assert(str.length == 0);
    assert(str.ptr[0] == '\0');
}

unittest {
    StringZ str = StringZ("hello");
    assert(str.length == 5);
    assert(str[0] == 'h');
    assert(str.ptr[0] == 'h');
    assert(str.ptr[5] == '\0');
}
