/**

This module provides functions for parsing and handling INI files.

*/

module capsule.encode.ini;

private:

import capsule.io.file : File, FileLocation, FileReader;
import capsule.io.messages : CapsuleMessageLog, CapsuleMessageSeverity;
import capsule.io.messages : getCapsuleMessageSeverityByChar;
import capsule.meta.enums : getEnumMemberAttribute;
import capsule.range.range : toArray;
import capsule.string.escape : escapeCapsuleText, unescapeCapsuleText;

private alias Status = IniMessageStatus;

public:

alias CapsuleIniMessageLog = CapsuleMessageLog!IniMessageStatus;

bool isIniInlineWhitespace(in char ch) pure nothrow @safe @nogc {
    return ch == ' ' || ch == '\t' || ch == '\r';
}

/// Enumerate recognized INI parser status values.
enum IniMessageStatus: uint {
    @('D', "")
    Ok = 0,
    @('E', "Invalid syntax.")
    InvalidSyntax,
    @('E', "Unterminated string literal.")
    UnterminatedStringLiteral,
    @('E', "Unmatched close bracket.")
    UnmatchedCloseBracket,
    @('E', "Unmatched open bracket.")
    UnmatchedOpenBracketError,
    @('E', "Invalid escape sequence.")
    InvalidEscapeSequenceError,
    @('E', "Invalid line continuation.")
    InvalidLineContinuationError,
    @('E', "Property has no name.")
    NoPropertyNameError,
    @('E', "Section has no name.")
    NoSectionNameError,
}

/// Represents a key, value pair in an INI file
struct IniKeyValuePair {
    nothrow @safe:
    
    string key;
    string value;
    
    static string escapeText(in string text) @trusted {
        string escaped = null;
        auto escapeRange = escapeCapsuleText(text);
        foreach(ch; escapeRange) {
            if(ch == '=') {
                escaped ~= "\\=";
            }
            else if(escaped.length && escaped[$ - 1] == '\\' && ch == 'n') {
                escaped ~= '\n';
            }
            else {
                escaped ~= ch;
            }
        }
        if(escaped.length &&
            isIniInlineWhitespace(escaped[0]) ||
            isIniInlineWhitespace(escaped[$ - 1])
        ) {
            escaped = "\"" ~ escaped ~ "\"";
        }
        return escaped;
    }
    
    string toString() @trusted const {
        auto key = typeof(this).escapeText(this.key);
        auto value = typeof(this).escapeText(this.value);
        return cast(string) (key ~ "=" ~ value);
    }
}

/// Represents information parsed from an INI file
struct Ini {
    nothrow @safe:
    
    alias Group = IniGroup;
    alias Pair = IniKeyValuePair;
    alias Parser = IniParser;
    alias Section = IniSection;
    
    /// Contains global key/value pairs (defined before any section)
    Section globals;
    /// A list of sections, in the order they were declared
    Section[] sections;
    
    auto addSection(Section section) {
        this.sections ~= section;
    }
    
    auto addSection(in string sectionName) {
        this.addSection(Section(sectionName));
    }
    
    string get(in string key) const @nogc {
        return this.get(null, key);
    }
    
    string get(in string sectionName, in string key) const @nogc {
        if(!sectionName || !sectionName.length) {
            auto value = (key in this.globals);
            return value is null ? null : *value;
        }
        foreach(section; this.sections) {
            if(section.name == sectionName) {
                auto value = (key in section);
                return value is null ? null : *value;
            }
        }
        return null;
    }
    
    string[] all(in string key) const {
        return this.all(null, key);
    }
    
    string[] all(in string sectionName, in string key) const {
        if(!sectionName || !sectionName.length) {
            auto values = this.globals.all(key);
            return values.length ? values : null;
        }
        foreach(section; this.sections) {
            if(section.name == sectionName) {
                auto values = section.all(key);
                return values.length ? values : null;
            }
        }
        return null;
    }
    
    void set(in string key, in string value) {
        return this.set(null, key, value);
    }
    
    void set(in string sectionName, in string key, in string value) {
        if(!sectionName || !sectionName.length) {
            this.globals[key] = value;
            return;
        }
        foreach(ref section; this.sections) {
            if(section.name == sectionName) {
                section[key] = value;
                return;
            }
        }
        this.sections ~= Section(sectionName);
        this.sections[$ - 1][key] = value;
    }
    
