/**

This module provides definitions that are useful to have commonly
for the various Capsule extension modules present in this same
capsule.extension package.

*/

module capsule.extension.common;

public:

alias CapsuleModuleMessageCallback = void function(
    in CapsuleModuleMessageSeverity severity, in char[] message
);

enum CapsuleModuleMessageSeverity: uint {
    None = 0,
    Debug = 1,
    Info = 2,
    Warning = 3,
    Error = 4,
}

mixin template CapsuleModuleMixin() {
    import capsule.extension.common : CapsuleModuleMessageCallback;
    import capsule.extension.common : CapsuleModuleMessageSeverity;
    
    alias MessageCallback = CapsuleModuleMessageCallback;
    alias Severity = CapsuleModuleMessageSeverity;
    
    MessageCallback onMessage;
    
    void addMessage(in Severity severity, in char[] message) {
        if(this.onMessage !is null) {
            this.onMessage(severity, message);
        }
    }
    
    void addDebugMessage(in char[] message) {
        this.addMessage(Severity.Debug, message);
    }
    
    void addErrorMessage(in char[] message) {
        this.addMessage(Severity.Error, message);
    }
}

