# Standard Application Binary Interface for Capsule Bytecode

Capsule bytecode recognizes eight registers.

The first is Z, or hardwired zero, for which reads are always zero
and writes are a non-operation.

The remaining seven are all general-purpose registers, assigned
conventional uses by the standard ABI.

## Summary of register usage

| Name | Convention                         | Saved by  |
| ---- | ---------------------------------- | --------- |
| A    | Function argument & return value   | caller    |
| B    | Stack frame pointer                | callee    |
| C    | Saved register                     | callee    |
| R    | Return address                     | callee    |
| S    | Stack pointer                      | callee    |
| X    | Temporary register                 | caller    |
| Y    | Temporary register                 | caller    |

The first three word-or-smaller function arguments are passed in
the registers A, X, and Y, from first to last priority.
Other arguments are pushed onto the stack, indicated by the
stack pointer register S and stack frame pointer register B.

Word-sized return values are given in registers A, X, and Y.
Other or additional return values are saved on the stack.

Functions are not obligated to preserve the A, X, or Y registers
across function boundaries.
They are, however, obligated to preserve the B, C, R, and S registers
across function boundaries.
