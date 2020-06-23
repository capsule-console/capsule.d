/**

This module provides definitions that are useful to have commonly
for the various Capsule extension modules present in this same
capsule.extension package.

*/

module capsule.extension.common;

public:

alias ExtensionErrorMessageCallback = void function(in char[] message);

mixin template CapsuleModuleMixin() {
    alias ErrorMessageCallback = void function(in char[] message);
    
    ErrorMessageCallback onErrorMessage;
    
    void addErrorMessage(in char[] message) {
        if(this.onErrorMessage !is null) {
            this.onErrorMessage(message);
        }
    }
}

