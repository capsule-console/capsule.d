module capsule.apps.lib.extcommon;

public:

alias ExtensionErrorMessageCallback = void delegate(in char[] message);

mixin template CapsuleExtensionMixin() {
    alias ErrorMessageCallback = void delegate(in char[] message);
    
    ErrorMessageCallback onErrorMessage;
    
    void addErrorMessage(in char[] message) {
        if(this.onErrorMessage !is null) {
            this.onErrorMessage(message);
        }
    }
}

