module capsule.apps.lib.modulesettings;

private:

import capsule.algorithm.indexof : indexOf;
import capsule.encode.ini : Ini;
import capsule.math.vector : Vector;
import capsule.string.ascii : trimWhitespace;
import capsule.string.boolean : parseBooleanValue;
import capsule.string.parseint : parseInt;

public:

/// Helper to parse a string representing a vector.
private T parseVector(T: Vector!(size, X), size_t size, X)(in string text) {
    static assert(size > 1, "Degenerate vector case.");
    static enum string recognizedSeparators = ",:x";
    char sep = 0;
    ptrdiff_t lastSepIndex = 0;
    ptrdiff_t nextSepIndex = -1;
    foreach(recognizedSep; recognizedSeparators) {
        sep = recognizedSep;
        nextSepIndex = indexOf(text, recognizedSep);
        if(nextSepIndex >= 0) {
            break;
        }
    }
    if(!sep || nextSepIndex < 0) {
        return T.init;
    }
    T vector = T.init;
    size_t vectorIndex = 0;
    while(nextSepIndex > lastSepIndex && vectorIndex < vector.length) {
        const valueText = trimWhitespace(text[lastSepIndex + 1 .. nextSepIndex]);
        if(valueText.length) {
            const value = parseInt!X(valueText);
            if(value.ok) {
                vector.set(vectorIndex, value.value);
            }
        }
        lastSepIndex = nextSepIndex;
        nextSepIndex = (
            1 + lastSepIndex + indexOf(text[1 + lastSepIndex .. $], sep)
        );
        if(nextSepIndex < 0) {
            nextSepIndex = text.length;
        }
        vectorIndex++;
    }
    return vector;
}

/// Helper type to make reading properties from a Capsule console settings
/// INI file more syntactically convenient and concise.
struct CapsuleModulePropertySettings {
    nothrow @safe:
    
    /// Expect properties to appear in this INI section.
    string name;
    /// INI files to look for settings properties in.
    Ini.Group ini;
    
    /// Get and parse a boolean property value.
    T get(T: bool)(in string property) const @nogc {
        return 0 < parseBooleanValue(this.ini.get(name, property));
    }
    
    /// Get a string property value.
    T get(T: string)(in string property) const @nogc {
        return this.ini.get(name, property);
    }
    
    /// Get and parse a vector property value, e.g. "0, 0, 0" or "256x256"
    T get(T: Vector!(size, X), size_t size, X)(in string property) const @nogc {
        return parseVector!T(this.ini.get(name, property));
    }
}
