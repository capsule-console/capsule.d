module capsule.apps.lib.ecall;

import capsule.core.extension : CapsuleExtension;
import capsule.core.engine : CapsuleEngine, CapsuleExtensionCallResult;
import capsule.core.stdio : stdio;
import capsule.core.types : CapsuleExceptionCode;

private alias Engine = CapsuleEngine;
private alias ExceptionCode = CapsuleExceptionCode;
private alias Extension = CapsuleExtension;
private alias Result = CapsuleExtensionCallResult;

private alias Ext = EcallExt;
private alias ExtFunction = EcallExtFunction;

public:

alias EcallExtFunction = Result function(Engine* engine, in uint arg);

struct EcallExt {
    alias Function = EcallExtFunction;
    
    Extension id;
    Function func;
}

/// List must be sorted from lowest to highest extension ID value.
Ext[] ecallExtList = [
    Ext(Extension.meta_noop, &ecall_meta_noop),
    Ext(Extension.meta_exit_ok, &ecall_meta_exit_ok),
    Ext(Extension.meta_exit_error, &ecall_meta_exit_error),
    Ext(Extension.meta_check_ext, &ecall_meta_check_ext),
    Ext(Extension.meta_list_exts, &ecall_meta_list_exts),
    Ext(Extension.meta_host_uuid, &ecall_meta_host_uuid),
    Ext(Extension.meta_host_name, &ecall_meta_host_name),
    Ext(Extension.stdio_init, &ecall_stdio_init),
    Ext(Extension.stdio_quit, &ecall_stdio_quit),
    Ext(Extension.stdio_put_byte, &ecall_stdio_put_byte),
    Ext(Extension.stdio_get_byte, &ecall_stdio_get_byte),
    Ext(Extension.stdio_flush, &ecall_stdio_flush),
    Ext(Extension.stdio_eof, &ecall_stdio_eof),
];

ExtFunction getExtFunction(in uint id) {
    uint low = 0;
    uint high = cast(uint) ecallExtList.length;
    while(true) {
        const uint mid = low + ((high - low) / 2);
        if(mid < ecallExtList.length && ecallExtList[mid].id == id) {
            return ecallExtList[mid].func;
        }
        else if(low >= mid) {
            return null;
        }
        else if(ecallExtList[mid].id > id) {
            high = mid;
        }
        else {
            assert(ecallExtList[mid].id < id);
            low = mid + 1;
        }
    }
}

Result ecall(Engine* engine, in uint id, in uint arg) {
    assert(engine);
    auto extFunction = getExtFunction(id);
    if(extFunction) {
        return extFunction(engine, arg);
    }
    else {
        return Result.ExtMissing;
    }
}

Result ecall_meta_noop(Engine* engine, in uint arg) {
    return Result.Ok(0);
}

Result ecall_meta_exit_ok(Engine* engine, in uint arg) {
    engine.status = Engine.Status.ExitOk;
    return Result.Ok(0);
}

Result ecall_meta_exit_error(Engine* engine, in uint arg) {
    engine.status = Engine.Status.ExitError;
    return Result.Ok(0);
}

Result ecall_meta_check_ext(Engine* engine, in uint arg) {
    return Result.Ok(0); // TODO
}

Result ecall_meta_list_exts(Engine* engine, in uint arg) {
    return Result.Ok(0); // TODO
}

Result ecall_meta_host_uuid(Engine* engine, in uint arg) {
    return Result.Ok(0); // TODO
}

Result ecall_meta_host_name(Engine* engine, in uint arg) {
    return Result.Ok(0); // TODO
}

Result ecall_stdio_init(Engine* engine, in uint arg) {
    return Result.Ok(0); // TODO
}

Result ecall_stdio_quit(Engine* engine, in uint arg) {
    return Result.Ok(0); // TODO
}

Result ecall_stdio_put_byte(Engine* engine, in uint arg) {
    stdio.write(cast(char) arg);
    return Result.Ok(0);
}

Result ecall_stdio_get_byte(Engine* engine, in uint arg) {
    return Result.Ok(0); // TODO
}

Result ecall_stdio_flush(Engine* engine, in uint arg) {
    stdio.flush();
    return Result.Ok(0);
}

Result ecall_stdio_eof(Engine* engine, in uint arg) {
    return Result.Ok(0); // TODO
}
