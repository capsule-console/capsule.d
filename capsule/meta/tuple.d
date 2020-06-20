/**

This module defines a tuple type, which is an important data
structure to have when doing metaprogramming in D.

https://dlang.org/tuple.html

*/

module capsule.meta.tuple;

public:

auto tuple(T...)(auto ref T values) {
    return Tuple!T(values);
}

auto tupleMap(alias transform, T...)(auto ref T values) {
    static if(T.length == 0) {
        return Tuple!().init;
    }
    else static if(T.length == 1) {
        return tuple(transform(values[0]));
    }
    else static if(T.length == 2) {
        return tuple(transform(values[0]), transform(values[1]));
    }
    else {
        enum half = T.length / 2;
        return tuple(
            tupleMap!transform(values[0 .. half]).values,
            tupleMap!transform(values[half .. $]).values
        );
    }
}

struct Tuple(T...) {
    T values;
    alias values this;
    
    this(T values) {
        this.values = values;
    }
}
