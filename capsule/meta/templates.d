module capsule.meta.templates;

public:

template Aliases(T...){
    alias Aliases = T;
}

template Unconst(T) {
    static if(is(T R == const R)) {
        alias Unconst = R;
    }
    else {
        alias Unconst = T;
    }
}

template isTemplateOf(alias T: Base!Args, alias Base, Args...){
    enum bool isTemplateOf = true;
}

template isTemplateOf(T: Base!Args, alias Base, Args...){
    enum bool isTemplateOf = true;
}

enum isTemplateOf(T, alias Base) = false;

enum isTemplateOf(T, Base) = false;
