module capsule.core.path;

public:

struct Path {
    nothrow @safe:
    
    string path;
    
    static typeof(this) join(T...)(in T parts) {
        static if(T.length == 0) {
            return typeof(this)(null);
        }
        else {
            string joined = null;
            foreach(i, _; parts) {
                size_t lastSep = 0;
                if(!joined.length && parts[i].length &&
                    (parts[i][0] == '/' || parts[i][0] == '\\')
                ) {
                    joined = "/";
                }
                for(size_t j = 0; j < parts[i].length; j++) {
                    if(parts[i][j] == '/' || parts[i][j] == '\\') {
                        if(j > lastSep) {
                            if(joined.length && joined[$ - 1] != '/') joined ~= '/';
                            joined ~= parts[i][lastSep .. j];
                        }
                        lastSep = j + 1;
                    }
                }
                if(parts[i].length > lastSep) {
                    if(joined.length && joined[$ - 1] != '/') joined ~= '/';
                    joined ~= parts[i][lastSep .. $];
                }
            }
            if(parts[$ - 1].length &&
                (parts[$ - 1][$ - 1] == '/' || parts[$ - 1][$ - 1] == '\\')
            ) {
                joined ~= '/';
            }
            return typeof(this)(joined);
        }
    }
    
    @nogc:
    
    string fileName() const {
        size_t i = this.path.length;
        while(i > 0 && this.path[i - 1] != '/' && this.path[i - 1] != '\\') i--;
        return 1 + i < this.path.length ? this.path[i .. $] : null;
    }
    
    string dirName() const {
        size_t i = this.path.length;
        while(i > 0 && this.path[i - 1] != '/' && this.path[i - 1] != '\\') i--;
        return this.path[0 .. i];
    }
    
    string fileExt() const {
        size_t i = this.path.length;
        while(i > 0 && this.path[i - 1] != '.') i--;
        return this.path[i .. $];
    }
    
    /// Determine whether a file path is absolute on the current platform.
    version(Posix) alias isAbsolute = isAbsolutePosix;
    version(Windows) alias isAbsolute = isAbsoluteWin;
    
    bool isRelative() const {
        return !this.isAbsolute();
    }
    
    /// Determine whether a Posix file path is absolute.
    /// Absolute Posix paths always start with '/'.
    bool isAbsolutePosix() const {
        return this.path.length && (this[0] == '/');
    }
    
    /// Determine whether a Windows file path is absolute.
    /// A Windows path is absolute when it fits one of these forms:
    /// Relative to current drive "\path" or UNC "\\path"
    /// Relative to given drive "C:\path"
    bool isAbsoluteWin() const {
        return (
            (this.length && (this[0] == '/' || this[0] == '\\')) ||
            (this.length >= 3 &&
                (this[1] == ':' && (this[2] == '/' || this[2] == '\\'))
            )
        );
    }
    
    size_t length() const {
        return this.path.length;
    }
    
    string toString() const {
        return this.path;
    }
    
    char opIndex(in size_t index) const {
        assert(index < this.path.length);
        return this.path[index];
    }
    
    bool opEquals(in string path) const {
        return this.path == path;
    }
    
    bool opEquals(in typeof(this) path) const {
        return this.path == path.path;
    }
}

unittest {
    assert(Path.join() == "");
    assert(Path.join("ok") == "ok");
    assert(Path.join("//ok///") == "/ok/");
    assert(Path.join("abc/def/", "/xyz", "123") == "abc/def/xyz/123");
    assert(Path.join("abc", "/def/xyz/", "123") == "abc/def/xyz/123");
    assert(Path.join(`abc\`, `\def\xyz\123`) == "abc/def/xyz/123");
    assert(Path.join("/hello", "world") == "/hello/world");
    assert(Path.join("one/", "two/") == "one/two/");
    assert(Path.join("/a/", "/b/", "/c/") == "/a/b/c/");
}

unittest {
    assert(Path(``).fileName == ``);
    assert(Path(``).dirName == ``);
    assert(Path(``).fileExt == ``);
}

unittest {
    assert(Path(`stuff.dat`).fileName == `stuff.dat`);
    assert(Path(`stuff.dat`).dirName == ``);
    assert(Path(`stuff.dat`).fileExt == `dat`);
}

unittest {
    assert(Path(`hello/world/stuff.dat`).fileName == `stuff.dat`);
    assert(Path(`hello\world\stuff.dat`).fileName == `stuff.dat`);
    assert(Path(`hello/world/stuff.dat`).dirName == `hello/world/`);
    assert(Path(`hello\world\stuff.dat`).dirName == `hello\world\`);
    assert(Path(`hello/world/stuff.dat`).fileExt == `dat`);
    assert(Path(`hello\world\stuff.dat`).fileExt == `dat`);
}
