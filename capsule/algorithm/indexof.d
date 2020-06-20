/**

This module implements functions for finding the index of an element
in a list.

*/

module capsule.algorithm.indexof;

public nothrow pure @safe @nogc:

/// Get the first index of an element in an array.
/// Returns -1 if the element did not appear in the array at all.
ptrdiff_t indexOf(T)(in T[] array, in T element) {
    for(size_t i = 0; i < array.length; i++) {
        if(array[i] == element) {
            return cast(ptrdiff_t) i;
        }
    }
    return -1;
}

/// Get the last index of an element in an array.
/// Returns -1 if the element did not appear in the array at all.
ptrdiff_t lastIndexOf(T)(in T[] array, in T element) {
    for(size_t i = array.length; i > 0; i--) {
        if(array[i - 1] == element) {
            return cast(ptrdiff_t) i - 1;
        }
    }
    return -1;
}
