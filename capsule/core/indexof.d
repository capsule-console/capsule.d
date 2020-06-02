module capsule.core.indexof;

public nothrow pure @safe @nogc:

ptrdiff_t indexOf(T)(in T[] array, in T element) {
    for(size_t i = 0; i < array.length; i++) {
        if(array[i] == element) {
            return cast(ptrdiff_t) i;
        }
    }
    return -1;
}

ptrdiff_t lastIndexOf(T)(in T[] array, in T element) {
    for(size_t i = array.length; i > 0; i--) {
        if(array[i - 1] == element) {
            return cast(ptrdiff_t) i - 1;
        }
    }
    return -1;
}