    void add(in string key, in string value) {
        return this.add(null, key, value);
    }
    
    void add(in string sectionName, in string key, in string value) {
        if(!sectionName || !sectionName.length) {
            this.globals.add(key, value);
            return;
        }
        foreach(ref section; this.sections) {
            if(section.name == sectionName) {
                section.add(key, value);
                return;
            }
        }
        this.sections ~= Section(sectionName);
        this.sections[$ - 1][key] = value;
    }
    
    /// Get a pointer to the first section with a matching name,
    /// or a null pointer if there was no matching section.
    Section getSection(in string sectionName) @nogc {
        foreach(ref section; this.sections) {
            if(section.name == sectionName) {
                return section;
            }
        }
        return Section.init;
    }
    
    /// Get the first section with a matching name,
    /// or an empty section if there was no match.
    Section* getSectionPtr(in string sectionName) @system @nogc {
        foreach(ref section; this.sections) {
            if(section.name == sectionName) {
                return &section;
            }
        }
        return null;
    }
    
    auto opBinaryRight(string op: "in")(in string sectionName) @system @nogc {
        return this.getSectionPtr(sectionName);
    }
    
    Section opIndex(in string sectionName) @nogc {
        return this.getSection(sectionName);
    }
    
    string toString() const {
        string text = this.globals.propertiesToString();
        foreach(section; this.sections) {
            text ~= section.toString();
        }
        return text;
    }
}

/// Represents a group of INI files, with sections and properties
/// in the earlier files being overridden by those in the latter files.
struct IniGroup {
    nothrow @safe:
    
    alias Pair = IniKeyValuePair;
    
    /// The list of INI files.
    /// Properties in earlier files in the list are overridden
    /// by properties in latter files in the list.
    Ini[] iniList;
    
    /// Get the first value defined in the global section for
    /// the given key by the last file that defines a key.
    string get(in string key) const @nogc {
        return this.get(null, key);
    }
    
    /// Get the first value defined in the named section for
    /// the given key by the last file that defines a key.
    string get(in string sectionName, in string key) const @nogc {
        foreach_reverse(ini; this.iniList) {
            auto value = ini.get(sectionName, key);
            if(value.length) {
                return value;
            }
        }
        return null;
    }
    
    /// Get the list of all values defined in the global section for
    /// the given key by the last file that defines a key.
    string[] all(in string key) const {
        return this.all(null, key);
    }
    
    /// Get the list of all values defined in the named section for
    /// the given key by the last file that defines a key.
    string[] all(in string sectionName, in string key) const {
        foreach_reverse(ini; this.iniList) {
            auto values = ini.all(sectionName, key);
            if(values.length) {
                return values;
            }
        }
        return null;
    }
    
    /// Get the aggregated list of all values defined in the
    /// global section of every file that defines a key.
    string[] aggregate(in string key) const {
        return this.aggregate(null, key);
    }
    
    /// Get the aggregated list of all values defined in the
    /// named section of every file that defines a key.
    string[] aggregate(in string sectionName, in string key) const {
        string[] values = null;
        foreach(ini; this.iniList) {
            values ~= ini.all(sectionName, key);
        }
        return values;
    }
    
    bool opCast(T: bool)() const {
        return this.iniList.length != 0;
    }
}

/// Represents a section in an INI file
struct IniSection {
    nothrow @safe:
    
    alias Pair = IniKeyValuePair;
    
    /// The name assigned to this section
    string name;
    /// Key/value pairs in this section
    Pair[] pairs;
    
    /// Get the number of key/value pairs defined in this section.
    /// Duplicate keys are counted separately.
    size_t length() @nogc const {
        return this.pairs.length;
    }
    
    /// Get the first value associated with a given key,
    /// or null if there was no such key.
    string get(in string key) @nogc const {
        foreach(ref pair; this.pairs) {
            if(pair.key == key) {
                return pair.value;
            }
        }
        return null;
    }
    
