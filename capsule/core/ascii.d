module capsule.core.ascii;

public pure nothrow @safe @nogc:

bool isDigit(in char ch) {
    return ch >= '0' && ch <= '9';
}

bool isWhitespace(in char ch) {
    return (
        ch == ' ' || ch == '\t' || ch == '\r' ||
        ch == '\n' || ch == '\v' || ch == '\f'
    );
}

bool isInlineWhitespace(in char ch) {
    return ch == ' ' || ch == '\t';
}

/// Determine whether an ASCII character is a upper-case letter.
bool isUpper(in char ch) {
    return ch >= 'A' && ch <= 'Z';
}

/// Determine whether an ASCII character is a lower-case letter.
bool isLower(in char ch) {
    return ch >= 'a' && ch <= 'z';
}

/// Convert an ASCII character to upper case.
/// Returns the input itself when the input is not a lower-case letter.
char toUpper(in char ch) {
    return cast(char)(ch.isLower ? ch - 0x20 : ch);
}

/// Convert an ASCII character to lower case.
/// Returns the input itself when the input is not an upper-case letter.
char toLower(in char ch) {
    return cast(char)(ch.isUpper ? ch + 0x20 : ch);
}

/// Special case insensitive string comparison
/// jalr == jalr
/// jalr == JALR
/// jalr != Jalr
bool eitherCaseStringEquals(T)(in T[] eitherCase, in T[] lowerCase) {
    if(lowerCase.length != eitherCase.length) {
        return false;
    }
    bool lower = true;
    bool upper = true;
    for(size_t i = 0; i < lowerCase.length && (lower || upper); i++) {
        if(lowerCase[i] != eitherCase[i]) {
            lower = false;
        }
        if(toUpper(lowerCase[i]) != eitherCase[i]) {
            upper = false;
        }
    }
    return lower || upper;
}
