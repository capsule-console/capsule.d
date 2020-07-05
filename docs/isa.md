# Capsule Instruction Set Architecture

This document provides an exhaustive explanation of the Capsule instruction
set architecture (ISA) and all of its supported opcodes.

For a more concise summary of instructions, please refer to the
[Capsule Assembly Instruction Listing](./instructions.md).

Here is a very quick overview:

- Instructions are 32 bits long, and must be aligned on a 4-byte boundary.
- Opcodes are 7 bits long.
- Immediate values are 16 bits long, and they are always sign-extended
rather than zero-extended.
- Registers contain 32-bit integers.
- There are 7 general-purpose registers and a hard-wired zero register.
- Addressable memory can contain up to 2,147,483,648 bytes, or approximately 2 gigabytes.

Please note these common abbreviations:

- **rd**, meaning _destination register_, or the register to which the
output of an operation is written.
- **rs1**, meaning the _first source register_, or the first register from
which the input for an operation is read.
- **rs2**, meaning the _second source register_, or the second register from
which the input for an operation is read.
- **i32**, meaning an instruction's _immediate value_, sign-extended from
16 bits to 32 bits.
- **pc**, meaning the _program counter_. Also called an instruction pointer.

## Encoding

All Capsule bytecode instructions are represented with a 32-bit word
and should be represented in
[little endian order](https://en.wikipedia.org/wiki/Endianness)
when encoded in a binary format.
In compiled bytecode, instructions must always fall on a 32-bit
word boundary in memory in order to be executable.

There is only one instruction format, i.e. the same information about
an instruction always occupies the same span of bits for every opcode.

The opcode always occupies the lowest 7 bits, the destination register
the next 3 bits, the first source register the 3 bits after that,
the second source register a subsequent 3 bits, and an immediate value
occupies the highest 16 bits.

``` text
| 00 .. 07 | 07 .. 10 | 10 .. 13 | 13 .. 16 | 16 .. 32  |
| opcode   | rd       | rs1      | rs2      | immediate |
```

## Registers

There are eight registers that an instruction may operate upon, not counting
the _pc_, or program counter, which may be manipulated by jump and branch
instructions or accessed via the _auipc_ instruction.

Register 0, or _Z_, is a hard-wired zero register. When used for an instruction's
_rs1_ (first source register) or _rs2_ (second source register), it always
produces a value of 0. When used for an instruction's _rd_ (destination register),
it means that the output is discarded and is not written to any register.

The remaining registers 1 through 7 are general-purpose registers. They may
be given special meanings by an ABI or calling conventions, but the ISA itself
imposes no conventions or restrictions upon their usage.

The register names are, in order: Z, A, B, C, R, S, X, Y.

## Exceptions

Some instructions may produce an exception under certain circumstances.

As of writing, exceptions are always and immediately fatal to a Capsule program.
There is no way to recover from an exception.
In the future, there may be some facility to handle and recover from exceptions.

There are 127 possible exception codes, not counting the exception code used to
represent an absent or missing exception (0x00).
Currently, only fifteen of these codes have been assigned a meaning.
Only eleven of these codes are currently possible to trigger.

- **triple (0x01)** - Not currently used. This exception is reserved to
represent a triple fault, to be triggered if an exception occurs while
handling a double fault exception.

- **double (0x02)** - Not currently used. This exception is reserved to
represent a double fault, to be triggered if an exception occurs while
handling another exception.

- **instr (0x03)** - This exception is triggered when the virtual machine
encounters an unrecognized or invalid instruction.

- **pcexec (0x04)** - This exception is triggered when the program counter is
found to be in non-executable memory, i.e. outside the _text_ segment.

- **lalign (0x05)** - This exception is triggered upon attempting to load
a half word from an address not aligned on a 16 bit boundary,
or upon attempting to load a word from an address that is not aligned
on a 32 bit boundary.

- **salign (0x06)** - This exception is triggered upon attempting to store
a half word to an address not aligned on a 16 bit boundary,
or upon attempting to store a word to an address that is not aligned
on a 32 bit boundary.

- **pcalign (0x07)** - This exception is triggered when the program counter
is found to not be aligned on a 32-bit word boundary.

- **lbounds (0x08)** - This exception is triggered when attempting to load
from an address that is not within valid addressable memory, e.g. because
the signed address is less than zero or because it exceeds the length of
the program's memory.

- **sbounds (0x09)** - This exception is triggered when attempting to store
to an address that is not within valid addressable memory, e.g. because
the signed address is less than zero or because it exceeds the length of
the program's memory.

- **pcbounds (0x0a)** - This exception is triggered when the program counter
is found to not be within valid addressable memory, e.g. because
the signed address is less than zero or because it exceeds the length of
the program's memory.

- **sro (0x0b)** - This exception is triggered when attempting to store
to a read-only location in memory, such as to an address within the
program's _text_ or _rodata_ segment.

- **ovf (0x0c)** - Not currently used. This exception is reserved to
represent arithmetic overflow.

- **divz (0x0d)** - Not currently used. This exception is reserved to
represent an integer divison by zero.

- **extmiss (0x0e)** - This exception is triggered by the _ecall_ instruction
when the given extension ID value is unknown or unsupported by the VM
implementation.

- **exterr (0x0f)** - This exception may be triggered by the _ecall_
instruction, depending on the extension, to signal some kind of error or
invalid state detected while calling that extension.

## Opcode Listing

### Missing or invalid instruction (0x00)

The zero opcode is reserved to represent a missing or invalid instruction.

### Bitwise AND (and, 0x04)

_rd = rs1 & rs2_

The _and_ instruction performs a
[bitwise AND](https://en.wikipedia.org/wiki/Bitwise_operation#AND)
operation on the values of _rs1_ and _rs2_ and stores the result in _rd_.

### Bitwise OR (or, 0x05)

_rd = rs1 | rs2_

The _or_ instruction performs a
[bitwise OR](https://en.wikipedia.org/wiki/Bitwise_operation#OR)
operation on the values of _rs1_ and _rs2_ and stores the result in _rd_.

### Bitwise XOR (xor, 0x06)

_rd = rs1 ^ rs2_

The _xor_ instruction performs a
[bitwise XOR](https://en.wikipedia.org/wiki/Bitwise_operation#XOR),
or "exclusive or" operation on the values of _rs1_ and _rs2_ and
stores the result in _rd_.

### Subtract (sub, 0x07)

_rd = rs1 - rs2_

The _sub_ instruction subtracts _rs2_ from _rs1_ and stores the
difference in _rd_.

### Set minimum signed (min, 0x08)

_rd = rs1 < rs2 ? rs1 : rs2_

The _min_ instruction compares _rs1_ and _rs2_ as signed integers,
and stores the lesser value in _rd_.

### Set minimum unsigned (minu, 0x09)

_rd = rs1 < rs2 ? rs1 : rs2_

The _minu_ instruction compares _rs1_ and _rs2_ as unsigned integers,
and stores the lesser value in _rd_.

### Set to maximum signed (max, 0x0a)

_rd = rs1 >= rs2 ? rs1 : rs2_

The _min_ instruction compares _rs1_ and _rs2_ as signed integers,
and stores the greater value in _rd_.

### Set to maximum unsigned (maxu, 0x0b)

_rd = rs1 >= rs2 ? rs1 : rs2_

The _minu_ instruction compares _rs1_ and _rs2_ as unsigned integers,
and stores the greater value in _rd_.

### Set if less than signed (slt, 0x0c)

_rd = rs1 < rs2 ? 1 : 0_

The _slt_ instruction compares _rs1_ and _rs2_ as signed integers.
It stores 1 in _rd_ if _rs1_ was less than _rs2_, and stores 0 otherwise.

### Set if less than unsigned (sltu, 0x0d)

_rd = rs1 < rs2 ? 1 : 0_

The _sltu_ instruction compares _rs1_ and _rs2_ as unsigned integers.
It stores 1 in _rd_ if _rs1_ was less than _rs2_, and stores 0 otherwise.

### Multiply and truncate (mul, 0x10)

_rd = (rs1 * rs2) & 0x0000000ffffffff_

The _mul_ instruction multiples _rs1_ and _rs2_ and stores the
low 32 bits of the product to _rd_.

### Multiply signed and shift (mulh, 0x11)

_rd = (rs1 * rs2) >> 32_

The _mulh_ instruction multiples _rs1_ and _rs2_, both as signed integers,
and stores the high 32 bits of the product to _rd_.

### Multiply unsigned and shift (mulhu, 0x12)

_rd = (rs1 * rs2) >> 32_

The _mulhu_ instruction multiples _rs1_ and _rs2_, both as unsigned integers,
and stores the high 32 bits of the product to _rd_.

### Multiply signed by unsigned and shift (mulhsu, 0x13)

_rd = (rs1 * rs2) >> 32_

The _mulhsu_ instruction multiples _rs1_ and _rs2_, _rs1_ as a signed
integer and _rs2_ as an unsigned integer, and stores the high 32 bits
of the product to _rd_.

### Divide signed (div, 0x14)

_rd = rs2 == 0 ? 0 : rs1 / rs2_

The _div_ instruction divides _rs1_ by _rs2_, both as signed integers,
and stores the quotient to _rd_.

If _rs2_ was 0, 0 is stored to _rd_.

If _rs1_ was -2147483648 and _rs2_ was -1, -2147483648 is stored to _rd_,
the same overflow behavior as if -2147483648 was subtracted from 0.

### Divide unsigned (divu, 0x15)

_rd = rs2 == 0 ? 0 : rs1 / rs2_

The _divu_ instruction divides _rs1_ by _rs2_, both as unsigned integers,
and stores the quotient to _rd_.

If _rs2_ was 0, 0 is stored to _rd_.

### Remainder (rem, 0x16)

_rd = rs2 == 0 ? 0 : rs1 % rs2_

The _rem_ instruction divides _rs1_ by _rs2_, both as signed integers,
and stores the remainder to _rd_.

When nonzero, the remainder has the same sign as _rs1_, the dividend.

If _rs2_ was 0, 0 is stored to _rd_.

### Remainder unsigned (remu, 0x17)

_rd = rs2 == 0 ? 0 : rs1 % rs2_

The _remu_ instruction divides _rs1_ by _rs2_, both as unsigned integers,
and stores the remainder to _rd_.

If _rs2_ was 0, 0 is stored to _rd_.

### Reverse byte order (revb, 0x18)

_rd = revb(rs1)_

The _revb_ instruction reverses the byte order of _rs1_ and stores
the result in _rd_, i.e. the least significant byte becomes the most
significant byte and vice-versa.

Note that a byte is 8 bits in length, and there are four bytes
in a 32-bit register.

### Reverse half word order (revh, 0x19)

_rd = revh(rs1)_

The _revh_ instruction reverses the half word order of _rs1_ and stores
the result in _rd_, i.e. the least significant half word becomes the most
significant half word and vice-versa.

Note that a half word is 16 bits in length, and there are two half words
in a 32-bit register.

### Count leading zeros (clz, 0x1a)

_rd = clz(rs1)_

The _clz_ instruction counts the number of leading zeros in the binary
representation of _rs1_, and stores that count to _rd_.

### Count trailing zeros (ctz, 0x1b)

_rd = ctz(rs1)_

The _ctz_ instruction counts the number of trailing zeros in the binary
representation of _rs1_, and stores that count to _rd_.

### Count set bits (pcnt, 0x1c)

_rd = pcnt(rs1)_

The _pcnt_, or "population count" instruction, counts the number of set
bits in the binary representation of _rs1_, and stores that count to _rd_.

### Breakpoint (ebreak, 0x3f)

The _ebreak_ instruction is reserved to represent a breakpoint for debugging
tools. When not given a special meaning by a debugger, the _ebreak_
instruction is to be treated as a no-op.

### Bitwise AND immediate (andi, 0x44)

_rd = rs1 & i32_

The _and_ instruction performs a
[bitwise AND](https://en.wikipedia.org/wiki/Bitwise_operation#AND)
operation on _rs1_ and _i32_ and stores the result in _rd_.

### Bitwise OR immediate (ori, 0x45)

_rd = rs1 | i32_

The _or_ instruction performs a
[bitwise OR](https://en.wikipedia.org/wiki/Bitwise_operation#OR)
operation on _rs1_ and _i32_ and stores the result in _rd_.

### Bitwise XOR immediate (xori, 0x46)

_rd = rs1 ^ i32_

The _xor_ instruction performs a
[bitwise XOR](https://en.wikipedia.org/wiki/Bitwise_operation#XOR)
operation on _rs1_ and _i32_ and stores the result in _rd_.

### Shift logical left (sll, 0x48)

_rd = (rs1 << (i32 & 0x1F)) << (rs2 & 0x1F)_

The _sll_ instruction performs a bit shift left of _rs1_, first by the
value indicated by the lowest 5 bits of _rs2_, and then also by the
value indicated by the lowest 5 bits of _i32_.

The shift operation moves bits from a lower order position to a higher
order position. The lowest bits, which information was shifted out of,
are filled with zeros.

### Shift logical right (srl, 0x49)

_rd = (rs1 >>> (i32 & 0x1F)) >>> (rs2 & 0x1F)_

The _srl_ instruction performs a logical bit shift right of _rs1_,
first by the value indicated by the lowest 5 bits of _rs2_,
and then also by the value indicated by the lowest 5 bits of _i32_.

The shift operation moves bits from a higher order position to a lower
order position. The highest bits, which information was shifted out of,
are filled with zeros.

### Shift arithmetic right (sra, 0x4a)

_rd = (rs1 >> (i32 & 0x1F)) >> (rs2 & 0x1F)_

The _sra_ instruction performs an arithmetic bit shift right of _rs1_,
first by the value indicated by the lowest 5 bits of _rs2_,
and then also by the value indicated by the lowest 5 bits of _i32_.

The shift operation moves bits from a higher order position to a lower
order position. The highest bits, which information was shifted out of,
are filled with the sign bit, i.e. zero if the highest bit was previously
zero and one if the highest bit was previously one.

### Add (add, 0x4b)

_rd = rs1 + rs2 + i32_

The _add_ instruction adds three integer values, _rs1_, _rs2_, and _i32_,
and stores the sum of the addition to _rd_.

### Set if less than immediate (slti, 0x4c)

_rd = rs1 < i32 ? 1 : 0_

The _slti_ instruction compares _rs1_ and _i32_ as signed integers.
It stores 1 in _rd_ if _rs1_ was less than _i32_, and stores 0 otherwise.

### Set if less than immediate unsigned (sltiu, 0x4d)

_rd = rs1 < i32 ? 1 : 0_

The _sltiu_ instruction compares _rs1_ and _rs2_ as unsigned integers.
It stores 1 in _rd_ if _rs1_ was less than _i32_, and stores 0 otherwise.

### Load upper immediate (lui, 0x4e)

_rd = i32 << 16_

The _lui_ instruction shifts _i32_ left by 16 bit places and stores
the result to _rd_, in effect loading an upper half word into _rd_.

### Add upper immediate to program counter (auipc, 0x4f)

_rd = pc + (i32 << 16)_

The _auipc_ instruction shifts _i32_ left by 16 bit places and stores
the sum of that value and the current _pc_, or program counter, to _rd_.

This instruction is essential for computing relative offsets to jump,
load, or store targets in relocatable code.

### Load sign-extended byte (lb, 0x50)

_rd = memory.byte[rs1 + i32]_

The _lb_ instruction loads an 8-bit byte from the address indicated by the
sum of _rs1_ and _i32_ and stores that byte, sign-extended, to _rd_.

Attempting to load from an address that is outside of the program's
addressable memory will trigger an _lbounds_ exception (0x08).

### Load zero-extended byte (lbu, 0x51)

_rd = memory.ubyte[rs1 + i32]_

The _lbu_ instruction loads an 8-bit byte from the address indicated by the
sum of _rs1_ and _i32_ and stores that byte, zero-extended, to _rd_.

Attempting to load from an address that is outside of the program's
addressable memory will trigger an _lbounds_ exception (0x08).

### Load sign-extended half word (lh, 0x52)

_rd = memory.half[(rs1 + i32)]_

The _lh_ instruction loads a 16-bit  half word from the memory address
indicated by the sum of _rs1_ and _i32_ and stores that half word,
sign-extended, to _rd_.

Attempting to load from an address that is outside of the program's
addressable memory will trigger an _lbounds_ exception (0x08).

Attempting to load from an address that is not aligned on a 16-bit half
word boundary will trigger an _lalign_ exception (0x05).

### Load zero-extended half word (lhu, 0x53)

_rd = memory.uhalf[(rs1 + i32)]_

The _lhu_ instruction loads a 16-bit half word from the memory address
indicated by the sum of _rs1_ and _i32_ and stores that half word,
zero-extended, to _rd_.

Attempting to load from an address that is outside of the program's
addressable memory will trigger an _lbounds_ exception (0x08).

Attempting to load from an address that is not aligned on a 16-bit half
word boundary will trigger an _lalign_ exception (0x05).

### Load word (lw, 0x54)

_rd = memory.word[(rs1 + i32)]_

The _lw_ instruction loads a 32-bit word from the memory address
indicated by the sum of _rs1_ and _i32_ and stores that word to _rd_.

Attempting to load from an address that is outside of the program's
addressable memory will trigger an _lbounds_ exception (0x08).

Attempting to load from an address that is not aligned on a 32-bit word
boundary will trigger an _lalign_ exception (0x05).

### Store byte (sb, 0x55)

_memory.byte[rs2 + i32] = rs1 & 0xff_

The _sb_ instruction stores the low 8-bit byte of _rs1_ to the
memory address indicated by the sum of _rs2_ and _i32_.

Attempting to store to an address that is outside of the program's
addressable memory will trigger an _sbounds_ exception (0x09).

Attempting to store to an address that is read-only,
such as an address that is in a program's _text_ or _rodata_ segment,
will trigger an _sro_ exception (0x0b).

### Store half word (sh, 0x56)

_memory.half[(rs2 + i32)] = rs1 & 0xffff_

The _sh_ instruction stores the low 16-bit half word of _rs1_ to the
memory address indicated by the sum of _rs2_ and _i32_.

Attempting to store to an address that is outside of the program's
addressable memory will trigger an _sbounds_ exception (0x09).

Attempting to store to an address that is not aligned on a 16-bit half word
boundary will trigger an _salign_ exception (0x06).

Attempting to store to an address that is read-only,
such as an address that is in a program's _text_ or _rodata_ segment,
will trigger an _sro_ exception (0x0b).

### Store word (sw, 0x57)

_memory.word[(rs2 + i32)] = rs1_

The _sw_ instruction stores the entire word value of _rs1_ to the
memory address indicated by the sum of _rs2_ and _i32_.

Attempting to store to an address that is outside of the program's
addressable memory will trigger an _sbounds_ exception (0x09).

Attempting to store to an address that is not aligned on a 32-bit word
boundary will trigger an _salign_ exception (0x06).

Attempting to store to an address that is read-only,
such as an address that is in a program's _text_ or _rodata_ segment,
will trigger an _sro_ exception (0x0b).

### Jump and link (jal, 0x58)

_rd = pc + 4, pc = (pc + i32)_

The _jal_ instruction first stores the sum of the current _pc_ and the
constant 4 to _rd_, which is the memory address of the subsequent instruction,
then adds _i32_ to the _pc_.

Attempting to jump to an address that is outside the program's
addressable memory will trigger a _pcbounds_ exception (0x0a).

Attempting to jump to an address that is not aligned on a 32-bit word
boundary will trigger a _pcalign_ exception (0x07).

Attempting to jump to an address that is not executable, i.e. that
is not within the program's _text_ segment, will trigger a _pcexec_
exception (0x04).

### Jump and link register (jalr, 0x59)

_rd = pc + 4, pc = (rs1 + i32)_

The _jalr_ instruction stores computes the sum of the current _pc_ and the
constant 4 to _rd_, which is the memory address of the subsequent instruction.
It then stores the sum of _rs1_ and _i32_ to the _pc_.

If the same register was used as both _rs1_ and _rd_, then the value of
the register upon entering the instruction is summed with _i32_ to determine
the destination of the _pc_.

Attempting to jump to an address that is outside the program's
addressable memory will trigger a _pcbounds_ exception (0x0a).

Attempting to jump to an address that is not aligned on a 32-bit word
boundary will trigger a _pcalign_ exception (0x07).

Attempting to jump to an address that is not executable, i.e. that
is not within the program's _text_ segment, will trigger a _pcexec_
exception (0x04).

### Branch if equal (beq, 0x5a)

_if rs1 == rs2: pc = pc + (i32)_

The _beq_ instruction compares the values of _rs1_ and _rs2_ and, if they
are equal, adds _i32_ to the _pc_, or program counter.

If _rs1_ and _rs2_ were not equal, then execution continues at the
subsequent instruction as normal.

Attempting to branch to an address that is outside the program's
addressable memory will trigger a _pcbounds_ exception (0x0a).

Attempting to branch to an address that is not aligned on a 32-bit word
boundary will trigger a _pcalign_ exception (0x07).

Attempting to branch to an address that is not executable, i.e. that
is not within the program's _text_ segment, will trigger a _pcexec_
exception (0x04).

### Branch if not equal (bne, 0x5b)

_if rs1 != rs2: pc = pc + (i32)_

The _bne_ instruction compares the values of _rs1_ and _rs2_ and, if they
are not equal, adds _i32_ to the _pc_, or program counter.

If _rs1_ and _rs2_ were equal, then execution continues at the
subsequent instruction as normal.

Attempting to branch to an address that is outside the program's
addressable memory will trigger a _pcbounds_ exception (0x0a).

Attempting to branch to an address that is not aligned on a 32-bit word
boundary will trigger a _pcalign_ exception (0x07).

Attempting to branch to an address that is not executable, i.e. that
is not within the program's _text_ segment, will trigger a _pcexec_
exception (0x04).

### Branch if less than signed (blt, 0x5c)

_if rs1 < rs2: pc = pc + (i32)_

The _blt_ instruction compares the values of _rs1_ and _rs2_, both as
signed integers. If they _rs1_ was less than _rs2_, then _i32_ is added
to the _pc_, or program counter.

If _rs1_ was not less than _rs2_, then execution continues at the
subsequent instruction as normal.

Attempting to branch to an address that is outside the program's
addressable memory will trigger a _pcbounds_ exception (0x0a).

Attempting to branch to an address that is not aligned on a 32-bit word
boundary will trigger a _pcalign_ exception (0x07).

Attempting to branch to an address that is not executable, i.e. that
is not within the program's _text_ segment, will trigger a _pcexec_
exception (0x04).

### Branch if less than unsigned (bltu, 0x5d)

_if rs1 < rs2: pc = pc + (i32)_

The _bltu_ instruction compares the values of _rs1_ and _rs2_, both as
unsigned integers. If they _rs1_ was less than _rs2_, then _i32_ is added
to the _pc_, or program counter.

If _rs1_ was not less than _rs2_, then execution continues at the
subsequent instruction as normal.

Attempting to branch to an address that is outside the program's
addressable memory will trigger a _pcbounds_ exception (0x0a).

Attempting to branch to an address that is not aligned on a 32-bit word
boundary will trigger a _pcalign_ exception (0x07).

Attempting to branch to an address that is not executable, i.e. that
is not within the program's _text_ segment, will trigger a _pcexec_
exception (0x04).

### Branch if greater or equal signed (bge, 0x5e)

_if rs1 >= rs2: pc = pc + (i32)_

The _bge_ instruction compares the values of _rs1_ and _rs2_, both as
signed integers. If they _rs1_ was greater than or equal to _rs2_,
then _i32_ is added to the _pc_, or program counter.

If _rs1_ was not greater than or equal to _rs2_,
then execution continues at the subsequent instruction as normal.

Attempting to branch to an address that is outside the program's
addressable memory will trigger a _pcbounds_ exception (0x0a).

Attempting to branch to an address that is not aligned on a 32-bit word
boundary will trigger a _pcalign_ exception (0x07).

Attempting to branch to an address that is not executable, i.e. that
is not within the program's _text_ segment, will trigger a _pcexec_
exception (0x04).

### Branch if greater or equal unsigned (bgeu, 0x5f)

_if rs1 >= rs2: pc = pc + (i32)_

The _bgeu_ instruction compares the values of _rs1_ and _rs2_, both as
unsigned integers. If they _rs1_ was greater than or equal to _rs2_,
then _i32_ is added to the _pc_, or program counter.

If _rs1_ was not greater than or equal to _rs2_,
then execution continues at the subsequent instruction as normal.

If the new _pc_ is outside of the program's addressable memory, then
this will trigger a _pcbounds_ exception (0x0a).

Attempting to branch to an address that is outside the program's
addressable memory will trigger a _pcbounds_ exception (0x0a).

Attempting to branch to an address that is not aligned on a 32-bit word
boundary will trigger a _pcalign_ exception (0x07).

Attempting to branch to an address that is not executable, i.e. that
is not within the program's _text_ segment, will trigger a _pcexec_
exception (0x04).

### Call extension (ecall, 0x7f)

_rd = ecall(extid: rs2 + i32, input: rs1)_

The _ecall_ instruction invokes the extension identified by the sum of
_rs2_ and _i32_. The value of _rs1_ may be treated as an input, depending
on the extension.

Attempting to call an extension which is not supported by the implementation
will trigger an _extmiss_ exception (0x0e).
Note that the _meta.check_ext_ extension (0x00000003) should be provided
by every implementation to check whether an extension ID is supported or not.

Called extensions may trigger an _exterr_ exception (0x0f) if they were
used in an unsupported or invalid manner.
