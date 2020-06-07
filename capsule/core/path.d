module capsule.core.path;

public:

/// Data structure wraps a string and provides utilities specially
/// for the manipulation of file path strings.
struct Path {
    nothrow @safe:
    
    version(Windows) {
        static enum char SeparatorChar = '\\';
        static enum string Separator = "\\";
    }
    else {
        static enum char SeparatorChar = '/';
        static enum string Separator = "/";
    }
    
    string path;
    
    static typeof(this) join(in string[] parts) {
        if(parts.length == 0) {
            return typeof(this)(null);
        }
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
    
    static typeof(this) join(T...)(in T parts) @trusted {
        static if(T.length == 0) {
            return typeof(this)(null);
        }
        else {
            string[parts.length] partStrings;
            foreach(i, part; parts) {
                partStrings[i] = cast(string) part;
            }
            return typeof(this).join(partStrings);
        }
    }
    
    string fileName() @nogc const {
        size_t i = this.path.length;
        while(i > 0 && this.path[i - 1] != '/' && this.path[i - 1] != '\\') i--;
        return 1 + i < this.path.length ? this.path[i .. $] : null;
    }
    
    string dirName() @nogc const {
        size_t i = this.path.length;
        while(i > 0 && this.path[i - 1] != '/' && this.path[i - 1] != '\\') i--;
        return this.path[0 .. i];
    }
    
    string fileExt() @nogc const {
        size_t i = this.path.length;
        while(i > 0 && this.path[i - 1] != '.') i--;
        return this.path[i .. $];
    }
    
    /// Determine whether a file path is absolute on the current platform.
    version(Posix) alias isAbsolute = isAbsolutePosix;
    version(Windows) alias isAbsolute = isAbsoluteWin;
    
    bool isRelative() @nogc const {
        return !this.isAbsolute();
    }
    
    /// Determine whether a Posix file path is absolute.
    /// Absolute Posix paths always start with '/'.
    bool isAbsolutePosix() @nogc const {
        return this.path.length && (this[0] == '/');
    }
    
    /// Determine whether a Windows file path is absolute.
    /// A Windows path is absolute when it fits one of these forms:
    /// Relative to current drive "\path" or UNC "\\path"
    /// Relative to given drive "C:\path"
    bool isAbsoluteWin() @nogc const {
        return (
            (this.length && (this[0] == '/' || this[0] == '\\')) ||
            (this.length >= 3 &&
                (this[1] == ':' && (this[2] == '/' || this[2] == '\\'))
            )
        );
    }
    
    string[] split() const {
        if(!this.path.length) {
            return null;
        }
        string[] parts;
        size_t partStartIndex = 0;
        bool lastWasSep = false;
        const firstIsSep = (this.path[0] == '/' || this.path[0] == '\\');
        for(size_t i = 0; i < this.path.length; i++) {
            const isSep = (this.path[i] == '/' || this.path[i] == '\\');
            if(isSep) {
                if(partStartIndex < i) {
                    parts ~= ((!parts.length && firstIsSep) ?
                        "/" ~ this.path[partStartIndex .. i] :
                        this.path[partStartIndex .. i]
                    );
                }
                partStartIndex = i + 1;
            }
        }
        if(partStartIndex < this.path.length) {
            parts ~= this.path[partStartIndex .. $];
        }
        return parts;
    }
    
    typeof(this) normalize() const {
        const parts = this.split();
        string[] normalParts;
        foreach(part; parts) {
            if(part == ".." && normalParts.length && normalParts[$ - 1] != "..") {
                normalParts.length--;
            }
            else if(part != ".") {
                normalParts ~= part;
            }
        }
        return typeof(this).join(normalParts);
    }
    
    /// Get the length of the path string in characters.
    size_t length() @nogc const {
        return this.path.length;
    }
    
    string toString() @nogc const {
        return this.path;
    }
    
    /// Get the character at an index.
    char opIndex(in size_t index) @nogc const {
        assert(index < this.path.length);
        return this.path[index];
    }
    
    bool opEquals(in string path) @nogc const {
        return this.path == path;
    }
    
    bool opEquals(in typeof(this) path) @nogc const {
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
    assert(Path("").split() == new string[0]);
    assert(Path("hello").split() == ["hello"]);
    assert(Path("hello/world").split() == ["hello", "world"]);
    assert(Path("a//b/c").split() == ["a", "b", "c"]);
    assert(Path("/abc/xyz/123/").split() == ["/abc", "xyz", "123"]);
}

unittest {
    assert(Path("").normalize() == "");
    assert(Path("./").normalize() == "");
    assert(Path("abc").normalize() == "abc");
    assert(Path("./xyz").normalize() == "xyz");
    assert(Path("../abc/xyz/../123").normalize() == "../abc/123");
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
