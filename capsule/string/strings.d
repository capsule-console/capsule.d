module capsule.string.strings;

public nothrow @nogc:

bool startsWith(T)(in T[] text, in T[] sub) {
    if(text.length < sub.length) {
        return false;
    }
    return text[0 .. sub.length] == sub;
}

bool endsWith(T)(in T[] text, in T[] sub) {
    if(text.length < sub.length) {
        return false;
    }
    return text[$ - sub.length .. $] == sub;
}

auto padLeft(T)(in T[] text, in T padWith, in uint padLength) {
    if(text.length >= padLength) {
        return text;
    }
    T[] padded = new T[padLength];
    const padCount = padLength - text.length;
    for(uint i = 0; i < padCount; i++) {
        padded[i] = padWith;
    }
    padded[i .. $] = text;
    return padded;
}
