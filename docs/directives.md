# Capsule Assembler Directive Listing

Here is a list of all the directives recognized by the
Capsule assembler (casm).

A directive is a part of an assembly program that instructs the
compiler on how the instructions or other data should be
organized or placed in an object file and, ultimately, the
final executable program file.

## Key concepts

A **directive** is any lower-case identifier preceded by a single period character `.`, for example _.text_, and sometimes followed
by one or more comma-separated arguments.

A **section** is an abstract structure in which data or code
can be located. Different types of sections can be initialized
or uninitialized, executable or non-executable, read-only or read-write. Sections of a same type will ultimately be all
put together in a series in a segment of that type by the
linker program (clink).
The full list of directives which begin a new section are:
**bss**, **data**, **rodata**, and **text**.

A **symbol** is a name assigned by the programmer to some value
or some location in the program.
Symbols can be declared via labels (like `this:`), via _.const_
directives, or via _.extern_ directives.

To **declare** something is to tell the compiler that it
exists.
To **define** something is to do that, _and_ to tell the
compiler what exactly it is.

A **reference** is where a symbol name is given in order to
identify a value or address represented by that symbol, as
though the symbol is an alias for that value.

References have **reference types**, which tell the compiler or
linker information about how to resolve a referenced value.
Reference types can be given explicitly in brackets `like[this]`,
but most of the time the compiler will be smart enough to
know what reference type to use without being explicitly told.
References can also have an addend, which is a signed constant
literal value to be added to the value being referenced,
for example `my_symbol[+10]`.

A **literal** is an actual, definite, right-there-in-your-face,
literal value. Like a number, such as `1234`, or a string,
such as `"Hello, world!"`. A reference is _not_ a literal value.
This distinction is important for some directive types.

## .align

_.align [boundary], [fill]_

Data immediately after an **align** directive will be aligned to a
specified byte boundary, e.g. if _boundary_ is set to 4 then the
following data will be aligned to a word boundary.

When used in an initialized section, the _fill_ value indicates what
value bytes should be if bytes must be inserted in order to align the
following data on the correct boundary.

Sections are aligned to a word boundary by default, when they
contain no align directives.
A section with one or more align directives will be aligned
on a boundary that is the least common multiple of 4 and every
align directive's _boundary_ value.

Using the default configuration, the compiler will emit a fatal error
if the _boundary_ value is not a power of two, or if the least common
multiple of all the _boundary_ values in a section exceeds 256.

Both _boundary_ and _fill_ must be literal numeric values known
at compilation time. They cannot be references to symbols.

``` casm
.data
    .align 8 .word 0x12345678, 0xfedcba98
```

## .bss

_.bss_

The **bss** directive indicates the beginning of a new section
that should be placed in a program's bss segment.

The bss segment is uninitialized, not executable, and can
be both read from and written to.
It is primarily intended to be used for global variables that
do not need to be initialized before runtime.

All bytes within the bss segment hold a zero value when a program
begins. The **resb**, **resh**, and **resw** directives can
be used to reserve space in a bss section.

``` casm
.bss
    my_variable: .resw 1
    my_buffer: .resb 256
```

## .byte

_.byte [numbers...]_

The **byte** directive is used to insert 8-bit bytes of the given values
in an initialized section, such as a _data_ or _rodata_ section.

Using the directive in an uninitialized section such as a _bss_ section
is not allowed and will normally result in a compiler error.
Using it in an executable section such as a _text_ section will normally
result in a warning.

It expects one or more comma-separated number values as its arguments,
and those values can be either literals or references.

``` casm
.data
    my_bytes: .byte 1, 2, 3, my_constant
```

## .comment

_.comment [string]_

The **comment** directive can be used to set the comment string
that will be outputted with the created object file.
If there is more than one comment directive found while compiling
a single object file, then the object's comment will be the concatenation
of all comment strings, in the order they appeared.

An object's comment is not meaningful to the linker (clink).
It can contain whatever you want it to.

``` casm
.comment "Compiled by Bob Roberts (c) 2020"
```

## .const

_.const [name], [value]_

The **const** directive defines a new symbol with the given
name, with a literal numeric value specified.

The constant value can then be used where references are
recognized, such as in the immediate value for assembly
instructions, and the data placed in that space will correspond
to the value assigned to the constant symbol.

Symbols defined via the const directive can be exported using
an **export** directive or referenced in other modules using
an **extern** directive, just like any other symbol.

The const directive is not required to appear in any
particular section, and can be used even where no section has
been defined.

``` casm
.const one_hundred, 100

.text
    li A, one_hundred
```

## .data

_.data_

