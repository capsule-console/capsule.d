/**

This module implements a data structure that can be used to help manage
bit flags that are stored in an integer type.

https://en.wikipedia.org/wiki/Bit_field

*/

module capsule.bits.bitflags;

nothrow @safe public:

/// Convenience type to represent a bunch of flags.
/// First template argument is the type of the value holding the flags.
/// The second template argument should be an enum type naming the
/// value of each flag.
struct BitFlags(Flags, Option) {
    nothrow @safe @nogc:
    
    Flags flags;
    
    bool get(in Option option) const {
        return (this.flags & cast(Flags) option) != 0;
    }
    
    void set(in Option option) {
        this.flags |= cast(Flags) option;
    }
    
    void unset(in Option option) {
        this.flags &= ~(cast(Flags) option);
    }
    
    Flags opCast(T: Flags)() const {
        return this.flags;
    }
}

/// Define an enum type to be used for BitFlags test coverage
private version(unittest) {
    enum FlagOptions: uint {
        A = 1,
        B = 2,
        C = 4,
        D = 8,
    }
}

/// Test coverage for the BitFlags type
unittest {
    BitFlags!(uint, FlagOptions) flags;
    assert(!flags.get(FlagOptions.A));
    assert(!flags.get(FlagOptions.B));
    assert(!flags.get(FlagOptions.C));
    assert(!flags.get(FlagOptions.D));
    assert(cast(uint) flags == 0);
    flags.set(FlagOptions.A);
    flags.set(FlagOptions.D);
    assert(flags.get(FlagOptions.A));
    assert(!flags.get(FlagOptions.B));
    assert(!flags.get(FlagOptions.C));
    assert(flags.get(FlagOptions.D));
    assert(cast(uint) flags == (FlagOptions.A | FlagOptions.D));
    flags.unset(FlagOptions.A);
    assert(!flags.get(FlagOptions.A));
    assert(!flags.get(FlagOptions.B));
    assert(!flags.get(FlagOptions.C));
    assert(flags.get(FlagOptions.D));
    assert(cast(uint) flags == FlagOptions.D);
}
