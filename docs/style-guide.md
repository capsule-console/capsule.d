# Capsule Implementation Style Guide

Code is indented with four spaces.

Constants, types, and enum members are named by PascalCase identifiers. Functions, variables, and everything else are named by camelCase identifiers.

Function, struct, class, enum, and other normally multi-line declarations should normally be separated by a single blank newline.

``` d
enum MyEnum: uint {
    Zero = 0,
    One,
    Two,
    Three,
}

struct MyType {
    static enum MyConstant = 0;
    int myAttribute;
}

void myFirstFunction() {
    int myVariable = 0;
    return doStuff(myVariable);
}

void mySecondFunction() {
    return doOtherStuff();
}
```

Consider 80 characters to be a soft line length limit.

The opening brace `{` belongs on the same line as the keyword or closing parenthese `)`.

There should be one space in between a closing parenthese `)` and a corresponding open brace `{`.

There should not be any whitespace in between a keyword or identifier and an open parenthese `(`.

Closing braces `}` generally belong on their own line.

Opening braces `{` generally should be the last character on a line.

Prefer enclosing statements such as loop or `if` bodies within braces `{}`.

Avoid putting more than one statement on the same line.

``` d
void myFunction() {
    if(myCondition) {
        indentedFunctionBody();
    }
    else {
        doSomeOtherStuff();
    }
}
```

Lists of things or conditions for control flow statements enclosed within brackets `[]` or parentheses `()` and spread across multiple lines should follow the same indentation rules as curly braces `{}`.

Multi-line lists of things, whether arrays or arguments, should generally have trailing commas.

``` d
const string[] myList = [
    "Hello",
    "World",
    "!!!",
];
```

``` d
void myFunction() {
    if(
        myFirstCondition.isMet() &&
        mySecondCondition.isMet() && (
            myThirdCondition.isCompatible() ||
            myFourthCondition.isCompatible()
        )
    ) {
        doSomething();
    }
}
```

Infix operators are padded with whitespace.

Always use parentheses to clarify the intended order of operations when mixing multiple operators in the same statement.

``` d
int x = a + b;
int y = x + y + z;
int i = j + (k * 2);
```

Prefer placing comments on their own line, rather than on the same line as code.

``` d
/// My documenting comment
void myDocumentedFunction() {
    // Do something
    return doTheThing();
}
```

When importing other modules, always be explicit about what symbols are being used. Avoid using import statements that are not followed by a list of identifiers.

``` d
import capsule.core.ascii : isDigit, isUpper;
```

Prefer structs to classes.

Exercise restraint in regards to operator overloads.

Avoid using the `@property` function decorator.
It should always be clear when an assignment is modifying a single particular instance attribute versus when it is doing something more complex.

Avoid using `alias this`.

Avoid using the `opDispatch` operator overload.
