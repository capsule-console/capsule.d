module capsule.core.bitflags;

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

private version(unittest) {
    enum FlagOptions: uint {
        A = 1,
        B = 2,
        C = 4,
        D = 8,
    }
}

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
