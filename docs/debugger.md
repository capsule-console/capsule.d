# Capsule Debugger

Capsule programs can be run in a debugging environment by
passing the `--debug` or `-db` flag as a command line argument
to the **capsule** VM binary.
Doing so loads a program normally but results in a debug command
prompt being displayed rather than executing the program immediately.

``` text
> capsule bin/hello-world.capsule -db
Running Capsule program in debug mode.
Type "help" for more information.
db >
```

Note that some debugger functionality will only be helpful if the
program being executed contains debugging information.

Debugging information can be included in compiled object files by
passing the `--debug` or `-db` option to the **casm** assembler binary.
Debugging information in object files can be carried on to the
executable program file by passing the `--debug` or `-db` option
to the **clink** linker binary.

``` text
> casm hello-world.casm -o bin/hello-world.casm -db
Wrote object data with debug info to bin/hello-world.casm
> clink bin/hello-world.casm -o bin/hello-world.capsule -db
Wrote program data with debug info to bin/hello-world.capsule
```

## Number values

Many commands accept one or more number values.
Number values can also be entered on their own into the prompt to
display them.

A number value is either:

- A decimal integer literal, e.g. **1234**
- A hexadecimal integer literal, e.g. **0x1234**
- **pc**, meaning the address where the program counter is located
- **entry**, meaning the address marked as the program's entry point
- **r1**, **a**, **A**, meaning register A (AKA r1)
- **r2**, **b**, **B**, meaning register B (AKA r2)
- **r3**, **c**, **C**, meaning register C (AKA r3)
- **r4**, **r**, **R**, meaning register R (AKA r4)
- **r5**, **s**, **S**, meaning register S (AKA r5)
- **r6**, **x**, **X**, meaning register X (AKA r6)
- **r7**, **y**, **Y**, meaning register Y (AKA r7)

``` text
db > 1234
1234 = 0x000004d2 (int: 1234)
db > 0x1234
0x1234 = 0x00001234 (int: 4660)
db > pc
pc = 0x0000001c (int: 28)
db > entry
entry = 0x00000010 (int: 16)
db > a
a = 0x00000000 (int: 0)
db > r6
r6 = 0x0000006c (int: 108)
```

## List of commands

### Quit (q)

Entering just **q** terminates the program and exits the debugger.

``` text
db > q
```

### Help (help)

Entering **help** displays help text and a summary of the available
debugger commands.

``` text
db > help
```

### Step once

Pressing enter without inputting anything causes the VM to execute one
instruction before pausing for input again, and to display the state of
the VM's registers prior to execution and the instruction that was
executed, accompanied by the memory address where that instruction was
located.

``` text
db >
Z = 0, A = 0, B = 0, C = 0, R = 0, S = 0, X = 0, Y = 0
@0x00000010: ecall rd: Z rs1: Z rs2: Z imm: 0x3000
db >
Z = 0, A = 0, B = 0, C = 0, R = 0, S = 0, X = 0, Y = 0
@0x00000014: add rd: C rs1: Z rs2: Z imm: 0x0000
db >
Z = 0, A = 0, B = 0, C = 0, R = 0, S = 0, X = 0, Y = 0
@0x00000018: lbu rd: X rs1: C rs2: Z imm: 0x0000
db >
Z = 0, A = 0, B = 0, C = 0, R = 0, S = 0, X = 72, Y = 0
@0x0000001c: beq rd: Z rs1: X rs2: Z imm: 0x0010
```

### Step multiple

Typing some number of periods `.` executes the same number of instructions
as there are periods before pausing for input.

``` text
db > ....
Z = 0, A = 0, B = 0, C = 0, R = 0, S = 0, X = 72, Y = 0
@0x00000020: beq rd: Z rs1: X rs2: Z imm: 0x0010
```

### Show registers (reg)

Entering **reg** displays the value of every register.

``` text
db > reg
Z = 0x00000000 (int: 0)
A = 0x00000000 (int: 0)
B = 0x00000000 (int: 0)
C = 0x00000003 (int: 3)
R = 0x00000000 (int: 0)
S = 0x00000000 (int: 0)
X = 0x0000006c (int: 108)
Y = 0x00000000 (int: 0)
```

