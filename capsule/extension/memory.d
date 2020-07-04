/**

This module implements Capsule's "memory" extensions.

*/

module capsule.extension.memory;

private:

import capsule.core.engine : CapsuleEngine, CapsuleExtensionCallResult;
import capsule.core.extension : CapsuleExtension;

import capsule.extension.common : CapsuleModuleMixin;
import capsule.extension.list : CapsuleExtensionListEntry, CapsuleExtensionList;

public:

struct CapsuleMemoryModule {
    mixin CapsuleModuleMixin;
    
    nothrow @safe:
    
    alias ecall_memory_brk = .ecall_memory_brk;
    
    alias Extension = CapsuleExtension;
    
    this(MessageCallback onMessage) {
        this.onMessage = onMessage;
    }
    
    void conclude() {
        // Do nothing
    }
    
    CapsuleExtensionListEntry[] getExtensionList() {
        alias Entry = CapsuleExtensionListEntry;
        return [
            Entry(Extension.memory_brk, &ecall_memory_brk, &this),
        ];
    }
}

/// Adjust program break.
/// Sets the destination register to 0 on success.
/// Sets it to a nonzero value upon failure.
CapsuleExtensionCallResult ecall_memory_brk(
    void* data, CapsuleEngine* engine, in uint arg
) {
    assert(engine);
    const brk = cast(int) arg;
    if(brk < engine.mem.bssStart) {
        return CapsuleExtensionCallResult.Ok(1);
    }
    const status = engine.mem.realloc(cast(uint) brk);
    return CapsuleExtensionCallResult.Ok(status ? 0 : 1);
}