The **data** directive indicates the beginning of a new section
that should be placed in a program's data segment.

The data segment is initialized, not executable, and can
be both read from and written to.
It is primarily intended to be used for global variables that
ought to be initialized to some particular non-zero value before
runtime.

The **byte**, **half**, and **word** directives exist mainly to
be used to define variables in a _data_ or _rodata_ section.
Note also the **padb**, **padh**, **padw**, **string**,
and **stringz** instructions.

``` casm
.data
    my_variable: .word 0x12345678
    my_bytes: .padb 128, 0xff
    my_string: .stringz "Hello, world!"
```

## .endproc

_.endproc [name]_

The **endproc** directive is used in combination with the **procedure**
directive to mark some span of code as belonging to a single procedure.

A procedure can be defined as the code spanning from an entry point used
as the target for a _jalr_ instruction to the last instance of a _jalr_
instruction at that destination which returns execution to immediately
after that entering _jalr_.

Marking this information about the location and length of a procedure is
not mandatory, but it may be exposed in useful ways by debugging tools.

``` casm
; This procedure squares the value stored in register A
.text .procedure square:
    ; Multiply A * A and store the result in register A
    mul A, A, A
    ; Exit the procedure and return execution control to the caller
    ; `ret` is a psuedo-instruction; this emits `jalr Z, R`
    ret R
.endproc square
```

## .entry

_.entry_

The **entry** directive defines where the entry point for a program
should be placed, i.e. at what address program execution should begin.

There should be exactly one entry directive in all object files being
linked to create an executable program file.
If there are no entry directives or more than one entry directive across
linked objects, this will normally result in an error or warning.

``` casm
.text .entry
    la A, hello_world_stringz
    call R, write_stringz
    ecalli Z, Z, meta.exit_ok
```

## .export

_.export [name]_

The **export** directive indicates that a symbol defined in
this module should be visible to other modules when linking.
Other modules can reference the defined symbol with an
**extern** declaration.

``` casm
; Make my_important_global visible to other linked modules
.export my_important_global

.data
    ; Define my_important_global with a value of 0x12345678
    my_important_global: .word 0x12345678
```

``` casm
; Indicate that my_important_global is defined in another module
.extern my_important_global

.text
    ; Load the address of the important global into X
    la X, my_important_global
    ; Load 0x12345678, the value of the important global, into A
    lw A, X, 0
```

## .extern

_.extern [name]_

The **extern** directive declares a symbol without defining it,
indicating to the compiler and linker that a module needs to be linked
with one which does define and **export** a symbol with that name.

``` casm
; Make my_important_global visible to other linked modules
.export my_important_global

.data
    ; Define my_important_global with a value of 0x12345678
    my_important_global: .word 0x12345678
```

``` casm
; Indicate that my_important_global is defined in another module
.extern my_important_global

.text
    ; Load the address of the important global into X
    la X, my_important_global
    ; Load 0x12345678, the value of the important global, into A
    lw A, X, 0
```

## .half

_.half [numbers...]_

The **half** directive is used to insert 16-bit half-words of the given
values in an initialized section, such as a _data_ or _rodata_ section.

Using the directive in an uninitialized section such as a _bss_ section
is not allowed and will normally result in a compiler error.
Using it in an executable section such as a _text_ section will normally
result in a warning.

It expects one or more comma-separated number values as its arguments,
and those values can be either literals or references.

``` casm
.data
    my_words: .half 1, 2, 3, 100_000, my_constant
```

## .padb

_.padb [count]_

Reserves a given number of 8-bit bytes at the current
location in memory, all initialized to a given literal number value.
This directive is primarily intended to be used within a _data_
or _rodata_ section.

Using the padb directive in an uninitialized section,
such as a _bss_ section, will normally result in a compiler error.
Using it in an executable section, such as the _text_ section,
will normally result in a warning.

``` casm
.data
    my_bytes: .padb 16, 0xff
    my_half_words: .padh 8, 0x1234
    my_words: .padw 4, 0xff00ff00
```

## .padh

_.padh [count]_

Reserves a given number of 16-bit half words at the current
location in memory, all initialized to a given literal number value.
This directive is primarily intended to be used within a _data_
or _rodata_ section.

Using the padh directive in an uninitialized section,
such as a _bss_ section, will normally result in a compiler error.
Using it in an executable section, such as the _text_ section,
will normally result in a warning.

``` casm
.data
    my_bytes: .padb 16, 0xff
    my_half_words: .padh 8, 0x1234
    my_words: .padw 4, 0xff00ff00
```

## .padw

_.padw [count]_

Reserves a given number of 32-bit words at the current
location in memory, all initialized to a given literal number value.
This directive is primarily intended to be used within a _data_
or _rodata_ section.

