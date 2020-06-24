/**

This module implements Capsule's "time" extensions.

*/

module capsule.extension.time;

private:

import capsule.time.monotonic : monotonicns;
import capsule.time.sleep : sleepMilliseconds;

import capsule.core.engine : CapsuleEngine, CapsuleExtensionCallResult;
import capsule.core.extension : CapsuleExtension;

import capsule.extension.common : CapsuleModuleMixin;
import capsule.extension.list : CapsuleExtensionListEntry, CapsuleExtensionList;

public:

struct CapsuleTimeModule {
    mixin CapsuleModuleMixin;
    
    alias ecall_time_init = .ecall_time_init;
    alias ecall_time_quit = .ecall_time_quit;
    alias ecall_time_sleep_ms = .ecall_time_sleep_ms;
    alias ecall_time_monotonic_ms = .ecall_time_monotonic_ms;
    
    alias Extension = CapsuleExtension;
    
    this(ErrorMessageCallback onErrorMessage) {
        this.onErrorMessage = onErrorMessage;
    }
    
    void conclude() {
        // Do nothing
    }
    
    CapsuleExtensionListEntry[] getExtensionList() {
        alias Entry = CapsuleExtensionListEntry;
        return [
            Entry(Extension.time_init, &ecall_time_init, &this),
            Entry(Extension.time_quit, &ecall_time_quit, &this),
            Entry(Extension.time_sleep_ms, &ecall_time_sleep_ms, &this),
            Entry(Extension.time_monotonic_ms, &ecall_time_monotonic_ms, &this),
        ];
    }
}

/// Initialize time module.
CapsuleExtensionCallResult ecall_time_init(
    void* data, CapsuleEngine* engine, in uint arg
) {
    return CapsuleExtensionCallResult.Ok(0);
}

/// Quit time module.
CapsuleExtensionCallResult ecall_time_quit(
    void* data, CapsuleEngine* engine, in uint arg
) {
    return CapsuleExtensionCallResult.Ok(0);
}

/// Sleep for an approximate number of milliseconds.
CapsuleExtensionCallResult ecall_time_sleep_ms(
    void* data, CapsuleEngine* engine, in uint arg
) {
    sleepMilliseconds(arg);
    return CapsuleExtensionCallResult.Ok(0);
}

/// Get the monotonic clock's current number of milliseconds.
CapsuleExtensionCallResult ecall_time_monotonic_ms(
    void* data, CapsuleEngine* engine, in uint arg
) {
    const uint monotonicMilliseconds = cast(uint) (
        monotonicns() / 1_000_000L
    );
    return CapsuleExtensionCallResult.Ok(monotonicMilliseconds);
}
