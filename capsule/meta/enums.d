/**

This module defines functions and templates that are useful
for dealing with D enum values and types.

https://dlang.org/spec/enum.html

*/

module capsule.meta.enums;

pure nothrow @safe @nogc public:

/// Check whether a given type is an enum type.
template isEnumType(T...) if(T.length == 1) {
    enum bool isEnumType = is(T[0] == enum);
}

/// Check whether an enum value corresponds to any
/// named member of the enum.
bool isNamedEnumMember(T)(in T value) {
    foreach(member; __traits(allMembers, T)) {
        if(value is __traits(getMember, T, member)) {
            return true;
        }
    }
    return false;
}

/// Get the name by which an enum value was declared.
/// Returns null if the value did not correspond to any
/// named member of the enum.
string getEnumMemberName(T)(in T value) {
    foreach(member; __traits(allMembers, T)) {
        if(value is __traits(getMember, T, member)) {
            return member;
        }
    }
    return null;
}

/// Check whether there is any member in an enum type
/// matching the given name.
bool isEnumMemberName(T)(in string name) {
    foreach(member; __traits(allMembers, T)) {
        if(name == member) {
            return true;
        }
    }
    return false;
}

/// Get the value of the enum member with a given name.
/// Returns T.init (probably the first, zero member) when
/// there was no enum member by that name.
T getEnumMemberByName(T)(in string name) {
    foreach(member; __traits(allMembers, T)) {
        if(name == member) {
            return __traits(getMember, T, member);
        }
    }
    return T.init;
}

/// Get the first UDA of a given type that was defined
/// for a given enum member.
/// Returns a default value when there was no matching UDA.
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

/// Get the first enum member value which has a UDA matching
/// the given value.
/// Returns T.init when there was no enum member with a
/// matching UDA value.
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

/// Define an enum type that will be used by unit tests.
private version(unittest) {
    enum TestEnum: uint {
        @("green") Apple = 0,
        @("blue") Blueberry,
        @(2, "red") Cranberry,
    }
}

/// Tests for isEnumType
unittest {
    assert(isEnumType!TestEnum);
    assert(!isEnumType!uint);
}

/// Tests for isNamedEnumMember
unittest {
    assert(isNamedEnumMember(TestEnum.Apple));
    assert(isNamedEnumMember(TestEnum.Blueberry));
    assert(isNamedEnumMember(TestEnum.Cranberry));
    assert(!isNamedEnumMember(cast(TestEnum) 1234));
}

/// Tests for getEnumMemberName
unittest {
    assert(getEnumMemberName(TestEnum.Apple) == "Apple");
    assert(getEnumMemberName(TestEnum.Blueberry) == "Blueberry");
    assert(getEnumMemberName(TestEnum.Cranberry) == "Cranberry");
    assert(!getEnumMemberName(cast(TestEnum) 1234));
}

/// Tests for isEnumMemberName
unittest {
    assert(isEnumMemberName!TestEnum("Apple"));
    assert(isEnumMemberName!TestEnum("Blueberry"));
    assert(isEnumMemberName!TestEnum("Cranberry"));
    assert(!isEnumMemberName!TestEnum("nope"));
}

/// Tests for getEnumMemberByName
unittest {
    assert(getEnumMemberByName!TestEnum("Apple") is TestEnum.Apple);
    assert(getEnumMemberByName!TestEnum("Blueberry") is TestEnum.Blueberry);
    assert(getEnumMemberByName!TestEnum("Cranberry") is TestEnum.Cranberry);
    assert(getEnumMemberByName!TestEnum("nope") is TestEnum.init);
}

/// Tests for getEnumMemberAttribute
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

/// Tests for getEnumMemberWithAttribute
unittest {
    assert(getEnumMemberWithAttribute!TestEnum("green") is TestEnum.Apple);
    assert(getEnumMemberWithAttribute!TestEnum("blue") is TestEnum.Blueberry);
    assert(getEnumMemberWithAttribute!TestEnum("red") is TestEnum.Cranberry);
    assert(getEnumMemberWithAttribute!TestEnum("xyz") is TestEnum.Apple);
}
