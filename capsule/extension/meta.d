/**

This module implements Capsule's "meta" extensions.

*/

module capsule.extension.meta;

private:

import capsule.core.engine : CapsuleEngine, CapsuleExtensionCallResult;

import capsule.core.extension : CapsuleExtension;

import capsule.extension.common : CapsuleModuleMixin;
import capsule.extension.list : CapsuleExtensionListEntry, CapsuleExtensionList;

public:

struct CapsuleMetaModule {
    mixin CapsuleModuleMixin;
    
    alias ecall_meta_noop = .ecall_meta_noop;
    alias ecall_meta_exit_ok = .ecall_meta_exit_ok;
    alias ecall_meta_exit_error = .ecall_meta_exit_error;
    alias ecall_meta_check_ext = .ecall_meta_check_ext;
    //alias ecall_meta_host_uuid = .ecall_meta_host_uuid; // TODO
    //alias ecall_meta_host_name = .ecall_meta_host_name; // TODO
    
    alias Extension = CapsuleExtension;
    
    CapsuleExtensionList* extList;
    
    this(ErrorMessageCallback onErrorMessage, CapsuleExtensionList* extList) {
        this.onErrorMessage = onErrorMessage;
        this.extList = extList;
    }
    
    void conclude() {
        // Do nothing
    }
    
    CapsuleExtensionListEntry[] getExtensionList() {
        alias Entry = CapsuleExtensionListEntry;
        return [
            Entry(Extension.meta_noop, &ecall_meta_noop, &this),
            Entry(Extension.meta_exit_ok, &ecall_meta_exit_ok, &this),
            Entry(Extension.meta_exit_error, &ecall_meta_exit_error, &this),
            Entry(Extension.meta_check_ext, &ecall_meta_check_ext, &this),
        ];
    }
}

CapsuleExtensionCallResult ecall_meta_noop(
    void* data, CapsuleEngine* engine, in uint arg
) {
    // No operation - do nothing.
    return CapsuleExtensionCallResult.Ok(0);
}

CapsuleExtensionCallResult ecall_meta_exit_ok(
    void* data, CapsuleEngine* engine, in uint arg
) {
    assert(engine);
    engine.status = CapsuleEngine.Status.ExitOk;
    return CapsuleExtensionCallResult.Ok(0);
}

CapsuleExtensionCallResult ecall_meta_exit_error(
    void* data, CapsuleEngine* engine, in uint arg
) {
    assert(engine);
    engine.status = CapsuleEngine.Status.ExitError;
    return CapsuleExtensionCallResult.Ok(0);
}

CapsuleExtensionCallResult ecall_meta_check_ext(
    void* data, CapsuleEngine* engine, in uint arg
) {
    assert(data);
    auto meta = cast(CapsuleMetaModule*) data;
    auto checkExt = cast(bool) meta.extList.getExtension(arg);
    return CapsuleExtensionCallResult.Ok(checkExt ? 1 : 0);
}