    /// Get a list of all values associated with a given key
    string[] all(in string key) const {
        string[] values = null;
        foreach(ref pair; this.pairs) {
            if(pair.key == key) {
                values ~= pair.value;
            }
        }
        return values;
    }
    
    /// Set the value of the first appearance of the key,
    /// if there is any, otherwise append the key, value pair
    /// to the end of the list.
    void set(in string key, in string value) {
        foreach(ref pair; this.pairs) {
            if(pair.key == key) {
                pair.value = value;
                return;
            }
        }
        this.pairs ~= Pair(key, value);
    }
    
    /// Append a new key, value pair to the end of the section.
    void add(in string key, in string value) {
        this.pairs ~= Pair(key, value);
    }
    
    /// Get a pointer to the first associated value string if the
    /// key is in the section, otherwise return null.
    auto opBinaryRight(string op: "in")(in string key) @trusted @nogc const {
        foreach(ref pair; this.pairs) {
            if(pair.key == key) {
                return &pair.value;
            }
        }
        return null;
    }
    
    string opIndex(in string key) @nogc const {
        return this.get(key);
    }
    
    Pair opIndex(in size_t index) @nogc const {
        return this.pairs[index];
    }
    
    void opIndexAssign(in string value, in string key) {
        this.set(key, value);
    }
    
    void opIndexAssign(in Pair pair, in size_t index) {
        this.pairs[index] = pair;
    }
    
    bool opCast(T: bool)() @nogc const {
        return this.name && this.name.length;
    }
    
    string toString() const {
        return "[" ~ this.name ~ "]\n" ~ this.propertiesToString();
    }
    
    string propertiesToString() const {
        string text = "";
        foreach(pair; this.pairs) {
            text ~= pair.toString() ~ "\n";
        }
        return text;
    }
}

/// Data structure used by the IniParser to represent a parsed line
/// of INI text data.
struct IniParserLine {
    /// Location in the INI file where the line appeared
    FileLocation location;
    /// Non-commented-out whitespace-trimmed text making up the line
    string text;
    /// Index of the first equals '=', or -1 if there was no equals
    ptrdiff_t equalsIndex;
    /// True if the line ended with an unescaped backslash '\'
    bool endEscaped;
}

/// Used to parse the contents of an INI file
struct IniParser {
    alias Line = IniParserLine;
    alias Log = CapsuleIniMessageLog;
    alias Status = IniMessageStatus;
    
    /// Provides content for the INI file being read
    FileReader reader;
    /// The INI data being assembled from the parsed text
    Ini ini;
    /// A log of error or message statuses encountered during parsing
    Log* log;
    
    static string trimText(in string text) {
        size_t start = 0;
        size_t end = text.length;
        while(start < end && isIniInlineWhitespace(text[start])) start++;
        while(start < end && isIniInlineWhitespace(text[end - 1])) end--;
        if(end < text.length && text[end - 1] == '\\') end++;
        return text[start .. end];
    }
    
    static string trimTextEnd(in string text) {
        size_t end = text.length;
        while(end > 0 && isIniInlineWhitespace(text[end - 1])) end--;
        return text[0 .. end];
    }
    
    this(Log* log, File file) {
        assert(log !is null);
        this.log = log;
        this.reader = file.reader;
    }
    
    this(Log* log, FileReader reader) {
        assert(log !is null);
        this.log = log;
        this.reader = reader;
    }
    
    bool ok() const {
        return this.log && !this.log.anyErrors;
    }
    
    void addStatus(in FileLocation location, in Status status, in string context = null) {
        assert(this.log);
        assert(status !is Status.Ok);
        auto severityChar = getEnumMemberAttribute!char(status);
        auto severity = getCapsuleMessageSeverityByChar(severityChar);
        this.log.add(location, severity, status, context);
    }
    
    typeof(this) parse() {
        while(!this.reader.empty) {
            this.parseNextLine();
        }
        return this;
    }
    
    void parseNextLine() {
        assert(!this.reader.empty);
        this.parseLine(this.getNextLine());
    }
    
