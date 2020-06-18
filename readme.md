# Capsule

Capsule is a virtual console, or [fantasy console](https://www.pixelbath.com/2020/02/fantasy-consoles/), that is currently in an **alpha development stage**.

Please be aware that, in this early alpha stage, **major changes may yet be made**
to the standard toolchain or to the bytecode specification without regard for
backwards-compatibility.

This repository and its contents are licensed according to the
[GNU Affero General Public License v3.0](https://github.com/capsule-console/capsule.d/blob/master/LICENSE),
a ["copyleft"](https://en.wikipedia.org/wiki/Copyleft) software license.

This repository contains an assembler, linker, and virtual machine for compiling and running Capsule bytecode, all written in the [D programming language](https://dlang.org/).

## Documentation

This project's documentation is located in the
[docs/](https://github.com/capsule-console/capsule.d/blob/master/docs)
directory.

The docs directory contains a
[**Capsule Documentation Index**](https://github.com/capsule-console/capsule.d/blob/master/docs/index.md)
listing and explaining the contents of each documentation file.

## Quick Introduction

The Capsule instruction set is similar to [RISC-V](https://riscv.org/specifications/),
with a few major differences.

Capsule bytecode uses only eight registers, one of them a hard-wired zero.

All Capsule instructions are encoded the same way ⁠— with a 7-bit opcode, three
3-bit registers, and one 16-bit immediate ⁠— even if not all of those fields are
meaningful to a particular instruction.

Here is a self-contained "hello world" program written in Capsule assembly:

``` casm
.const meta.exit_ok, 0x0001
.const stdio.init, 0x3000
.const stdio.put_byte, 0x3002

.rodata
    hello_world: .stringz "Hello, world!"
    
.text
.entry
    ; Ensure stdio is active
    ecalli Z, Z, stdio.init
    ; Initialize the loop counter to zero
    mv C, Z
loop:
    ; Load the next character in the string
    lbu X, C, hello_world
    ; If the character was zero, terminate the loop
    beq X, Z, end
    ; Otherwise proceed to print the character
    ecalli Z, X, stdio.put_byte
    ; Increment the loop counter C
    addi C, C, 1
    ; Go to the beginning of the loop
    j loop
end:
    ; End program execution
    ecalli Z, Z, meta.exit_ok
```

## Compiling

This repository is configured to be built with [**dub**](https://dub.pm/index.html).
With dub installed, run one of the following commands in a CLI with the repository root as your working directory to build a particular binary:

- Capsule virtual machine **capsule**: `dub --config=capsule --build=release`
- Capsule virtual machine **capsule** (CLI only): `dub --config=capsule-cli --build=release`
- Capsule assembler **casm**: `dub --config=casm --build=release`
- Capsule linker **clink**: `dub --config=clink --build=release`
- Capsule implementation checker **capcheck**: `dub --config=capcheck --build=release`

## Contributing

Contributions to the Capsule console project are welcome!

When contributing, please follow the
[code style guide](https://github.com/capsule-console/capsule.d/blob/master/docs/style-guide.md),
and please be civil and respectful of others.

As much as possible, this project should be self-contained
without relying on other libraries,
the [Phobos standard library](https://dlang.org/phobos/) included.
As much as possible, all import statements in this repository should
be either for modules in `capsule.*`, meaning modules implemented in
the project itself, or in `core.*`, meaning modules implemented by
the D programming language's
[low-level runtime library](https://github.com/dlang/druntime/tree/master/src/core).
