module capsule.core.math;

public pure nothrow @safe @nogc:

/// Get the maximum of two values
int min(T)(in T x, in T y) {
    return x < y ? x : y;
}

/// Get the minimum of two values
int max(T)(in T x, in T y) {
    return x > y ? x : y;
}

/// Get the greatest common divisor
uint gcd(in uint x, in uint y) {
    uint a = x;
    uint b = y;
    while(b != 0) {
        uint t = b;
        b = a % b;
        a = t;
    }
    return a;
}

/// Get the least common multiple
uint lcm(in uint x, in uint y) {
    return (x * y) / gcd(x, y);
}

/// Count leading zeroes
uint clz(in uint value) {
    if(value == 0) {
        return 32;
    }
    uint i = 0;
    uint x = value;
    if((x & 0xFFFF0000) == 0) {
        i += 16;
        x <<= 16;
    }
    if((x & 0xFF000000) == 0) {
        i += 8;
        x <<= 8;
    }
    if((x & 0xF0000000) == 0) {
        i += 4;
        x <<= 4;
    }
    if((x & 0xC0000000) == 0) {
        i += 2;
        x <<= 2;
    }
    if((x & 0x80000000) == 0) {
        i += 1;
    }
    return i;
}

/// Count trailing zeroes
uint ctz(in uint value) {
    if(value == 0) {
        return 32;
    }
    uint i = 0;
    uint x = value;
    if((x & 0x0000FFFF) == 0) {
        i += 16;
        x >>= 16;
    }
    if((x & 0x000000FF) == 0) {
        i += 8;
        x >>= 8;
    }
    if((x & 0x0000000F) == 0) {
        i += 4;
        x >>= 4;
    }
    if((x & 0x00000003) == 0) {
        i += 2;
        x >>= 2;
    }
    if((x & 0x00000001) == 0) {
        i += 1;
    }
    return i;
}

/// Count set bits
/// http://cs-fundamentals.com/tech-interview/c/c-program-to-count-number-of-ones-in-unsigned-integer.php
uint pcnt(in uint value) {
    uint x = cast(uint) value;
    x = x - ((x >> 1) & 0x55555555);
    x = (x & 0x33333333) + ((x >> 2) & 0x33333333);
    x = (x + (x >> 4)) & 0x0F0F0F0F;
    x = x + (x >> 8);
    x = x + (x >> 16);
    return x & 0x0000003F;
}

bool isPow2(T)(in T value) {
    return (value & value - 1) ? 0 : 1;
}

/// Tests for gcd and lcm
unittest {
    assert(gcd(8, 4) == 4);
    assert(gcd(7, 11) == 1);
    assert(gcd(9, 6) == 3);
    assert(lcm(5, 10) == 10);
    assert(lcm(15, 10) == 30);
}

/// Tests for clz (count leading zeroes)
unittest {
    assert(clz(0x00000000) == 32);
    assert(clz(0x00000001) == 31);
    assert(clz(0x000007FF) == 21);
    assert(clz(0x00000FFF) == 20);
    assert(clz(0x00008000) == 16);
    assert(clz(0x00038000) == 14);
    assert(clz(0x03FFFFFF) == 6);
    assert(clz(0x10000000) == 3);
    assert(clz(0x30000000) == 2);
    assert(clz(0x75555555) == 1);
    assert(clz(0x80000000) == 0);
    assert(clz(0xFFFFFFFF) == 0);
}

/// Tests for ctz (count trailing zeroes)
unittest {
    assert(ctz(0x00000000) == 32);
    assert(ctz(0x80000000) == 31);
    assert(ctz(0x11100000) == 20);
    assert(ctz(0x00010000) == 16);
    assert(ctz(0x0003C000) == 14);
    assert(ctz(0xFFFFF000) == 12);
    assert(ctz(0xFFFFF800) == 11);
    assert(ctz(0xFFFFFC00) == 10);
    assert(ctz(0xFFFFFE00) == 9);
    assert(ctz(0x00000008) == 3);
    assert(ctz(0x00000002) == 1);
    assert(ctz(0x00000001) == 0);
    assert(ctz(0xFFFFFFFF) == 0);
}

/// Tests for pcnt (count set bits)
unittest {
    assert(pcnt(0xFFFFFFFF) == 32);
    assert(pcnt(0x7FFFFFFF) == 31);
    assert(pcnt(0xFF7FFFFF) == 31);
    assert(pcnt(0xFFF7FFFF) == 31);
    assert(pcnt(0xFFFFFFF7) == 31);
    assert(pcnt(0x7FFF7FFF) == 30);
    assert(pcnt(0x3FFFFFFF) == 30);
    assert(pcnt(0x7FFF7F7F) == 29);
    assert(pcnt(0x3F7FFFFF) == 29);
    assert(pcnt(0xFFFFF1FF) == 29);
    assert(pcnt(0xFFFFF0FF) == 28);
    assert(pcnt(0xFFFFFFF0) == 28);
    assert(pcnt(0x7FFFFFF0) == 27);
    assert(pcnt(0xFFF3F3F3) == 26);
    assert(pcnt(0x0000FFFF) == 16);
    assert(pcnt(0x00FF00FF) == 16);
    assert(pcnt(0x00000020) == 1);
    assert(pcnt(0x04000000) == 1);
    assert(pcnt(0x00008000) == 1);
    assert(pcnt(0x10000000) == 1);
    assert(pcnt(0x00100000) == 1);
    assert(pcnt(0x00000100) == 1);
    assert(pcnt(0x00000001) == 1);
    assert(pcnt(0x00000000) == 0);
}

/// Tests for isPow2
unittest {
    assert(isPow2(0x0));
    assert(isPow2(0x1));
    assert(isPow2(0x2));
    assert(isPow2(0x4));
    assert(isPow2(0x8));
    assert(isPow2(0x10));
    assert(isPow2(0x100));
    assert(isPow2(0x8000));
    assert(isPow2(0x80000000));
    assert(!isPow2(0x3));
    assert(!isPow2(0x5));
    assert(!isPow2(0xffff));
    assert(!isPow2(0x12345));
    assert(!isPow2(0xffffffff));
}