    string getNextLineText() {
        const size_t startIndex = this.reader.index;
        char lastChar = 0;
        while(!this.reader.empty && this.reader.front != '\n') {
            lastChar = this.reader.front;
            this.reader.popFront();
        }
        const size_t endIndex = (lastChar == '\r' ?
            this.reader.index - 1 : this.reader.index
        );
        if(!this.reader.empty) {
            this.reader.popFront();
        }
        return this.reader.content[startIndex .. endIndex];
    }
    
    Line getNextLine() {
        const startLocation = this.reader.location();
        const line = typeof(this).trimText(this.getNextLineText());
        const lineLocation = startLocation.end(this.reader.location);
        if(!line.length) {
            return Line.init;
        }
        // Enumerate characters, look for comments ';' and equals '='
        ptrdiff_t equalsIndex = -1;
        ptrdiff_t commentStart = -1;
        bool escape = false;
        for(ptrdiff_t i = 0; i < line.length; i++) {
            const ch = line[i];
            if(escape) {
                escape = false;
            }
            else if(ch == '\\') {
                escape = true;
            }
            else if(ch == ';') {
                commentStart = i;
                break;
            }
            else if(equalsIndex < 0 && ch == '=') {
                equalsIndex = i;
            }
        }
        // Get the line text sans comment and with whitespace trimmed
        const size_t lineEnd = (
            commentStart >= 0 ? cast(size_t) commentStart : line.length
        );
        const lineText = typeof(this).trimTextEnd(line[0 .. lineEnd]);
        // Determine whether the line ended with an unescaped backslash '\'
        bool endEscape = false;
        size_t i = lineText.length;
        while(i > 0 && lineText[i - 1] == '\\') {
            endEscape = !endEscape;
            i--;
        }
        // All done
        return Line(lineLocation, lineText, equalsIndex, endEscape);
    }
    
    void parseLine(in Line line) @trusted {
        if(!line.text.length) {
            return;
        }
        string text = line.text;
        ptrdiff_t equalsIndex = line.equalsIndex;
        bool lineEndEscaped = line.endEscaped;
        while(lineEndEscaped) {
            if(this.reader.empty) {
                this.addStatus(this.reader.location, Status.InvalidLineContinuationError);
                return;
            }
            const next = this.getNextLine();
            if(equalsIndex < 0 && next.equalsIndex > 0) {
                equalsIndex = cast(ptrdiff_t) text.length + next.equalsIndex - 1;
            }
            text = text[0 .. $ - 1] ~ next.text;
            lineEndEscaped = next.endEscaped;
        }
        if(text[0] == '[' && text[$ - 1] == ']') {
            if(text.length <= 2) {
                this.addStatus(line.location, Status.NoSectionNameError);
                return;
            }
            this.ini.addSection(text[1 .. $ - 1]);
            return;
        }
        if(equalsIndex < 0) {
            this.addStatus(line.location, Status.InvalidSyntax);
            return;
        }
        string escapedKey = typeof(this).trimText(
            text[0 .. equalsIndex]
        );
        string escapedValue = typeof(this).trimText(
            text[1 + equalsIndex .. $]
        );
        if(escapedKey.length >= 2 &&
            escapedKey[0] == '"' && escapedKey[$ - 1] == '"' &&
            escapedKey[$ - 2] != '\\'
        ) {
            escapedKey = escapedKey[1 .. $ - 1];
        }
        if(escapedValue.length >= 2 &&
            escapedValue[0] == '"' && escapedValue[$ - 1] == '"' &&
            escapedValue[$ - 2] != '\\'
        ) {
            escapedValue = escapedValue[1 .. $ - 1];
        }
        const string key = cast(string) (
            unescapeCapsuleText(escapedKey).toArray()
        );
        const string value = cast(string) (
            unescapeCapsuleText(escapedValue).toArray()
        );
        if(!key.length) {
            this.addStatus(line.location, Status.NoPropertyNameError);
        }
        if(!this.ini.sections.length) {
            this.ini.globals.add(key, value);
        }
        else {
            this.ini.sections[$ - 1].add(key, value);
        }
    }
}

private version(unittest) static const IniTestContent1 = `
; line comment
x=1 ; X component
y=2 ; Y component
hello-world = ok then
[my-section]
abc xyz 123 = nil
value-continuation=hello \  ; line 1
world!                      ; line 2
key-\                       ; line 1
continuation=why\neven      ; line 2
[section-2]
[section-3]
ok=ok...
`;

