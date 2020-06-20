/**

This module provides interfaces for reading from and writing to files.

*/

module capsule.io.file;

private:

import core.stdc.stdio : FILE;
import core.stdc.stdio : fopen, fclose, fread, feof, fwrite, fputc, fflush;

import capsule.io.filesystem : openFile;
import capsule.string.stringz : StringZ;

nothrow @safe public:

/// Enumeration of possible file read or write status codes.
enum FileStatus: uint {
    Ok = 0,
    UnspecifiedError,
    FilePathError,
    ReadError,
    WriteError,
}

/// Return type of the readFileContent function.
/// Pairs a content string with a file operation status code.
struct ReadFileResult {
    nothrow @safe @nogc:
    
    alias Status = FileStatus;
    
    static const FilePathError = typeof(this)(Status.FilePathError);
    static const ReadError = typeof(this)(Status.ReadError);
    
    Status status;
    string content;
    
    static typeof(this) Ok(in string content) pure nothrow @safe @nogc {
        return typeof(this)(Status.Ok, content);
    }
}

/// Get the entire content of a file as a single string.
ReadFileResult readFileContent(in string path) @trusted {
    alias Result = ReadFileResult;
    // Check the file path
    if(path.length <= 0) {
        return Result.FilePathError;
    }
    // Open the file
    FILE* file = openFile(path, "rb");
    if(file is null) {
        return Result.FilePathError;
    }
    // Read its contents
    char[1024] buffer;
    string content;
    while(true) {
        const count = fread(buffer.ptr, char.sizeof, buffer.length, file);
        if(count == buffer.length) {
            content ~= buffer;
        }
        else {
            content ~= buffer[0 .. count];
            break;
        }
    }
    // All done
    if(!feof(file)) {
        return Result.ReadError;
    }
    fclose(file);
    return Result.Ok(content);
}

/// Write a content string to a path as a complete file.
FileStatus writeFileContent(T)(
    in string path, in T[] content
) @trusted {
    alias Status = FileStatus;
    // Check the file path
    if(path.length <= 0) {
        return Status.FilePathError;
    }
    // Open the file
    FILE* file = openFile(path, "wb");
    if(file is null) {
        return Status.FilePathError;
    }
    // Write the content
    const count = fwrite(content.ptr, T.sizeof, content.length, file);
    // All done
    fclose(file);
    if(count != content.length) {
        return Status.WriteError;
    }
    return Status.Ok;
}

/// Type for representing a file, with a path string, a content string,
/// and a status indicator.
struct File {
    nothrow @safe:
    
    alias Status = FileStatus;
    
    string path;
    string content;
    Status status = Status.Ok;
    
    /// Read a file and its content completely and get a File
    /// instance representing that file.
    static typeof(this) read(in string path) {
        const read = readFileContent(path);
        return File(path, read.content, read.status);
    }
    
    /// Write the content associated with this file to a file path.
    auto write(in string toPath = "") const {
        return writeFileContent(toPath.length ? toPath : this.path, this.content);
    }
    
    @nogc:
    
    bool ok() const {
        return this.status is Status.Ok;
    }
    
    size_t length() const {
        return this.content.length;
    }
    
    auto reader() {
        return FileReader(this);
    }
    
    char opIndex(in size_t index) {
        assert(index >= 0 && index < this.content.length);
        return this.content[index];
    }
    
    string opSlice(in size_t low, in size_t high) {
        assert(low >= 0 && high >= low && high <= this.content.length);
        return this.content[low .. high];
    }
    
    bool opCast(T: bool)() const {
        return this.path || this.content;
    }
}

/// Data type for representing a location in a file.
struct FileLocation {
    nothrow @safe @nogc:
    
    File file;
    size_t startIndex;
    size_t endIndex;
    size_t lineStartIndex;
    size_t lineNumber;
    
    typeof(this) end(in size_t endIndex) const {
        return typeof(this)(
            this.file, this.startIndex, endIndex,
            this.lineStartIndex, this.lineNumber
        );
    }
    
    typeof(this) end(in FileLocation endLocation) const {
        return typeof(this)(
            this.file, this.startIndex, endLocation.endIndex,
            this.lineStartIndex, this.lineNumber
        );
    }
    
    size_t length() const {
        return this.endIndex - this.startIndex;
    }
    
    size_t column() const {
        return 1 + this.startIndex - this.lineStartIndex;
    }
    
    string toString() const {
        return this.file.content[this.startIndex .. this.endIndex];
    }
    
    bool opCast(T: bool)() const {
        return (
            this.file.path || this.file.content ||
            this.startIndex || this.endIndex || this.lineNumber
        );
    }
}

/// Range for enumerating the bytes in a file
struct FileReader {
    nothrow @safe @nogc:
    
    File file;
    size_t index = 0;
    size_t lineStartIndex = 0;
    size_t lineNumber = 1;
    
    string path() const {
        return this.file.path;
    }
    
    string content() const {
        return this.file.content;
    }
    
    size_t length() const {
        return this.file.content.length;
    }
    
    FileLocation location() const {
        return FileLocation(
            this.file, this.index, this.index,
            this.lineStartIndex, this.lineNumber
        );
    }
    
    bool empty() const {
        return this.index >= this.file.content.length;
    }
    
    char front() const {
        assert(this.index < this.file.content.length);
        return this.file.content[this.index];
    }
    
    void popFront() {
        assert(this.index < this.file.content.length);
        if(this.file.content[this.index] == '\n') {
            this.lineStartIndex = 1 + this.index;
            this.lineNumber++;
        }
        this.index++;
    }
    
    void skip(in size_t count) {
        assert(this.index + count <= this.length);
        for(size_t i = 0; i < count; i++) {
            this.popFront();
        }
    }
}

/// Utility for writing data to a file stream.
struct FileWriter {
    alias Status = FileStatus;
    
    FILE* file = null;
    Status status = Status.Ok;
    
    static open(in string path) @trusted {
        if(path.length <= 0) {
            return typeof(this)(null, Status.FilePathError);
        }
        // Open the file
        const string mode = "wb";
        const string pathz = path ~ "\0";
        FILE* file = fopen(pathz.ptr, mode.ptr);
        if(file is null) {
            return typeof(this)(null, Status.FilePathError);
        }
        else {
            return typeof(this)(file);
        }
    }
    
    bool ok() const {
        return this.status is Status.Ok && this.file !is null;
    }
    
    bool isOpen() const {
        return this.file !is null;
    }
    
    void close() @trusted {
        assert(this.file);
        if(this.file !is null) {
            fclose(this.file);
            this.file = null;
        }
    }
    
    Status put(T)(in T ch) if(T.sizeof == 1) {
        if(!this.file) {
            this.status = Status.WriteError;
            return Status.WriteError;
        }
        const result = fputc(cast(int) ch, this.file);
        if(result != ch) {
            this.status = Status.WriteError;
            return Status.WriteError;
        }
        return Status.Ok;
    }
    
    Status put(T)(in T[] content) {
        if(!this.file) {
            this.status = Status.WriteError;
            return Status.WriteError;
        }
        const count = fwrite(
            content.ptr, T.sizeof, content.length, this.file
        );
        if(count != content.length) {
            this.status = Status.WriteError;
            return Status.WriteError;
        }
        return Status.Ok;
    }
    
    bool opCast(T: bool)() const {
        return this.file !is null;
    }
}
