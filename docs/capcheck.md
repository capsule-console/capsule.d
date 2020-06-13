# Capsule Implementation Check Documentation

The Capsule implementation checker (capcheck) is a utility for running
a suite of tests against a Capsule toolchain and virtual machine,
compiling and linking test programs from their sources and verifying
their behavior when run via the Capsule virtual machine.

The **capcheck** utility is intended to be used on the command line.
It can be run without arguments or with the `--help` argument to
explain how it is used.

## Command line usage

The first command-line argument must be the path to a capcheck configuration
INI file, such as the one located in
[tests/index.ini](https://github.com/capsule-console/capsule.d/blob/master/tests/index.ini)
in this repository.

The following options and flags can also be configured in the INI file.
When an option appears in both the command line arguments and in the INI
configuration file, the setting given in the command line arguments will
take precedence.

Flag options such as `--debug` or `--silent` or `--verbose`
can either appear on their own, in which case the flag will
be set to a true state, or one of a set of certain strings can appear
after it.
`0`, `f`, or `false` indicate the flag should be set to false and
`1`, `t`, or `true` indicate the flag should be set to true.

### Output directory (--output, -o)

The `--output` or `-o` option is used to specify a directory that object
files, program files, and other outputted files should be written to.

``` text
> capcheck tests/index.ini --output tests/bin
```

### Debug information flag (--debug, -db)

When present, the `--debug` or `-db` flag causes the object and program files
outputted during the implementation check to include debugging information
such as symbol definitions and source maps.

``` text
> capcheck tests/index.ini --debug
```

### Capsule assembler path (--casm)

The `--casm` option tells capcheck where to find the Capsule assembler
executable.
This is the program it will use to compile assembly sources during
the implementation check.

``` text
> capcheck tests/index.ini --casm bin/casm.exe
```

### Capsule linker path (--clink)

The `--clink` option tells capcheck where to find the Capsule linker
executable.
This is the program it will use to link compiled Capsule object files
during the implementation check.

``` text
> capcheck tests/index.ini --clink bin/clink.exe
```

### Capsule virutal machine path (--capsule)

The `--capsule` option tells capcheck where to find the Capsule
virtual machine executable.
This is the program it will use to load and run compiled Capsule
program files during the implementation check.

``` text
> capcheck tests/index.ini --capsule bin/capsule.exe
```

### Only run matching tests (--only)

The `--only` option can be used to ignore all test cases other than
those tests whose name matches one of the strings passed via the option.

``` text
> capcheck tests/index.ini --only hello-world collatz op-lui
```

### Verbose flag (--verbose, -v)

When present, the `--verbose` or `-v` flag results in capcheck
writing more messages to the log than usual.
This flag may be useful for debugging issues with failing tests.

``` text
> capcheck tests/index.ini --verbose
```

### Very verbose flag (--very-verbose, -vv)

When present, the `--very-verbose` or `-vv` flag results in capcheck
writing drastically more messages to the log than usual, including
the fully verbose log output of every invocation of the assembler
or linker.
This flag may be useful for debugging issues with failing tests.

``` text
> capcheck tests/index.ini --very-verbose
```

### Run silently flag (--silent)

When present, the `--silent` flag prevents capcheck from writing
any messages to stdout at all.
This flag can be used when the only thing that matters for a given
situation is the program's exit status, which will be zero if all
tests passed and nonzero if there was any failure.

``` text
> capcheck tests/index.ini --silent
```

### Show help text (--help)

When given as the very first argument, the `--help` flag results in
capcheck displaying usage documentation, instead of running tests.

``` text
> capcheck --help
```

### Show software version (--version)

When given as the very first argument, the `--version` flag results in
capcheck displaying version information, instead of running tests.

``` text
> capcheck --version
```

## INI Configuration File Usage

The capcheck program relies on loading a configuration file that
is provided in [INI](https://en.wikipedia.org/wiki/INI_file) format.

Capsule's INI parser recognizes comments starting with a semicolon `;`.
It permits duplicate section names and it permits duplicate property names,
even within the same section.
It expects section names to be enclosed within brackets, e.g. `[section]`.
It recognizes line continuations (a line ending in a backslash `\`) and
a number of escape sequences (e.g. `\"`, `\n`, `\x01`).
It trims whitespace from either end of both property names and values,
and it recognizes only an equal sign `=` for separating a name and value.

A default value for any option accepted on the command line
can be provided in the INI file's initial global scope.
If a different value is given on the command line for any option
which the INI configuration file defines, then the command line
option will take precedence over what's given in the INI.

### Global properties

Global properties can be used to set defaults for options that would
otherwise be passed via the command line.

- **output**: See `--output` CLI option.
- **debug**: See `--debug` CLI option.
- **casm**: See `--casm` CLI option.
- **clink**: See `--clink` CLI option.
- **capsule**: See `--capsule` CLI option.
- **only**: See `--only` CLI option.
- **verbose**: See `--verbose` CLI option.
- **very-verbose**: See `--very-verbose` CLI option.
- **silent**: See `--silent` CLI option.

Properties representing a single string value are fairly straightforward:

``` ini
output=bin/
```

Properties with multiple recognized values should be indicated by
adding multiple properties with the same name.
The values given for the same-named properties will be combined
into a list.

``` ini
only=first-test
only=second-test
only=third-test
```

Properties representing flags, i.e. boolean options, should have a
value of `0`, `f`, or `false` for a false value and a
value of `1`, `t`, or `true` for a true value.

``` ini
verbose=true
silent=false
```

### Section properties

A test case is identified by the name of the section that defines it.

Here is a brief list of the properties that are recognized when they
appear in a section in the capcheck INI configuration file:

- **caseof**: Reuse a build needed by multiple test cases
- **stdin**: Run with some stdin
- **stdout**: Expected stdout
- **status**: Expected program exit status
- **comment**: Program file comment
- **source**: Path to a source code file
- **casm-args**: Extra **casm** arguments
- **clink-args**: Extra **clink** arguments
- **capsule-args**: Extra **capsule** arguments

#### caseof

The **caseof** property is intended for when the same program should be
built once but run and tested multiple times with different inputs.

The checking tool ignores build-related properties such as _comment_,
_source_, _casm-args_, or _clink-args_ in section with a _caseof_ property.
Instead, the program built by the case named by the _caseof_ property
will be run based on any input or expected output information given
in the test case section.

Note that any test section with one or more _caseof_ references pointing
to it will be treated only as a build configuration, and test case
properties such as _stdin_, _stdout_, or _capsule-args_ will be ignored
there.

``` ini
[build-info]
comment=Example build info for a program reused by multiple test cases
source=source/code.casm
source=lib/some-dependency.casm
[build-info.abc]
caseof=build-info
stdin=abc
stdout=123
[build-info.def]
caseof=build-info
stdin=def
stdout=546
[build-info.ghi]
caseof=build-info
stdin=ghi
stdout=789
```

#### stdin

The **stdin** property is recognized for each execution of a test program.
It causes the program to be run with the given data passed via standard input,
i.e. the data retrieved by _stdio.get_byte_ extension calls.

#### stdout

The **stdout** property is recognized for each execution of a test program.
It indicates what the program is expected to write to standard output
during execution.
If what is actually written does not match the data indicated by a test's
_stdout_ property, then capcheck considers the test to be a failure.

#### status

The **status** property is recognized for each execution of a test program.
It indicates what exit status code the program is expected to terminate with.
When the _status_ attribute is not explicitly specified, the program is
expected to exit with the **Ok** status, i.e. to run without errors.

The list of meaningful program exit status names is:

- **Ok**: Program execution completed without errors.
- **ExecutionExitError**: Program signaled an abnormal exit.
- **ExecutionError**: An unusual error occurred while running the program.
- **ExecutionAborted**: Program aborted because of an unhandled exception.
- **ExecutionTerminated**: Program responded to an external signal to quit execution.

#### comment

The **comment** property is recognized when building a test program.
It is used to set the program file's comment text, which has no effect
in the toolchain or virtual machine but may be used as documentation or
to provide information to other tools.

#### source

The **source** property is recognized when building a test program.
It indicates the path to one source file that should be included in
the compilation and linking process.
If there are multiple sources that need to be compiled and linked in
order to build a test program, then these should be indicated by using
multiple _source_ properties, one for each necessary path.

``` ini
[op-max]
comment=Verify the behavior of the "max" instruction
source=op-max.casm
source=lib/write-int.casm
stdout=0 1 -1 1 1 2147483647 0 2147483647 256
status=Ok
```

#### casm-args

The **casm-args** property is recognized when building a test program.
It can be used to specify additional arguments that should be passed
on the command line when running the Capsule assembler (casm)
.

#### clink-args

The **clink-args** property is recognized when building a test program.
It can be used to specify additional arguments that should be passed
on the command line when running the Capsule linker (clink).

#### capsule-args

The **capsule-args** property is recognized for each execution of a test program.
It can be used to specify additional arguments that should be passed
on the command line when running the Capsule virtual machine (capsule).

## Example INI Configuration File

Here is a simplified example showing what a capcheck INI configuration
file might look like:

``` ini
casm=casm
clink=clink
capsule=capsule
output=bin/

[hello-world]
comment=A simple and self-contained "Hello, world!" example program.
source=hello-world.casm
stdout=Hello, world!
status=Ok

[op-and]
comment=Verify the behavior of the "and" instruction
source=op-and.casm
source=lib/write-hex.casm
stdout=0 1 0 0 ffffffff 10010010
status=Ok

[collatz]
comment=Verify the behavior of a Collatz sequence test program.
source=collatz.casm
source=lib/read-int.casm
source=lib/write-int.casm
source=lib/write-stringz.casm
[collatz.512]
caseof=collatz
stdin=512
stdout=512 256 128 64 32 16 8 4 2 1
status=Ok
[collatz.19]
caseof=collatz
stdin=19
stdout=19 58 29 88 44 22 11 34 17 52 26 13 40 20 10 5 16 8 4 2 1
status=Ok
[collatz.1]
caseof=collatz
stdin=1
stdout=1
status=Ok
```


