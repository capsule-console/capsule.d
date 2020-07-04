/**

This module defines a vector type of arbitrary dimensions.

https://en.wikipedia.org/wiki/Euclidean_vector

*/

module capsule.math.vector;

private:

import capsule.meta.commontype : CommonType;
import capsule.meta.repeat : Repeat;

public:

alias Vector2(T) = Vector!(2, T);

alias Vector3(T) = Vector!(3, T);

alias Vector4(T) = Vector!(4, T);

alias Vector2i = Vector!(2, int);

alias Vector3i = Vector!(3, int);

alias Vector4i = Vector!(4, int);

auto vector(T...)(auto ref T values) nothrow @safe @nogc if(T.length) {
    return Vector!(T.length, CommonType!T)(values);
}

auto vector(T, X...)(auto ref X values) nothrow @safe @nogc if(X.length) {
    return Vector!(X.length, T)(values);
}

struct Vector(size_t size, T) {
    nothrow @safe @nogc:
    
    alias Value = T;
    alias Values = Repeat!(size, T);
    
    Values values;
    
    alias values this;
    
    static enum size_t length = size;
    
    static enum bool empty = (size == 0);
    
    /// Initialize from varargs
    this(X...)(auto ref X values) {
        foreach(i, _; Values) {
            static if(i < X.length) {
                this.values[i] = cast(T) values[i];
            }
            else {
                this.values[i] = T(0);
            }
        }
    }
    
    /// Initialize from a static array
    this(size_t N, X)(X[N] values) {
        foreach(i, _; Values) {
            static if(i < N) {
                this.values[i] = cast(T) values[i];
            }
            else {
                this.values[i] = T(0);
            }
        }
    }
    
    /// Initialize from a dynamic array
    this(X)(X[] values) {
        foreach(i, _; Values) {
            if(i < values.length) {
                this.values[i] = cast(T) values[i];
            }
            else {
                this.values[i] = T(0);
            }
        }
    }
    
    /// Initialize from another vector
    this(size_t N, X)(Vector!(N, X) vector) {
        foreach(i, _; Values) {
            static if(i < N) {
                this.values[i] = cast(T) vector.values[i];
            }
            else {
                this.values[i] = T(0);
            }
        }
    }
    
    static if(size >= 1) {
        alias x = typeof(this).values[0];
    }
    static if(size >= 2) {
        alias y = typeof(this).values[1];
    }
    static if(size >= 3) {
        alias z = typeof(this).values[2];
    }
    static if(size >= 4) {
        alias w = typeof(this).values[3];
    }
    
    T get(in size_t index) const {
        foreach(i, _; Values) {
            if(i == index) {
                return this.values[i];
            }
        }
        assert(false, "Index out of range.");
    }
    
    void set(in size_t index, in T value) {
        foreach(i, _; Values) {
            if(i == index) {
                this.values[i] = value;
                return;
            }
        }
        assert(false, "Index out of range.");
    }
    
    /// Override equality operator
    bool opEquals(X)(in Vector!(size, X) vector) const {
        foreach(i, _; Values) {
            if(this.values[i] != vector.values[i]) {
                return false;
            }
        }
        return true;
    }
}

/// Test basic vector initialization
unittest {
    assert(vector(int(1), int(2)) == vector(byte(1), byte(2)));
    assert(vector!int(0, 1, 2) == vector!byte(0, 1, 2));
    assert(vector!int(1, 2, 3) != vector!int(3, 2, 1));
    assert(Vector2i(4, 3) == Vector2i([4, 3]));
    assert(Vector2i(4, 5) == Vector2i(Vector2!byte(4, 5)));
}

/// Test component access
unittest {
    const v1 = Vector!(1, int)(2);
    const v2 = Vector!(2, int)(2, 4);
    const v3 = Vector!(3, int)(2, 4, 6);
    const v4 = Vector!(4, int)(2, 4, 6, 8);
    assert(v1.x == 2);
    assert(v2.x == 2);
    assert(v3.x == 2);
    assert(v4.x == 2);
    assert(v2.y == 4);
    assert(v3.y == 4);
    assert(v4.y == 4);
    assert(v3.z == 6);
    assert(v4.z == 6);
    assert(v4.w == 8);
    assert(v1[0] == 2);
    assert(v2[0] == 2);
    assert(v3[0] == 2);
    assert(v4[0] == 2);
    assert(v2[1] == 4);
    assert(v3[1] == 4);
    assert(v4[1] == 4);
    assert(v3[2] == 6);
    assert(v4[2] == 6);
    assert(v4[3] == 8);
    assert(v1.get(0) == 2);
    assert(v2.get(0) == 2);
    assert(v3.get(0) == 2);
    assert(v4.get(0) == 2);
    assert(v2.get(1) == 4);
    assert(v3.get(1) == 4);
    assert(v4.get(1) == 4);
    assert(v3.get(2) == 6);
    assert(v4.get(2) == 6);
    assert(v4.get(3) == 8);
}

/// Test component assignment
unittest {
    auto v4 = vector!int(1, 2, 3, 4);
    v4.x = 3;
    assert(v4 == vector(3, 2, 3, 4));
    v4.y = 5;
    assert(v4 == vector(3, 5, 3, 4));
    v4.z = 7;
    assert(v4 == vector(3, 5, 7, 4));
    v4.w = 9;
    assert(v4 == vector(3, 5, 7, 9));
    v4[0] = 0;
    assert(v4 == vector(0, 5, 7, 9));
    v4[1] = 2;
    assert(v4 == vector(0, 2, 7, 9));
    v4[2] = 4;
    assert(v4 == vector(0, 2, 4, 9));
    v4[3] = 6;
    assert(v4 == vector(0, 2, 4, 6));
    v4.set(0, 8);
    assert(v4 == vector(8, 2, 4, 6));
    v4.set(1, 7);
    assert(v4 == vector(8, 7, 4, 6));
    v4.set(2, 6);
    assert(v4 == vector(8, 7, 6, 6));
    v4.set(3, 5);
    assert(v4 == vector(8, 7, 6, 5));
}
