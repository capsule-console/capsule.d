/**

This module implements Capsule's standard IO extensions (stdio).

https://en.wikipedia.org/wiki/Standard_streams

*/

module capsule.extension.stdio;

private:

import capsule.core.engine : CapsuleEngine, CapsuleExtensionCallResult;
import capsule.io.file : File, FileWriter;
import capsule.io.stdio : stdio;

import capsule.core.extension : CapsuleExtension;

import capsule.extension.common : CapsuleModuleMixin;
import capsule.extension.list : CapsuleExtensionListEntry;

public:

struct CapsuleStandardIOModule {
    mixin CapsuleModuleMixin;
    
    nothrow @safe:
    
    alias ecall_stdio_init = .ecall_stdio_init;
    alias ecall_stdio_quit = .ecall_stdio_quit;
    alias ecall_stdio_put_byte = .ecall_stdio_put_byte;
    alias ecall_stdio_get_byte = .ecall_stdio_get_byte;
    // TODO: ecall_stdio_flush
    // TODO: ecall_stdio_eof
    
    alias Extension = CapsuleExtension;
    
    bool stdinHasContent = false;
    string stdinPath = null;
    string stdoutPath = null;
    string stdinContent = null;
    size_t stdinIndex = 0;
    FileWriter stdoutWriter = FileWriter(null);
    
    this(MessageCallback onMessage) @nogc {
        this.onMessage = onMessage;
    }
    
    void setInputContent(in string content) @nogc {
        this.stdinContent = content;
        this.stdinHasContent = true;
    }
    
    void setInputPath(in string path) @nogc {
        this.stdinPath = path;
    }
    
    void setOutputPath(in string path) @nogc {
        this.stdoutPath = path;
    }
    
    void conclude() @nogc {
        if(this.stdoutWriter.isOpen) {
            this.stdoutWriter.close();
        }
    }
    
    CapsuleExtensionListEntry[] getExtensionList() {
        alias Entry = CapsuleExtensionListEntry;
        return [
            Entry(Extension.stdio_init, &ecall_stdio_init, &this),
            Entry(Extension.stdio_quit, &ecall_stdio_quit, &this),
            Entry(Extension.stdio_put_byte, &ecall_stdio_put_byte, &this),
            Entry(Extension.stdio_get_byte, &ecall_stdio_get_byte, &this),
        ];
    }
}

CapsuleExtensionCallResult ecall_stdio_init(
    void* data, CapsuleEngine* engine, in uint arg
) {
    assert(data);
    auto io = cast(CapsuleStandardIOModule*) data;
    bool anyFailure = false;
    if(io.stdoutWriter) {
        io.addErrorMessage("stdio.init: Already initialized.");
        anyFailure = true;
    }
    else if(io.stdoutPath.length) {
        io.stdoutWriter = FileWriter.open(io.stdoutPath);
        anyFailure = anyFailure || !io.stdoutWriter.ok;
        if(!io.stdoutWriter.ok) {
            io.addErrorMessage("stdio.init: Failed to open output file.");
        }
    }
    if(io.stdinPath.length) {
        auto stdinFile = File.read(io.stdinPath);
        io.stdinHasContent = true;
        io.stdinContent = stdinFile.content;
        io.stdinIndex = 0;
        anyFailure = anyFailure || !stdinFile.ok;
        if(!stdinFile.ok) {
            io.addErrorMessage("stdio.init: Failed read input file.");
        }
    }
    if(anyFailure) {
        return CapsuleExtensionCallResult.Error;
    }
    else {
        return CapsuleExtensionCallResult.Ok(0);
    }
}

CapsuleExtensionCallResult ecall_stdio_quit(
    void* data, CapsuleEngine* engine, in uint arg
) {
    assert(data);
    auto io = cast(CapsuleStandardIOModule*) data;
    if(io.stdoutWriter.isOpen) {
        io.stdoutWriter.close();
    }
    return CapsuleExtensionCallResult.Ok(0);
}

CapsuleExtensionCallResult ecall_stdio_put_byte(
    void* data, CapsuleEngine* engine, in uint arg
) {
    assert(data);
    auto io = cast(CapsuleStandardIOModule*) data;
    if(io.stdoutWriter) {
        io.stdoutWriter.put(cast(char) arg);
    }
    else {
        stdio.write(cast(char) arg);
    }
    return CapsuleExtensionCallResult.Ok(0);
}

CapsuleExtensionCallResult ecall_stdio_get_byte(
    void* data, CapsuleEngine* engine, in uint arg
) {
    assert(data);
    auto io = cast(CapsuleStandardIOModule*) data;
    if(!io.stdinHasContent) {
        const ch = stdio.readChar();
        return CapsuleExtensionCallResult.Ok(cast(uint) ch);
    }
    else if(io.stdinIndex < io.stdinContent.length) {
        const ch = io.stdinContent[io.stdinIndex++];
        return CapsuleExtensionCallResult.Ok(cast(uint) ch);
    }
    else {
        const ch = int(-1);
        return CapsuleExtensionCallResult.Ok(cast(uint) ch);
    }
}