### Set register (rset)

The **rset** command can be used to set the value of a register,
formatted like `rset [register] [value]` where `[register]` is the
name of a register and `[value]` is any valid number value.

``` text
db > rset A 1234
db > A
A = 0x000004d2 (int: 1234)
db > rset B A
db > B
B = 0x000004d2 (int: 1234)
```

### Resume execution (resume)

The **resume** command resumes normal program execution until
encountering either an **ebreak** instruction, an exception,
or an extension call that modifies the VM's status, for example
**meta.exit_ok** or **meta.exit_error**.

``` text
db > resume
HZ = 0, A = 0, B = 0, C = 1, R = 0, S = 0, X = 72, Y = 0
@0x00000028: ebreak rd: Z rs1: Z rs2: Z imm: 0x0000
db > l
hello-world.casm L26:
ebreak
```

### Toggle pausing on breakpoints (toggle ebreak)

The **toggle ebreak** command switches whether execution should
always pause when an **ebreak** breakpoint instruction was
encountered.

``` text
db > toggle ebreak
Toggled breakpoints: Execution will no longer pause on ebreak.
db > toggle ebreak
Toggled breakpoints: Execution will pause on ebreak.
```

### Until PC reaches address (until pc)

Enter **until pc** with a number value indicating an address
to resume program execution until that address is reached.

``` text
db > until pc 0x20
Z = 0, A = 0, B = 0, C = 0, R = 0, S = 0, X = 72, Y = 0
@0x0000001c: beq rd: Z rs1: X rs2: Z imm: 0x0010
```

### Until PC reaches symbol (until sym)

The **until sym** command can be used to resume program execution
until the program counter is at the address indicated by a given
symbol.

This will only work for programs that were built with debug settings
and so include symbol information.

``` text
db > sym loop
text label loop = 0x00000018 (int: 24)
Found 1 matching symbols.
db > until sym loop
Running until: text label loop = 0x00000018 (int: 24)
Z = 0, A = 0, B = 0, C = 0, R = 0, S = 0, X = 0, Y = 0
@0x00000018: lbu rd: X rs1: C rs2: Z imm: 0x0000
```

### Until PC reaches an opcode (until op)

The **until op** command resumes program execution until a
specified instruction opcode is encountered.

The target opcode can be specified either via hexadecimal
value (e.g. `0x04`) or via a mnemonic (e.g. `add`).

``` text
db > until op add
Z = 0, A = 0, B = 0, C = 0, R = 0, S = 0, X = 0, Y = 0
@0x00000014: add rd: C rs1: Z rs2: Z imm: 0x0000
db > until op 0x2d
Z = 0, A = 0, B = 0, C = 0, R = 0, S = 0, X = 0, Y = 0
@0x00000018: lbu rd: X rs1: C rs2: Z imm: 0x0000
```

### Until returning from the current procedure (until ret)

The **until ret** command can be used to resume program execution until
returning from a procedure that is currently being executed.

``` text
db > l
op-and.casm L18:
call R, write_hex
db >
Z = 0, A = 0, B = 32, C = 0, R = 36, S = 0, X = 0, Y = 0
@0x00000028: jalr rd: R rs1: R rs2: Z imm: 0x008c
db > until ret
0Z = 0, A = 0, B = 32, C = 0, R = 44, S = 0, X = 48, Y = 0
@0x000001ac: jalr rd: Z rs1: R rs2: Z imm: 0x0000
db > l
lib/write-hex.casm L45:
ret R
db >
Z = 0, A = 0, B = 32, C = 0, R = 44, S = 0, X = 48, Y = 0
@0x000001ac: jalr rd: Z rs1: R rs2: Z imm: 0x0000
db > l
op-and.casm L18:
ecalli Z, B, stdio.put_byte
```

### Show memory length characteristics (memlen)

The **memlen** command causes information about the current
program's memory to be displayed.

``` text
db > memlen
Memory length: 52
Read-only start: 0x00000000 (0)
Read-only end: 0x00000034 (52)
Executable start: 0x00000010 (16)
Executable end: 0x00000034 (52)
```

### Show symbol information (sym)

