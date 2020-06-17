module capsule.apps.lib.stdio;

import capsule.core.engine : CapsuleEngine, CapsuleExtensionCallResult;
import capsule.core.file : File, FileWriter;
import capsule.core.stdio : stdio;

import capsule.apps.lib.extcommon : CapsuleExtensionMixin;

public:

struct CapsuleStandardIO {
    mixin CapsuleExtensionMixin;
    
    alias ecall_stdio_init = .ecall_stdio_init;
    alias ecall_stdio_put_byte = .ecall_stdio_put_byte;
    alias ecall_stdio_get_byte = .ecall_stdio_get_byte;
    
    /// Global instance shared by ecalls
    static typeof(this) global;
    
    bool stdinHasContent = false;
    string stdinPath = null;
    string stdoutPath = null;
    string stdinContent = null;
    size_t stdinIndex = 0;
    FileWriter stdoutWriter = FileWriter(null);
    
    void setInputContent(in string content) {
        this.stdinContent = content;
        this.stdinHasContent = true;
    }
    
    void setInputPath(in string path) {
        this.stdinPath = path;
    }
    
    void setOutputPath(in string path) {
        this.stdoutPath = path;
    }
}

CapsuleExtensionCallResult ecall_stdio_init(
    CapsuleEngine* engine, in uint arg
) {
    alias io = CapsuleStandardIO.global;
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
        return CapsuleExtensionCallResult.ExtError;
    }
    else {
        return CapsuleExtensionCallResult.Ok(0);
    }
}

CapsuleExtensionCallResult ecall_stdio_put_byte(
    CapsuleEngine* engine, in uint arg
) {
    alias io = CapsuleStandardIO.global;
    if(io.stdoutWriter) {
        io.stdoutWriter.put(cast(char) arg);
    }
    else {
        stdio.write(cast(char) arg);
    }
    return CapsuleExtensionCallResult.Ok(0);
}

CapsuleExtensionCallResult ecall_stdio_get_byte(
    CapsuleEngine* engine, in uint arg
) {
    alias io = CapsuleStandardIO.global;
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
