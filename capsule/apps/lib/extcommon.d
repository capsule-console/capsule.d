module capsule.apps.lib.extcommon;

public:

alias ExtensionErrorMessageCallback = void delegate(in string message);

mixin template CapsuleExtensionMixin() {
    alias ErrorMessageCallback = void delegate(in string message);
    
    ErrorMessageCallback onErrorMessage;
    
    void addErrorMessage(in string message) {
        if(this.onErrorMessage !is null) {
            this.onErrorMessage(message);
        }
    }
}

