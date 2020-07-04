/**

This module implements a template which can be used to get the common
type from a sequence of types, or to determine whether one exists.

*/

module capsule.meta.commontype;

public:

enum bool HasCommonType(T...) = __traits(compiles, CommonType!T);

template CommonType(T...) {
    static if(T.length <= 0) {
        static assert(false, "Empty type sequence has no common type.");
    }
    else static if(T.length == 1) {
        alias CommonType = T[0];
    }
    else static if(T.length == 2) {
        alias CommonType = typeof(0 ? T[0].init : T[1].init);
    }
    else static if(T.length == 3) {
        alias CommonType = typeof(0 ? 0 ? T[0].init : T[1].init : T[2].init);
    }
    else {
        enum size_t half = T.length / 2;
        alias CommonType = CommonType!(
            CommonType!(T[0 .. half]), CommonType!(T[half .. $])
        );
    }
}

private version(unittest) {
    import capsule.meta.aliases : Aliases;
}

/// Test coverage for CommonType template
unittest {
    static assert(is(CommonType!(int) == int));
    static assert(is(CommonType!(byte, short, int) == int));
    static assert(is(CommonType!(long, int) == long));
}

/// Test coverage for HasCommonType template
unittest {
    static assert(HasCommonType!(int));
    static assert(HasCommonType!(byte, short, int));
    static assert(HasCommonType!(long, int));
    static assert(!HasCommonType!());
    static assert(!HasCommonType!(int, string));
}