Using the padw directive in an uninitialized section,
such as a _bss_ section, will normally result in a compiler error.
Using it in an executable section, such as the _text_ section,
will normally result in a warning.

``` casm
.data
    my_bytes: .padb 16, 0xff
    my_half_words: .padh 8, 0x1234
    my_words: .padw 4, 0xff00ff00
```
## .priority

_.priority [priority]_

The **priority** directive sets the priority value of the section it's
used in. The priority value should be a signed integer literal.

Sections within the same segment but with different priorities assigned
to them will be ordered from lowest to highest priority value, i.e.
a section with _.priority -5_ will appear before a section with a default
priority of zero, which will appear before a section with _.priority +5_.

Normally, putting multiple priority directives in the same section will
result in the compiler emitting a warning.

``` casm
.bss
    .priority -1
    .string "Second section in memory"

.bss
    .priority -2
    .string "First section in memory"

.bss
    .priority +3
    .string "Last section in memory"
```

## .procedure

_.procedure_

The **procedure** directive is used to mark a label as indicating the
entry point to a procedure or function.
In general, every procedure direction should have a corresponding
**endproc** directive to indicate the end of the code making up a
procedure.

A procedure can be defined as the code spanning from an entry point used
as the target for a _jalr_ instruction to the last instance of a _jalr_
instruction at that destination which returns execution to immediately
after that entering _jalr_.

Marking this information about the location and length of a procedure is
not mandatory, but it may be exposed in useful ways by debugging tools.

``` casm
; This procedure squares the value stored in register A
.text .procedure square:
    ; Multiply A * A and store the result in register A
    mul A, A, A
    ; Exit the procedure and return execution control to the caller
    ; `ret` is a psuedo-instruction; this emits `jalr Z, R`
    ret R
.endproc square
```

## .resb

_.resb [count]_

Reserves a given number of zero-initialized 8-bit bytes at the
current location in memory.
This directive is primarily intended to be used within a _bss_
section.

``` casm
.bss
    my_bytes: .resb 16
    my_half_words: .resh 8
    my_words: .resw 4
```

## .resh

_.resh [count]_

Reserves a given number of zero-initialized 16-bit half words at the
current location in memory.
This directive is primarily intended to be used within a _bss_
section.

``` casm
.bss
    my_bytes: .resb 16
    my_half_words: .resh 8
    my_words: .resw 4
```

## .resw

_.resw [count]_

Reserves a given number of zero-initialized 32-bit words at the
current location in memory.
This directive is primarily intended to be used within a _bss_
section.

``` casm
.bss
    my_bytes: .resb 16
    my_half_words: .resh 8
    my_words: .resw 4
```

## .rodata

_.rodata_

The **rodata** directive indicates the beginning of a new section
that should be placed in a program's read-only data segment.

The read-only data segment is initialized, not executable, and can
be read from but not written to.
It is primarily intended to be used to store global constant values.

The **byte**, **half**, and **word** directives exist mainly to
be used to define variables in a _data_ or _rodata_ section.
Note also the **padb**, **padh**, **padw**, **string**,
and **stringz** instructions.

``` casm
.rodata
    my_read_only_word: .word 0x12345678
    my_read_only_bytes: .padb 128, 0xff
    my_read_only_string: .stringz "Hello, world!"
```

## .string

_.string [text]_

The **string** directive is used to insert string at
the current location in memory.
It should normally be used in a _data_ or _rodata_ section.

``` casm
.rodata
    hello_world_str: .string "Hello, world!\n"
```

## .stringz

_.stringz [text]_

The **stringz** directive is used to insert a null-terminated string at
the current location in memory, meaning a string that has a zero byte
appended to its end.
It should normally be used in a _data_ or _rodata_ section.

``` casm
.rodata
    hello_world_strz: .stringz "Hello, world!"
```

## .text

_.text_

The **text** directive indicates the beginning of a new section
that should be placed in a program's text segment.

The text segment is initialized, is executable, and can
be read from but not written to.
In general, executable code belongs in text sections.

``` casm
.text
    add A, B, C
```

## .word

_.word [numbers...]_

The **word** directive is used to insert 32-bit words of the given values
in an initialized section, such as a _data_ or _rodata_ section.

Using the directive in an uninitialized section such as a _bss_ section
is not allowed and will normally result in a compiler error.
Using it in an executable section such as a _text_ section will normally
result in a warning.

It expects one or more comma-separated number values as its arguments,
and those values can be either literals or references.

``` casm
.data
    my_words: .word 1, 2, 3, 100_000, my_constant
```
