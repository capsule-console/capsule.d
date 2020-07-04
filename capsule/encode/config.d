/**

This module provides functions that can be used to parse configuration
options given to an application via the command line and/or an INI
configuration file.

*/

module capsule.encode.config;

private:

import capsule.meta.enums : isEnumType;
import capsule.encode.ini : Ini;
import capsule.range.range : isArray;
import capsule.string.boolean : parseBooleanValue;
import capsule.string.parseint : parseSignedInt, parseUnsignedInt;

public:

enum CapsuleConfigStatus: uint {
    Ok = 0,
    UnspecifiedError,
    InvalidOptionNameError,
    InvalidOptionValueError,
    MissingRequiredOptionError,
}

static const string[] CapsuleConfigStatusStrings = [
    "",
    "Unspecified error.",
    "Invalid option name.",
    "Invalid option value.",
    "Missing required option.",
];

enum string CapsuleConfigStatusUnknownString = "Unknown config status";

string capsuleConfigStatusToString(
    in CapsuleConfigStatus status, in string context = null
) {
    alias Status = CapsuleConfigStatus;
    alias Strings = CapsuleConfigStatusStrings;
    alias UnknownString = CapsuleConfigStatusUnknownString;
    if(status is Status.Ok) {
        return null;
    }
    const size_t index = cast(size_t) status;
    if(index < Strings.length) {
        if(context && context.length) {
            return Strings[index] ~ " (" ~ context ~ ")";
        }
        else {
            return Strings[index];
        }
    }
    return UnknownString;
}

struct CapsuleConfigAttributeEnumName(T) {
    T value;
    string name;
}

struct CapsuleConfigAttribute(T) {
    alias Value = T;
    
    alias EnumName = CapsuleConfigAttributeEnumName!T;
    
    static enum bool isCapsuleConfigAttribute = true;
    static enum bool isArray = .isArray!T;
    
    string fullName;
    string shortName = null;
    string[] helpText;
    Value defaultValue = Value.init;
    bool optional = false;
    EnumName[] enumNames = null;
    size_t minLength = 0;
    
    this(in string fullName, in string shortName = null) {
        this.fullName = fullName;
        this.shortName = shortName;
        this.optional = false;
    }
    
    auto clone() {
        CapsuleConfigAttribute!T clone;
        clone.fullName = this.fullName;
        clone.shortName = this.shortName;
        clone.helpText = this.helpText;
        clone.defaultValue = this.defaultValue;
        clone.optional = this.optional;
        clone.enumNames = this.enumNames;
        clone.minLength = this.minLength;
        return clone;
    }
    
    auto setOptional(T defaultValue = T.init) {
        auto clone = this.clone();
        clone.optional = true;
        clone.defaultValue = defaultValue;
        return clone;
    }
    
    auto setHelpText(in string helpText) {
        return this.setHelpText([helpText]);
    }
    
    auto setHelpText(string[] helpText) {
        auto clone = this.clone();
        clone.helpText = helpText;
        return clone;
    }
    
    auto setMinLength(in size_t minLength) {
        auto clone = this.clone();
        clone.minLength = minLength;
        return clone;
    }
    
    auto setEnumNames(EnumName[] enumNames) {
        auto clone = this.clone();
        clone.enumNames = enumNames;
        return clone;
    }
}

struct CapsuleConfigResult(T) {
    alias Config = T;
    alias Status = CapsuleConfigStatus;
    alias Strings = CapsuleConfigStatusStrings;
    
    Config config;
    Status status;
    string context;
    
    bool ok() const @nogc {
        return this.status is Status.Ok;
    }
    
    void setStatus(in Status status, in string context = null) @nogc {
        this.status = status;
        this.context = context;
    }
    
    string toString() const {
        return capsuleConfigStatusToString(this.status, this.context);
    }
}

struct ParseCapsuleConfigAttributeResult(T) {
    bool ok;
    T value;
    size_t argsLength = 0;
}

auto parseCapsuleConfigAttribute(T: bool, Config)(
    ref Config config, in CapsuleConfigAttribute!T attribute,
    string[] args, in size_t argIndex, in bool isIni
) {
    alias Result = ParseCapsuleConfigAttributeResult!T;
    if(args.length > argIndex) {
        const value = parseBooleanValue(args[argIndex]);
        if(value >= 0) {
            return Result(true, cast(bool) value, 1);
        }
        else if(!isIni && (!args[argIndex].length || args[argIndex][0] == '-')) {
            return Result(true, true, 0);
        }
        else {
            return Result(false);
        }
    }
    else {
        return Result(true, true, 0);
    }
}

