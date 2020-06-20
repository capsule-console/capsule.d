module capsule.io.filesystem;

import core.stdc.stdio : FILE;
import core.stdc.stdio : SEEK_CUR, SEEK_END, SEEK_SET;

version(Posix) {
    import core.sys.posix.sys.stat : stat, stat_t;
    import core.sys.posix.sys.stat : S_IFMT, S_IFREG, S_IFDIR;
}

version(Windows) {
    import core.sys.windows.winnt : INVALID_FILE_ATTRIBUTES;
    import core.sys.windows.winnt : FILE_ATTRIBUTE_DIRECTORY;
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

import capsule.string.stringz : stringz;

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

version(Windows) auto getFileAttributes(in const(char)[] path) {
    import core.sys.windows.winbase : GetFileAttributesW;
    const pathwz = stringz(utf16Encode(utf8Decode(path)).toArray());
    return GetFileAttributesW(pathwz.ptr);
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
        const modez = mode ~ '\0';
        return fopen(stringz(path).ptr, modez.ptr);
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

/// Create a directory.
/// Returns true on success and false on failure.
bool makeDirectory(in const(char)[] path) {
    version(Windows) {
        // https://msdn.microsoft.com/en-us/library/windows/desktop/aa363855(v=vs.85).aspx
        import core.sys.windows.winbase : CreateDirectoryW;
        const pathwz = stringz(utf16Encode(utf8Decode(path)).toArray());
        return CreateDirectoryW(pathwz.ptr, null);
    }
    else version(Posix) {
        import core.sys.posix.sys.stat : mkdir;
        return mkdir(stringz(path).ptr, 0x1ff) == 0;
    }
    else {
        static assert(false, "Unsupported platform.");
    }
}

/// Get whether a path refers to any existing file.
bool fileExists(in const(char)[] path) @trusted {
    version(Windows) {
        // https://blogs.msdn.microsoft.com/oldnewthing/20071023-00/?p=24713/
        return getFileAttributes(path) != INVALID_FILE_ATTRIBUTES;
    }
    else version(Posix) {
        // http://stackoverflow.com/a/230070/3478907
        stat_t st;
        return stat(stringz(path).ptr, &st) == 0;
    }
    else {
        static assert(false, "Unsupported platform.");
    }
}

/// Returns true when the path exists and refers to a file.
bool isFile(in const(char)[] path) {
    version(Windows) {
        return (getFileAttributes(path) & FILE_ATTRIBUTE_DIRECTORY) == 0;
    }
    else version(Posix) {
        stat_t st;
        const status = stat(stringz(path).ptr, &st);
        return status == 0 && ((st.st_mode & S_IFMT) == S_IFREG);
    }
    else {
        static assert(false, "Unsupported platform.");
    }
}

/// Returns true when the path exists and refers to a directory.
bool isDirectory(in const(char)[] path) {
    version(Windows) {
        return (getFileAttributes(path) & FILE_ATTRIBUTE_DIRECTORY) != 0;
    }
    else version(Posix) {
        stat_t st;
        const status = stat(stringz(path).ptr, &st);
        return status == 0 && ((st.st_mode & S_IFMT) == S_IFDIR);
    }
    else {
        static assert(false, "Unsupported platform.");
    }
}

private version(unittest) {
    import capsule.io.path : Path;
    import core.stdc.stdio : fclose, fread;
    /// The very first line of this file
    enum FileStart = "module capsule.io.filesystem;";
    /// Path to this file
    enum FilePath = __FILE_FULL_PATH__;
    /// Path to the directory containing this file
    enum DirPath = Path(__FILE_FULL_PATH__).dirName;
    /// Path to a file that (presumably) does not exist
    enum FakePath = __FILE_FULL_PATH__ ~ ".not.a.real.file";
}

/// Tests for fileExists
unittest {
    assert(fileExists(FilePath));
    assert(fileExists(DirPath));
    assert(!fileExists(FakePath));
}

/// Tests for isFile
unittest {
    assert(isFile(FilePath));
    assert(!isFile(DirPath));
    assert(!isFile(FakePath));
}

/// Tests for isDirectory
unittest {
    assert(!isDirectory(FilePath));
    assert(isDirectory(DirPath));
    assert(!isDirectory(FakePath));
}

/// Tests for openFile (rb)
unittest {
    auto file = openFile(__FILE_FULL_PATH__, "rb");
    char[FileStart.length] buffer;
    const count = fread(buffer.ptr, char.sizeof, buffer.length, file);
    assert(count == buffer.length);
    assert(buffer == FileStart);
}
