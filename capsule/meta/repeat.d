/**

This module implements a template which can be used to repeat an alias
sequence some arbitrary number of times.

*/

module capsule.meta.repeat;

private:

import capsule.meta.aliases;

public:

/// Repeat the alias sequence after the first argument a number of times
/// as indicated by the first argument.
template Repeat(size_t count, T...) {
    static if(count <= 0) {
        alias Repeat = T[0 .. 0];
    }
    else static if(count == 1) {
        alias Repeat = T;
    }
    else static if(count == 2) {
        alias Repeat = Aliases!(T, T);
    }
    else {
        enum size_t left = count / 2;
        enum size_t right = count - left;
        alias Repeat = Aliases!(Repeat!(left, T), Repeat!(right, T));
    }
}

/// Tests for Repeat template
unittest {
    static assert(is(Repeat!(0, int) == Aliases!()));
    static assert(is(Repeat!(0, int, uint, long) == Aliases!()));
    static assert(is(Repeat!(1, int) == Aliases!(int)));
    static assert(is(Repeat!(1, void) == Aliases!(void)));
    static assert(is(Repeat!(1, int, uint, long) == Aliases!(int, uint, long)));
    static assert(is(Repeat!(4, int) == Aliases!(int, int, int, int)));
    static assert(is(Repeat!(4, int, uint, long) == Aliases!(
        int, uint, long, int, uint, long, int, uint, long, int, uint, long
    )));
}
