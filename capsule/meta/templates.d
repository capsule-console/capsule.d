module capsule.meta.templates;

public:

template Unconst(T) {
    static if(is(T R == const R)) {
        alias Unconst = R;
    }
    else {
        alias Unconst = T;
    }
}