private version(unittest) static const IniTestContent2 = `
src = hello/world.txt
src = abc/123.txt
name = alice
name = bob
name = charlie
[bump]
equals = \=
greetings = howdy
`;

private version(unittest) static const IniTestContent3 = `
src = hello/world.txt
src = abc/123.txt
name = adam
name = beatrice
name = clara
name = damien
[bump]
greetings = hiya
`;

/// Test the INI parser and related functionality
unittest {
    void eatLogMessage(in IniParser.Log.Message message) {}
    auto log = IniParser.Log(&eatLogMessage);
    auto parser = IniParser(&log, File("test.ini", IniTestContent1));
    parser.parse();
    assert(parser.ok);
    auto ini = parser.ini;
    assert(ini.globals.length == 3);
    assert(ini.sections.length == 3);
    assert(ini.globals["x"] == "1");
    assert(ini.globals["y"] == "2");
    assert(ini.globals["hello-world"] == "ok then");
    assert(ini["my-section"].length == 3);
    assert(ini["my-section"]["abc xyz 123"] == "nil");
    assert(ini["my-section"]["value-continuation"] == "hello world!");
    assert(ini["my-section"]["key-continuation"] == "why\neven");
    assert(ini["section-2"].length == 0);
    assert(ini["section-3"].length == 1);
    assert(ini["section-3"][0] == IniKeyValuePair("ok", "ok..."));
    assert(ini["section-3"]["ok"] == "ok...");
    assert("my-section" in ini);
    assert("no-such-section" !in ini);
    assert("x" in ini.globals);
    assert("z" !in ini.globals);
    assert(!ini["no-such-section"]);
    assert(!ini["my-section"]["no-such-key"]);
}

/// Test coverage for IniGroup functionality
unittest {
    void eatLogMessage(in IniParser.Log.Message message) {}
    auto log = IniParser.Log(&eatLogMessage);
    auto parser1 = IniParser(&log, File("test1.ini", IniTestContent2));
    auto parser2 = IniParser(&log, File("test2.ini", IniTestContent3));
    parser1.parse();
    assert(parser1.ok);
    parser2.parse();
    assert(parser2.ok);
    auto ini = IniGroup([parser1.ini, parser2.ini]);
    assert(ini.get("name") == "adam");
    assert(ini.all("name") == ["adam", "beatrice", "clara", "damien"]);
    assert(ini.aggregate("name") == [
        "alice", "bob", "charlie",
        "adam", "beatrice", "clara", "damien",
    ]);
    assert(ini.get("bump", "equals") == "=");
    assert(ini.get("bump", "greetings") == "hiya");
    assert(ini.all("bump", "equals") == ["="]);
    assert(ini.all("bump", "greetings") == ["hiya"]);
    assert(ini.aggregate("bump", "greetings") == ["howdy", "hiya"]);
}

/// Test coverage for INI serialization
unittest {
    void eatLogMessage(in IniParser.Log.Message message) {}
    auto log = IniParser.Log(&eatLogMessage);
    Ini ini;
    ini.set("hello", "world");
    ini.set("padded", "  text  ");
    ini.set("escaped", "=\t\0\\");
    ini.add("name", "ashley");
    ini.add("name", "bradley");
    ini.add("name", "corey");
    ini.set("my-section", "x", "+1");
    ini.set("my-section", "y", "0");
    ini.set("my-section", "z", "-1");
    assert(ini.get("hello") == "world");
    assert(ini.get("padded") == "  text  ");
    assert(ini.get("escaped") == "=\t\0\\");
    const string iniString = ini.toString();
    auto parser = IniParser(&log, File("test.ini", iniString));
    parser.parse();
    assert(parser.ok);
    assert(parser.ini.get("hello") == "world");
    assert(parser.ini.get("padded") == "  text  ");
    assert(parser.ini.get("escaped") == "=\t\0\\");
    assert(parser.ini.all("name") == ["ashley", "bradley", "corey"]);
    assert(parser.ini.get("my-section", "x") == "+1");
    assert(parser.ini.get("my-section", "y") == "0");
    assert(parser.ini.get("my-section", "z") == "-1");
}
