/**

This module provides functions for parsing and handling INI files.

*/

module capsule.parse.ini;

private:

import capsule.io.file : File, FileLocation, FileReader;
import capsule.io.messages : CapsuleMessageLog, CapsuleMessageSeverity;
import capsule.io.messages : getCapsuleMessageSeverityByChar;
import capsule.meta.enums : getEnumMemberAttribute;
import capsule.range.range : toArray;
import capsule.string.escape : unescapeCapsuleText;

private alias Status = IniMessageStatus;

public:

alias CapsuleIniMessageLog = CapsuleMessageLog!IniMessageStatus;

bool isIniInlineWhitespace(in char ch) {
    return ch == ' ' || ch == '\t';
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
    @('E', "Section has no name.")
    NoSectionNameError,
}

/// Represents a key, value pair in an INI file
struct IniKeyValuePair {
    string key;
    string value;
}

/// Represents information parsed from an INI file
struct Ini {
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
    
    bool set(in string sectionName, in string key, in string value) {
        if(!sectionName || !sectionName.length) {
            this.globals[key] = value;
            return true;
        }
        foreach(ref section; this.sections) {
            if(section.name == sectionName) {
                section[key] = value;
                return true;
            }
        }
        return false;
    }
    
    string get(in string key) const @nogc {
        return this.get(null, key);
    }
    
    bool set(in string key, in string value) {
        return this.set(null, key, value);
    }
    
    auto opBinaryRight(string op: "in")(in string sectionName) const @trusted @nogc {
        foreach(ref section; this.sections) {
            if(section.name == sectionName) {
                return &section;
            }
        }
        return null;
    }
    
    auto opIndex(in string sectionName) @nogc {
        foreach(ref section; this.sections) {
            if(section.name == sectionName) {
                return section;
            }
        }
        return Section.init;
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
        string[] values;
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
    void append(in string key, in string value) {
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
    Log log;
    
    static string trimText(in string text) {
        size_t start = 0;
        size_t end = text.length;
        while(start < end && isIniInlineWhitespace(text[start])) start++;
        while(start < end && isIniInlineWhitespace(text[end - 1])) end--;
        return text[start .. end];
    }
    
    static string trimTextEnd(in string text) {
        size_t end = text.length;
        while(end > 0 && isIniInlineWhitespace(text[end - 1])) end--;
        return text[0 .. end];
    }
    
    this(File file) {
        this.reader = file.reader;
    }
    
    this(FileReader reader) {
        this.reader = reader;
    }
    
    bool ok() const {
        return !this.log.anyErrors;
    }
    
    void addStatus(in FileLocation location, in Status status, in string context = null) {
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
        while(!this.reader.empty && this.reader.front != '\n') {
            this.reader.popFront();
        }
        const size_t endIndex = this.reader.index;
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
        const size_t lineEnd = (
            commentStart >= 0 ? cast(size_t) commentStart : line.length
        );
        const lineText = typeof(this).trimTextEnd(line[0 .. lineEnd]);
        return Line(lineLocation, lineText, equalsIndex);
    }
    
    void parseLine(in Line line) @trusted {
        if(!line.text.length) {
            return;
        }
        string text = line.text;
        ptrdiff_t equalsIndex = line.equalsIndex;
        while(text[$ - 1] == '\\') {
            if(this.reader.empty) {
                this.addStatus(this.reader.location, Status.InvalidLineContinuationError);
                return;
            }
            const next = this.getNextLine();
            if(equalsIndex < 0 && next.equalsIndex > 0) {
                equalsIndex = cast(ptrdiff_t) text.length + next.equalsIndex - 1;
            }
            text = text[0 .. $ - 1] ~ next.text;
        }
        if(text[0] == '[' && text[$ - 1] == ']') {
            if(text.length <= 2) {
                this.addStatus(this.reader.location, Status.NoSectionNameError);
                return;
            }
            this.ini.addSection(text[1 .. $ - 1]);
            return;
        }
        if(equalsIndex < 0) {
            this.addStatus(line.location, Status.InvalidSyntax);
            return;
        }
        const string escapedKey = typeof(this).trimText(
            text[0 .. equalsIndex]
        );
        const string escapedValue = typeof(this).trimText(
            text[1 + equalsIndex .. $]
        );
        const string key = cast(string) (
            unescapeCapsuleText(escapedKey).toArray()
        );
        const string value = cast(string) (
            unescapeCapsuleText(escapedValue).toArray()
        );
        if(!this.ini.sections.length) {
            this.ini.globals.append(key, value);
        }
        else {
            this.ini.sections[$ - 1].append(key, value);
        }
    }
}

private version(unittest) static const IniTestContent = `
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
import capsule.io.stdio;
/// Test the INI parser and related functionality
unittest {
    auto parser = IniParser(File("test.ini", IniTestContent));
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
