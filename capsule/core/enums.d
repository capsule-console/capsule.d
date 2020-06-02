module capsule.core.enums;

pure nothrow @safe @nogc public:

template isEnumType(T...) if(T.length == 1) {
    enum bool isEnumType = is(T[0] == enum);
}

bool isNamedEnumMember(T)(in T value) {
    foreach(member; __traits(allMembers, T)) {
        if(value is __traits(getMember, T, member)) {
            return true;
        }
    }
    return false;
}

string getEnumMemberName(T)(in T value) {
    foreach(member; __traits(allMembers, T)) {
        if(value is __traits(getMember, T, member)) {
            return member;
        }
    }
    return null;
}

T getEnumMemberByName(T)(in string name) {
    foreach(member; __traits(allMembers, T)) {
        if(name == member) {
            return __traits(getMember, T, member);
        }
    }
    return T.init;
}

AttrType getEnumMemberAttribute(AttrType, T)(
    in T value, in AttrType defaultValue = AttrType.init
) {
    foreach(member; __traits(allMembers, T)) {
        if(value is __traits(getMember, T, member)) {
            enum Attributes = __traits(
                getAttributes, __traits(getMember, T, member)
            );
            foreach(i, _; Attributes) {
                static if(is(typeof({AttrType a = Attributes[i];}))) {
                    return Attributes[i];
                }
            }
            return defaultValue;
        }
    }
    return defaultValue;
}

T getEnumMemberWithAttribute(T, AttrType)(in AttrType value) {
    foreach(member; __traits(allMembers, T)) {
        static assert(member.length);
        enum T enumValue = __traits(getMember, T, member);
        enum Attributes = __traits(getAttributes, __traits(getMember, T, member));
        foreach(i, _; Attributes) {
            static if(is(typeof({if(value == Attributes[i]){}}))) {
                if(value == Attributes[i]) {
                    return enumValue;
                }
            }
        }
    }
    return T.init;
}

private version(unittest) {
    enum TestEnum: uint {
        @("green") Apple = 0,
        @("blue") Blueberry,
        @(2, "red") Cranberry,
    }
}

unittest {
    assert(isEnumType!TestEnum);
    assert(!isEnumType!uint);
}

unittest {
    assert(isNamedEnumMember(TestEnum.Apple));
    assert(isNamedEnumMember(TestEnum.Blueberry));
    assert(isNamedEnumMember(TestEnum.Cranberry));
    assert(!isNamedEnumMember(cast(TestEnum) 1234));
}

unittest {
    assert(getEnumMemberName(TestEnum.Apple) == "Apple");
    assert(getEnumMemberName(TestEnum.Blueberry) == "Blueberry");
    assert(getEnumMemberName(TestEnum.Cranberry) == "Cranberry");
    assert(!getEnumMemberName(cast(TestEnum) 1234));
}

unittest {
    assert(getEnumMemberByName!TestEnum("Apple") is TestEnum.Apple);
    assert(getEnumMemberByName!TestEnum("Blueberry") is TestEnum.Blueberry);
    assert(getEnumMemberByName!TestEnum("Cranberry") is TestEnum.Cranberry);
    assert(getEnumMemberByName!TestEnum("nope") is TestEnum.init);
}

unittest {
    assert(getEnumMemberAttribute!string(TestEnum.Apple) == "green");
    assert(getEnumMemberAttribute!string(TestEnum.Blueberry) == "blue");
    assert(getEnumMemberAttribute!string(TestEnum.Cranberry) == "red");
    assert(getEnumMemberAttribute!string(cast(TestEnum) 1234) == null);
    assert(getEnumMemberAttribute!int(TestEnum.Apple) == 0);
    assert(getEnumMemberAttribute!int(TestEnum.Blueberry) == 0);
    assert(getEnumMemberAttribute!int(TestEnum.Cranberry) == 2);
    assert(getEnumMemberAttribute!int(cast(TestEnum) 1234) == 0);
    assert(getEnumMemberAttribute!uint(TestEnum.Apple) == 0);
    assert(getEnumMemberAttribute!uint(TestEnum.Blueberry) == 0);
    assert(getEnumMemberAttribute!uint(TestEnum.Cranberry) == 2);
    assert(getEnumMemberAttribute!uint(cast(TestEnum) 1234) == 0);
}

unittest {
    assert(getEnumMemberWithAttribute!TestEnum("green") is TestEnum.Apple);
    assert(getEnumMemberWithAttribute!TestEnum("blue") is TestEnum.Blueberry);
    assert(getEnumMemberWithAttribute!TestEnum("red") is TestEnum.Cranberry);
    assert(getEnumMemberWithAttribute!TestEnum("xyz") is TestEnum.Apple);
}