auto parseCapsuleConfigAttribute(T: int, Config)(
    ref Config config, in CapsuleConfigAttribute!T attribute,
    string[] args, in size_t argIndex, in bool isIni
) if(is(T == int) && !isEnumType!T) {
    alias Result = ParseCapsuleConfigAttributeResult!T;
    if(argIndex >= args.length) {
        return Result(false);
    }
    const result = parseSignedInt!int(args[argIndex]);
    return Result(result.ok, result.value, 1);
}

auto parseCapsuleConfigAttribute(T: uint, Config)(
    ref Config config, in CapsuleConfigAttribute!T attribute,
    string[] args, in size_t argIndex, in bool isIni
) if(is(T == uint) && !isEnumType!T) {
    alias Result = ParseCapsuleConfigAttributeResult!T;
    if(argIndex >= args.length) {
        return Result(false);
    }
    const result = parseUnsignedInt!uint(args[argIndex]);
    return Result(result.ok, result.value, 1);
}

auto parseCapsuleConfigAttribute(T, Config)(
    ref Config config, in CapsuleConfigAttribute!T attribute,
    string[] args, in size_t argIndex, in bool isIni
) if(isEnumType!T) {
    alias Result = ParseCapsuleConfigAttributeResult!T;
    if(argIndex >= args.length) {
        return Result(false);
    }
    foreach(enumName; attribute.enumNames) {
        if(enumName.name == args[argIndex]) {
            return Result(true, enumName.value, 1);
        }
    }
    return Result(false);
}

auto parseCapsuleConfigAttribute(T: string, Config)(
    ref Config config, in CapsuleConfigAttribute!T attribute,
    string[] args, in size_t argIndex, in bool isIni
) {
    alias Result = ParseCapsuleConfigAttributeResult!T;
    if(argIndex < args.length) {
        return Result(true, args[argIndex], 1);
    }
    else {
        return Result(false);
    }
}

auto parseCapsuleConfigAttribute(T: string[], Config)(
    ref Config config, in CapsuleConfigAttribute!T attribute,
    string[] args, in size_t argIndex, in bool isIni
) {
    alias Result = ParseCapsuleConfigAttributeResult!T;
    size_t i = argIndex;
    while(i < args.length && args[i].length && args[i][0] != '-') i++;
    if(i - argIndex < attribute.minLength) {
        return Result(false);
    }
    else {
        return Result(i > argIndex, args[argIndex .. i], i - argIndex);
    }
}

template isCapsuleConfigAttribute(Config, string member) {
    static if(is(typeof(__traits(getMember, Config, member)))) {
        enum attrs = __traits(getAttributes, __traits(getMember, Config, member));
        static if(attrs.length > 0 &&
            is(typeof(attrs[0].isCapsuleConfigAttribute)) &&
            attrs[0].isCapsuleConfigAttribute == true
        ) {
            enum bool isCapsuleConfigAttribute = true;
        }
        else {
            enum bool isCapsuleConfigAttribute = false;
        }
    }
    else {
         enum bool isCapsuleConfigAttribute = false;
    }
}

template getCapsuleConfigAttribute(Config, string member) {
    static if(is(typeof(__traits(getMember, Config, member)))) {
        enum attrs = __traits(getAttributes, __traits(getMember, Config, member));
        static if(attrs.length > 0 &&
            is(typeof(attrs[0].isCapsuleConfigAttribute)) &&
            attrs[0].isCapsuleConfigAttribute == true
        ) {
            alias getCapsuleConfigAttribute = attrs[0];
        }
        else {
            static assert(false);
        }
    }
    else {
         static assert(false);
    }
}

