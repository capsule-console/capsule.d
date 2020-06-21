/**

This module implements a message logging interface that can be used
to log and display messages emitted by some application.

*/

module capsule.io.messages;

private:

import capsule.algorithm.sort : sort;
import capsule.io.file : FileLocation;
import capsule.meta.enums : getEnumMemberName, getEnumMemberAttribute;
import capsule.range.concat : concat;
import capsule.range.join : join;
import capsule.range.map : map;
import capsule.range.range : toArray;
import capsule.string.writeint : writeInt;

public:

enum CapsuleMessageSeverity: uint {
    None = 0,
    Debug = 1,
    Info = 2,
    Warning = 3,
    Error = 4,
}

static const CapsuleMessageSeverityChars = [
    'X',
    'D',
    'I',
    'W',
    'E',
];

static const CapsuleMessageSeverityNames = [
    "",
    "Debug",
    "Info",
    "Warning",
    "Error",
];

CapsuleMessageSeverity getCapsuleMessageSeverityByChar(
    in char ch
) nothrow @safe @nogc {
    foreach(i, severityChar; CapsuleMessageSeverityChars) {
        if(ch == severityChar) {
            return cast(CapsuleMessageSeverity) i;
        }
    }
    return CapsuleMessageSeverity.None;
}

static const string CapsuleMessageUnknownString = (
    "Message status not valid."
);

struct CapsuleMessage(T) {
    nothrow @safe:
    
    alias Status = T;
    
    alias Severity = CapsuleMessageSeverity;
    alias SeverityNames = CapsuleMessageSeverityNames;
    alias UnknownString = CapsuleMessageUnknownString;
    
    size_t id;
    FileLocation location;
    Severity severity;
    Status status;
    string context = null;
    
    string getSeverityName() @nogc const {
        assert(cast(size_t) this.severity < SeverityNames.length);
        const index = cast(size_t) this.severity;
        return index < SeverityNames.length ? SeverityNames[index] : null;
    }
    
    string getMessageString() @nogc const {
        const attrString = getEnumMemberAttribute!string(this.status);
        if(attrString.length) {
            return attrString;
        }
        const nameString = getEnumMemberName(this.status);
        if(nameString.length) {
            return nameString;
        }
        return UnknownString;
    }
    
    string toString() const @trusted {
        const locationLineColString = !this.location.lineNumber ? "" : ("L" ~
            cast(string) writeInt(this.location.lineNumber).toArray() ~ ":" ~
            cast(string) writeInt(this.location.column).toArray()
        );
        const locationString = (!this.location ? "" : (
            this.location.file.path ~
            (this.location.lineNumber && this.location.file.path ? " " : "") ~
            locationLineColString
        ));
        if(this.context.length && !this.status && !this.severity) return (
            locationString ~
            (locationString.length ? " " : "") ~
            this.context
        );
        const severityName = this.getSeverityName();
        const contextString = (
            this.context && this.context.length ? " (" ~ this.context ~ ")" : ""
        );
        return (
            locationString ~
            (locationString.length && severityName.length ? " " : "") ~
            severityName ~
            (locationString.length || severityName.length ? ": " : "") ~
            this.getMessageString() ~
            contextString
        );
    }
    
    int opCmp(in CapsuleMessage other) @nogc const {
        if(this.severity > other.severity) {
            return -1;
        }
        else if(this.severity < other.severity) {
            return +1;
        }
        else if(this.location.startIndex < other.location.startIndex) {
            return -1;
        }
        else if(this.location.startIndex > other.location.startIndex) {
            return +1;
        }
        else if(this.id < other.id) {
            return -1;
        }
        else if(this.id > other.id) {
            return +1;
        }
        else {
            return 0;
        }
    }
}

struct CapsuleMessageLog(T) {
    alias Status = T;
    
    alias Message = CapsuleMessage!Status;
    alias Severity = CapsuleMessageSeverity;
    
    alias AddMessageCallback = void delegate(in Message message);
    
    AddMessageCallback onAddMessage = null;
    size_t nextMessageId = 0;
    Severity maxSeverity = Severity.None;
    size_t addMessageCount = 0;
    
    this(AddMessageCallback onAddMessage) {
        this.onAddMessage = onAddMessage;
    }
    
    bool empty() const nothrow @nogc @safe {
        return this.addMessageCount == 0;
    }
    
    size_t length() const nothrow @nogc @safe {
        return this.addMessageCount;
    }
    
    bool anyErrors() const nothrow @nogc @safe {
        return this.maxSeverity >= Severity.Error;
    }
    
    bool anyWarnings() const nothrow @nogc @safe {
        return this.maxSeverity >= Severity.Warning;
    }
    
    Message add(
        in Severity severity, in Status status, in string context = null
    ) {
        return this.add(FileLocation.init, severity, status, context);
    }
    
    Message addString(in string message) {
        return this.add(Severity.None, cast(Status) 0, message);
    }
    
    Message addDebug(in Status status, in string context = null) {
        return this.add(Severity.Debug, status, context);
    }
    
    Message addInfo(in Status status, in string context = null) {
        return this.add(Severity.Info, status, context);
    }
    
    Message addWarning(in Status status, in string context = null) {
        return this.add(Severity.Warning, status, context);
    }
    
    Message addError(in Status status, in string context = null) {
        return this.add(Severity.Error, status, context);
    }
    
    Message add(
        in FileLocation location, in Severity severity,
        in Status status, in string context = null
    ) {
        const id = this.nextMessageId++;
        const message = Message(id, location, severity, status, context);
        this.maxSeverity = (
            severity > this.maxSeverity ? severity : this.maxSeverity
        );
        if(this.onAddMessage) {
            this.onAddMessage(message);
        }
        return message;
    }
    
    Message addDebug(
        in FileLocation location, in Status status, in string context = null
    ) {
        return this.add(location, Severity.Debug, status, context);
    }
    
    Message addInfo(
        in FileLocation location, in Status status, in string context = null
    ) {
        return this.add(location, Severity.Info, status, context);
    }
    
    Message addWarning(
        in FileLocation location, in Status status, in string context = null
    ) {
        return this.add(location, Severity.Warning, status, context);
    }
    
    Message addError(
        in FileLocation location, in Status status, in string context = null
    ) {
        return this.add(location, Severity.Error, status, context);
    }
}