The **sym** command can be used to display information about a
symbol, when the loaded program file was built with debug settings
to include symbol definitions.

``` text
db > sym stdio.init
constant stdio.init = 0x00003000 (int: 12288)
Found 1 matching symbols.
db > sym hello_world
rodata label hello_world = 0x00000000 (int: 0)
Found 1 matching symbols.
```

### Load sign-extended byte (lb)

The **lb** command loads and displays a sign-extended
8-bit byte value located at a given memory address.

``` text
db > lb 0x18
@0x00000018 byte = 0x0000002d (int: 45)
db > lb 0x19
@0x00000019 byte = 0x0000000f (int: 15)
```

### Load zero-extended byte (lbu)

The **lbu** command loads and displays a zero-extended
8-bit byte value located at a given memory address.

``` text
db > lbu 0x18
@0x00000018 byte = 0x0000002d (int: 45)
db > lbu 0x19
@0x00000019 byte = 0x0000000f (int: 15)
```

### Load sign-extended half word (lh)

The **lh** command loads and displays a sign-extended
16-bit half word value located at a given memory address.

``` text
db > lh 0x10
@0x00000010 half = 0x0000003c (int: 60)
db > lh 0x12
@0x00000012 half = 0x00003000 (int: 12288)
db > lh 0x18
@0x00000018 half = 0x00000f2d (int: 3885)
db > lh 0x1a
@0x0000001a half = 0x00000000 (int: 0)
```

### Load zero-extended half word (lhu)

The **lhu** command loads and displays a zero-extended
16-bit half word value located at a given memory address.

``` text
db > lhu 0x10
@0x00000010 half = 0x0000003c (int: 60)
db > lhu 0x12
@0x00000012 half = 0x00003000 (int: 12288)
db > lhu 0x18
@0x00000018 half = 0x00000f2d (int: 3885)
db > lhu 0x1a
@0x0000001a half = 0x00000000 (int: 0)
```

### Load word (lw)

The **lw** command loads and displays a 32-bit word value
located at a given memory address.

``` text
db > lw 0x10
@0x00000010 word = 0x3000003c (int: 805306428)
db > lw 0x18
@0x00000018 word = 0x00000f2d (int: 3885)
```

### Load instruction (lin)

Use the **lin** command to load a word at a memory address
and display it, interpreted as a bytecode instruction.

``` text
db > lw 0x14
@0x00000014 word = 0x00000198 (int: 408)
db > lin 0x14
@0x00000014: add rd: C rs1: Z rs2: Z imm: 0x0000
db > lw 0x00
@0x00000000 word = 0x6c6c6548 (int: 1819043144)
db > lin 0x00
@0x00000000: op[0x48] rd: B rs1: A rs2: C imm: 0x6c6c
db > lin 0x15
@0x00000015: Misaligned address
```

### Show source map information (l)

The **l** command can be used with or without a number value
indicating a memory address.
Entering it without an explicit memory address is the same
as entering **l pc**.

Entering this command will display the source code text and
location associated with a given address in memory, assuming
that the loaded program file was built with debug settings and
so includes source map information.

``` text
db > pc
pc = 0x00000010 (int: 16)
db > l
hello-world.casm L13:
ecalli Z, Z, stdio.init
db > l 0x10
hello-world.casm L13:
ecalli Z, Z, stdio.init
db > l 0x14
hello-world.casm L15:
mv C, Z
db > l 0x18
hello-world.casm L19:
lbu X, C, hello_world
```

### List symbols (list sym)

The **list sym** command displays a list of all debug symbol
definitions included in the loaded program file.
Symbols are only included in programs built with debug settings.

``` text
db > list sym
Listing 6 symbols:
constant meta.exit_ok = 0x00000001 (int: 1)
constant stdio.init = 0x00003000 (int: 12288)
constant stdio.put_byte = 0x00003002 (int: 12290)
rodata label hello_world = 0x00000000 (int: 0)
text label loop = 0x00000018 (int: 24)
none label end = 0x00000030 (int: 48)
```

### List sources (list sources)

The **list sources** command displays a list of all source
files included in the loaded program file.
Sources are only included in programs built with debug
settings.

``` text
db > list sources
Listing 1 sources:
hello-world.casm
```