auto loadCapsuleConfig(Config)(
    string[] args, in Ini.Section iniSection = Ini.Section.init
) {
    alias Result = CapsuleConfigResult!Config;
    alias Status = CapsuleConfigStatus;
    Result result;
    bool[string] membersPresent;
    // Read INI and populate defaults
    foreach(member; __traits(allMembers, Config)) {
        static if(isCapsuleConfigAttribute!(Config, member)) {
            alias attr = getCapsuleConfigAttribute!(Config, member);
            alias Value = typeof(attr).Value;
            if(attr.fullName in iniSection) {
                auto values = iniSection.all(attr.fullName);
                auto attrResult = parseCapsuleConfigAttribute!Value(
                    result.config, attr, values, 0, true
                );
                mixin(`result.config.` ~ member ~ ` = attrResult.value;`);
                if(!attrResult.ok) {
                    result.setStatus(Status.InvalidOptionValueError, attr.fullName);
                    return result;
                }
                else {
                    membersPresent[member] = true;
                }
            }
            else if(attr.optional) {
                mixin(`result.config.` ~ member ~ ` = attr.defaultValue;`);
                membersPresent[member] = true;
            }
        }
    }
    // Parse CLI arguments
    size_t i = 0;
    while(i < args.length) {
        const arg = args[i];
        string fullName = null;
        string shortName = null;
        if(arg.length > 2 && arg[0] == '-' && arg[1] == '-') {
            fullName = arg[2 .. $];
        }
        else if(arg.length > 1 && arg[0] == '-') {
            shortName = arg[1 .. $];
        }
        i++;
        bool foundMember = false;
        foreach(member; __traits(allMembers, Config)) {
            static if(isCapsuleConfigAttribute!(Config, member)) {
                alias attr = getCapsuleConfigAttribute!(Config, member);
                alias Value = typeof(attr).Value;
                if((fullName && fullName == attr.fullName) ||
                    (shortName && shortName == attr.shortName)
                ) {
                    auto attrResult = parseCapsuleConfigAttribute!Value(
                        result.config, attr, args, i, false
                    );
                    mixin(`result.config.` ~ member ~ ` = attrResult.value;`);
                    i += attrResult.argsLength;
                    foundMember = true;
                    if(!attrResult.ok) {
                        result.setStatus(Status.InvalidOptionValueError, arg);
                        return result;
                    }
                    else {
                        membersPresent[member] = true;
                    }
                }
            }
        }
        if(!foundMember || (!fullName.length && !shortName.length)) {
            result.setStatus(Status.InvalidOptionNameError, arg);
            return result;
        }
    }
    // Check for missing mandatory config values
    foreach(member; __traits(allMembers, Config)) {
        static if(isCapsuleConfigAttribute!(Config, member)) {
            alias attr = getCapsuleConfigAttribute!(Config, member);
            if(!attr.optional && !(member in membersPresent)) {
                result.setStatus(Status.MissingRequiredOptionError, attr.fullName);
                return result;
            }
        }
    }
    // All done
    return result;
}

string getCapsuleConfigUsageString(Config)() {
    string text;
    static if(is(typeof(Config.UsageText) == string[])) {
        foreach(line; Config.UsageText) {
            text ~= line ~ "\n";
        }
    }
    text ~= "Options:\n";
    foreach(member; __traits(allMembers, Config)) {
        static if(isCapsuleConfigAttribute!(Config, member)) {
            alias attr = getCapsuleConfigAttribute!(Config, member);
            alias Value = typeof(attr).Value;
            text ~= "--" ~ attr.fullName;
            if(attr.shortName.length) {
                text ~= ", -" ~ attr.shortName;
            }
            text ~= "\n";
            foreach(line; attr.helpText) {
                text ~= "  " ~ line ~ "\n";
            }
            if(attr.enumNames.length) {
                text ~= "  Recognized values:\n    ";
                for(size_t i = 0; i < attr.enumNames.length; i++) {
                    if(i != 0) text ~= ", ";
                    text ~= attr.enumNames[i].name;
                }
                text ~= "\n";
            }
        }
    }
    return text;
}

//TODO treat first arg in list as either an ini path
//or a project directory path if it doesn't start with '-'

private version(unittest) static const TestIniContent = `
program-title=INI title
program-comment=INI comment
`;

private version(unittest) {
    import capsule.apps.clink : CapsuleLinkerConfig;
    import capsule.io.file : File;
}

unittest {
    auto args = [
        "-o", "output/path", "-i", "in/1", "in/2", "--program-title", "Hello",
        "--stack-length", "128"
    ];
    auto parser = Ini.Parser(File("test.ini", TestIniContent));
    parser.parse();
    assert(parser.ok);
    auto result = loadCapsuleConfig!CapsuleLinkerConfig(args, parser.ini.globals);
    assert(result.ok);
    auto config = result.config;
    assert(config.inputPaths == ["in/1", "in/2"]);
    assert(config.outputPath == "output/path");
    assert(config.programTitle == "Hello");
    assert(config.programComment == "INI comment");
    assert(config.stackSegmentLength == 128);
    assert(config.heapSegmentLength == 0);
}
