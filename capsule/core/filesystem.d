module capsule.core.filesystem;

import core.stdc.stdio : FILE;
import core.stdc.stdio : SEEK_CUR, SEEK_END, SEEK_SET;

version(Posix) {
    import core.sys.posix.sys.stat : stat, stat_t;
}

version(Windows) {
    import core.sys.windows.winbase : GetFileAttributesW;
    import core.sys.windows.winnt : INVALID_FILE_ATTRIBUTES;
    import capsule.core.utf.utf16decode : utf16Encode;
    import capsule.core.utf.utf8decode : utf8Decode;
}

version(CRuntime_Microsoft) {
    import core.sys.windows.stat : struct_stat, fstat;
}

version(Windows) {
    extern (C) nothrow @nogc FILE* _wfopen(in wchar* filename, in wchar* mode);
}

version(CRuntime_Microsoft){
    extern(C) @nogc nothrow int _fseeki64(FileHandle, long, int);
}

import capsule.core.stringz : stringz;

public nothrow:

version(CRuntime_Microsoft) {
    alias off_t = long;
}
else version(Windows) {
    alias off_t = int;
}
else version(Posix) {
    public import core.sys.posix.stdio : off_t;
}
else {
    static assert(false, "Unsupported platform.");
}

enum FileSeek: int {
    /// Relative to the current position in the file
    Cur = SEEK_CUR,
    /// Relative to the beginning of the file
    Set = SEEK_SET,
    /// Relative to the end of the file (Support dubious)
    End = SEEK_END,
}

FILE* openFile(in const(char)[] path, in const(char)[] mode) {
    version(Windows) {
        immutable(wchar)[] modewz;
        modewz.reserve(mode.length + 1);
        foreach(const ch; mode) modewz ~= ch;
        modewz ~= wchar(0);
        const pathwz = stringz(utf16Encode(utf8Decode(path)).toArray());
        return _wfopen(pathwz.ptr, modewz.ptr);
    }
    else version(Posix) {
        import core.stdc.stdio : fopen;
        const(char)[] modez = mode ~ '\0';
        const pathz = stringz(path);
        return fopen(pathz.ptr, modez.ptr);
    }
    else {
        static assert(false, "Unsupported platform.");
    }
}

int seekFile(FILE* file, in long offset, in FileSeek origin = FileSeek.Set) {
    version(CRuntime_Microsoft) {
        alias seek = _fseeki64;
    }
    else version(Windows) {
        import core.stdc.stdio : fseek;
        alias seek = fseek;
    }
    else version(Posix) {
        import core.sys.posix.stdio : fseeko;
        alias seek = fseeko;
    }
    else {
        static assert(false, "Unsupported platform.");
    }
    return seek(file, cast(off_t) offset, origin);
}

/// Get whether a path refers to any existing file.
bool fileExists(in const(char)[] path) @trusted {
    version(Windows) {
        // https://blogs.msdn.microsoft.com/oldnewthing/20071023-00/?p=24713/
        return Attributes(path).valid;
        const pathwz = stringz(utf16Encode(utf8Decode(path)).toArray());
        const attributes = GetFileAttributesW(pathwz.ptr);
        return attributes != INVALID_FILE_ATTRIBUTES;
    }
    else version(Posix) {
        // http://stackoverflow.com/a/230070/3478907
        auto pathz = stringz!char(path);
        stat_t st; return stat(pathz.ptr, &st) == 0;
    }
    else {
        static assert(false, "Unsupported platform.");
    }
}

unittest {
    assert(fileExists(__FILE_FULL_PATH__));
}
