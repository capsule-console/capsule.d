# Capsule Assembly Instruction Listing

Here is a list of all the instructions recognized by the Capsule assembler
and runtime in a brief and condensed format.

Note the following abbreviations:

- rd, meaning the destination register.
- rs1, meaning the first source register.
- rs2, meaning the second source register.
- imm, meaning an immediate value.
- i32 meaning the immediate value, sign-extended to 32 bits.

## Instructions

| Code | Mnemonic               | Name                                      | Operation |
| ---- | ---------------------- | ----------------------------------------- | --------- |
| 0x00 | \-                     | Missing or invalid instruction            | \- |
| 0x01 | \-                     | _Reserved_                                | \- |
| 0x02 | \-                     | _Reserved_                                | \- |
| 0x03 | \-                     | _Reserved_                                | \- |
| 0x04 | and rd,rs1,rs2         | Bitwise AND                               | rd = rs1 & rs2 |
| 0x05 | or rd,rs1,rs2          | Bitwise OR                                | rd = rs1 | rs2 |
| 0x06 | xor rd,rs1,rs2         | Bitwise XOR                               | rd = rs1 ^ rs2 |
| 0x07 | sub rd,rs1,rs2         | Subtract                                  | rd = rs1 - rs2 |
| 0x08 | min rd,rs1,rs2         | Set to minimum signed                     | rd = rs1 < rs2 ? rs1 : rs2 |
| 0x09 | minu rd,rs1,rs2        | Set to minimum unsigned                   | rd = rs1 < rs2 ? rs1 : rs2 |
| 0x0a | max rd,rs1,rs2         | Set to maximum signed                     | rd = rs1 >= rs2 ? rs1 : rs2 |
| 0x0b | maxu rd,rs1,rs2        | Set to maximum unsigned                   | rd = rs1 >= rs2 ? rs1 : rs2 |
| 0x0c | slt rd,rs1,rs2         | Set if less than signed                   | rd = rs1 < rs2 ? 1 : 0 |
| 0x0d | sltu rd,rs1,rs2        | Set if less than unsigned                 | rd = rs1 < rs2 ? 1 : 0 |
| 0x10 | mul rd,rs1,rs2         | Multiply and truncate                     | rd = (rs1 * rs2) & 0x00000000ffffffff |
| 0x11 | mulh rd,rs1,rs2        | Multiply signed and shift                 | rd = (rs1 * rs2) >> 32 |
| 0x12 | mulhu rd,rs1,rs2       | Multiply unsigned and shift               | rd = (rs1 * rs2) >> 32 |
| 0x13 | mulhsu rd,rs1,rs2      | Multiply signed by unsigned and shift     | rd = (rs1 * rs2) >> 32 |
| 0x14 | div rd,rs1,rs2         | Divide signed                             | rd = rs2 == rs1 / rs2 |
| 0x15 | divu rd,rs1,rs2        | Divide unsigned                           | rd = rs2 == rs1 / rs2 |
| 0x16 | rem rd,rs1,rs2         | Remainder signed                          | rd = rs2 == rs1 % rs2 |
| 0x17 | remu rd,rs1,rs2        | Remainder unsigned                        | rd = rs2 == rs1 % rs2 |
| 0x18 | revb rd,rs1            | Reverse byte order                        | rd = revb(rs1) |
| 0x19 | revh rd,rs1            | Reverse half word order                   | rd = revh(rs1) |
| 0x1a | clz rd,rs1             | Count leading zeros                       | rd = clz(rs1) |
| 0x1b | ctz rd,rs1             | Count trailing zeros                      | rd = ctz(rs1) |
| 0x1c | pcnt rd,rs1            | Count set bits                            | rd = pcnt(rs1) |
| 0x1d | \-                     | _Reserved, through to 0x3e_               | \- |
| 0x3f | ebreak                 | Breakpoint                                | Breakpoint for debuggers |
| 0x40 | \-                     | _Reserved_                                | \- |
| 0x41 | \-                     | _Reserved_                                | \- |
| 0x42 | \-                     | _Reserved_                                | \- |
| 0x43 | \-                     | _Reserved_                                | \- |
| 0x44 | andi rd,rs1,imm        | Bitwise AND immediate                     | rd = rs1 AND i32 |
| 0x45 | ori rd,rs1,imm         | Bitwise OR immediate                      | rd = rs1 OR i32 |
| 0x46 | xori rd,rs1,imm        | Bitwise XOR immediate                     | rd = rs1 XOR i32 |
| 0x47 | \-                     | _Reserved_                                | \- |
| 0x48 | sll rd,rs1,rs2,imm     | Shift logical left                        | rd = (rs1 << (i32 & 0x1F)) << (rs2 & 0x1F) |
| 0x49 | srl rd,rs1,rs2,imm     | Shift logical right                       | rd = (rs1 >>> (i32 & 0x1F)) >>> (rs2 & 0x1F) |
| 0x4a | sra rd,rs1,rs2,imm     | Shift arithmetic right                    | rd = (rs1 >> (i32 & 0x1F)) >> (rs2 & 0x1F) |
| 0x4b | add rd,rs1,rs2,imm     | Add                                       | rd = rs1 + rs2 + i32 |
| 0x4c | slti rd,rs1,imm        | Set if less than immediate signed         | rd = rs1 < i32 ? 1 : 0 |
| 0x4d | sltiu rd,rs1,imm       | Set if less than immediate unsigned       | rd = rs1 < i32 ? 1 : 0 |
| 0x4e | lui rd,imm             | Load upper immediate                      | rd = i32 << 16 |
| 0x4f | auipc rd,imm           | Add upper immediate to program counter    | rd = pc + (i32 << 16) |
| 0x50 | lb rd,rs1,imm          | Load sign-extended byte                   | rd = memory.byte[rs1 + i32] |
| 0x51 | lbu rd,rs1,imm         | Load zero-extended byte                   | rd = memory.ubyte[rs1 + i32] |
| 0x52 | lh rd,rs1,imm          | Load sign-extended half word              | rd = memory.half[rs1 + i32] |
| 0x53 | lhu rd,rs1,imm         | Load zero-extended half word              | rd = memory.uhalf[rs1 + i32] |
| 0x54 | lw rd,rs1,imm          | Load word                                 | rd = memory.word[rs1 + i32] |
| 0x55 | sb rs2,rs1,imm         | Store byte                                | memory.byte[rs1 + i32] = rs1 |
| 0x56 | sh rs2,rs1,imm         | Store half word                           | memory.half[rs1 + i32] = rs1 |
| 0x57 | sw rs2,rs1,imm         | Store word                                | memory.word[rs1 + i32] = rs1 |
| 0x58 | jal rd,imm             | Jump and link                             | rd = pc + 4, pc = (pc + i32) |
| 0x59 | jalr rd,rs1,imm        | Jump and link register                    | rd = pc + 4, pc = (rs1 + i32) |
| 0x5a | beq rs1,rs2,imm        | Branch if equal                           | if rs1 == rs2: pc = pc + (i32) |
| 0x5b | bne rs1,rs2,imm        | Branch if not equal                       | if rs1 != rs2: pc = pc + (i32) |
| 0x5c | blt rs1,rs2,imm        | Branch if less than signed                | if rs1 < rs2: pc = pc + (i32) |
| 0x5d | bltu rs1,rs2,imm       | Branch if less than unsigned              | if rs1 < rs2: pc = pc + (i32) |
| 0x5e | bge rs1,rs2,imm        | Branch if greater or equal signed         | if rs1 >= rs2: pc = pc + (i32) |
| 0x5f | bgeu rs1,rs2,imm       | Branch if greater or equal unsigned       | if rs1 >= rs2: pc = pc + (i32) |
| 0x60 | \-                     | _Reserved, through to 0x7e_               | \- |
| 0x7f | ecall rd,rs1,rs2,imm   | Call extension                            | rd = ecall(extid: rs2 + i32, input: rs1) |

## Pseudo-instructions

Here is a list of the pseudo-instructions recognized by the
Capsule assembler.
Pseudo-instructions are tools of convenience for translating common
abstract functions to a certain instruction or series of instructions.

The "Operation" column is present for illustrative purposes.
A compiler may emit different assembly code than this for pseudo-instructions,
particularly depending on the inputs.

| Mnemonic              | Name                                  | Operation |
|-----------------------|---------------------------------------|-----------|
| nop                   | No operation                          | add Z,Z,Z,0 |
| mv rd,rs1             | Copy register                         | add rd,rs1,Z,0 |
| not rd,rs1            | One's complement negation             | xori rd,rs1,-1 |
| neg rd,rs1            | Two's complement negation             | sub rd,Z,rs1 |
| nand rd,rs1,rs2       | Bitwise NOT AND                       | and rd,rs1,rs2 <br> xori rd,rd,-1 |
| nor rd,rs1,rs2        | Bitwise NOT OR                        | or rd,rs1,rs2 <br> xori rd,rd,-1 |
| xnor rd,rs1,rs2       | Bitwise NOT XOR                       | xor rd,rs1,rs2 <br> xori rd,rd,-1 |
| nandi rd,rs1,imm      | Bitwise NOT AND immediate             | andi rd,rs1,imm <br> xori rd,rd,-1 |
| nori rd,rs1,imm       | Bitwise NOT OR immediate              | ori rd,rs1,imm <br> xori rd,rd,-1 |
| xnori rd,rs1,imm      | Bitwise NOT XOR immediate             | xori rd,rs1,imm <br> xori rd,rd,-1 |
| andn rd,rs1,rs2       | Bitwise AND NOT                       | xori rd,rs2,-1 <br> and rd,rs1,rd |
| orn rd,rs1,rs2        | Bitwise OR NOT                        | xori rd,rs2,-1 <br> and rd,rs1,rd |
| xorn rd,rs1,rs2       | Bitwise XOR NOT                       | xori rd,rs2,-1 <br> and rd,rs1,rd |
| slli rd,rs1,imm       | Shift logical left by immediate       | sll rd,rs1,Z,imm |
| srli rd,rs1,imm       | Shift logical right by immediate      | srl rd,rs1,Z,imm |
| srai rd,rs1,imm       | Shift arithmetic right by immediate   | sra rd,rs1,Z,imm |
| addi rd,rs1,imm       | Add immediate                         | add rd,rs1,Z,imm |
| addwi rd,rs1,word     | Add word immediate                    | lui rd,word[hi] <br> add rd,rs1,rd,word[lo] |
| andwi rd,rs1,word     | Bitwise AND word immediate            | li rd,word <br> and rd,rs1,rd |
| orwi rd,rs1,word      | Bitwise OR word immediate             | li rd,word <br> or rd,rs1,rd |
| xorwi rd,rs1,word     | Bitwise XOR word immediate            | li rd,word <br> xor rd,rs1,rd |
| sltwi rd,rs1,word     | Set less than signed word immediate   | li rd,word <br> slt rd,rs1,rd |
| sltwiu rd,rs1,word    | Set less than unsigned word immediate | li rd,word <br> sltu rd,rs1,rd |
| clo rd,rs1            | Count leading ones                    | xori rd,rs1,-1 <br> clz rd,rd |
| cto rd,rs1            | Count trailing ones                   | xori rd,rs1,-1 <br> ctz rd,rd |
| seqz rd,rs1           | Set if equal to zero                  | sltiu rd,rs1,1 |
| snez rd,rs1           | Set if not equal to zero              | sltu rd,Z,rs1 |
| sltz rd,rs1           | Set if less than zero                 | slt rd,rs1,Z |
| sgtz rd,rs1           | Set if greater than zero              | slt rd,Z,rs1 |
| slez rd,rs1           | Set if less or equal to zero          | slti rd,rs1,1 |
| sgez rd,rs1           | Set if greater or equal to zero       | slt rd,rs1,Z <br> sltiu rd,rd,1 |
| li rd,value           | Load immediate                        | lui rd,value[hi] <br> add rd,rd,value[lo] |
| la rd,address         | Load address                          | auipc rd,address[pcrel_hi] <br> add rd,rd,address[pcrel_near_lo] |
| lba rd,address        | Load signed byte from address         | auipc rd,address[pcrel_hi] <br> lb rd,rd,address[pcrel_near_lo] |
| lbua rd,address       | Load unsigned byte from address       | auipc rd,address[pcrel_hi] <br> lba rd,rd,address[pcrel_near_lo] |
| lha rd,address        | Load signed half word from address    | auipc rd,address[pcrel_hi] <br> lh rd,rd,address[pcrel_near_lo] |
| lhua rd,address       | Load unsigned half word from address  | auipc rd,address[pcrel_hi] <br> lha rd,rd,address[pcrel_near_lo] |
| lwa rd,address        | Load word from address                | auipc rd,address[pcrel_hi] <br> lw rd,rd,address[pcrel_near_lo] |
| sba rd,rs1,address    | Store byte to address                 | auipc rd,address[pcrel_hi] <br> sb rs1,rd,address[pcrel_near_lo] |
| sha rd,rs1,address    | Store half word to address            | auipc rd,address[pcrel_hi] <br> sh rs1,rd,address[pcrel_near_lo] |
| swa rd,rs1,address    | Store word to address                 | auipc rd,address[pcrel_hi] <br> sw rs1,rd,address[pcrel_near_lo] |
| seq rd,rs1,rs2        | Set if equal                          | sub rd,rs1,rs2 <br> sltiu rd,rd,1 |
| sne rd,rs1,rs2        | Set if not equal                      | sub rd,rs1,rs2 <br> sltu rd,Z,rd |
| sge rd,rs1,rs2        | Set if greater or equal signed        | slt rd,rs1,rs2 <br> xori rd,rd,1 |
| sgeu rd,rs1,rs2       | Set if greater or equal unsigned      | sltu rd,rs1,rs2 <br> xori rd,rd,1 |
| sgt rd,rs1,rs2        | Set if greater than signed            | slt rd,rs2,rs1 |
| sgtu rd,rs1,rs2       | Set if greater than unsigned          | sltu rd,rs2,rs1 |
| sle rd,rs1,rs2        | Set if less than or equal signed      | slt rd,rs2,rs1 <br> xori rd,rd,1 |
| sleu rd,rs1,rs2       | Set if less than or equal unsigned    | sltu rd,rs2,rs1 <br> xori rd,rd,1 |
| beqz rs1,offset       | Branch if equal to zero               | beq rs1,Z,offset |
| bnez rs1,offset       | Branch if not equal to zero           | bne rs1,Z,offset |
| blez rs1,offset       | Branch if less or equal to zero       | bge Z,rs1,offset |
| bgez rs1,offset       | Branch if greater or equal to zero    | bge rs1,Z,offset |
| bltz rs1,offset       | Branch if less than zero              | blt rs1,Z,offset |
| bgtz rs1,offset       | Branch if greater than zero           | blt Z,rs1,offset |
| bgt rs1,rs2,offset    | Branch if greater than signed         | blt rs2,rs1,offset |
| ble rs1,rs2,offset    | Branch if less or equal to signed     | bge rs2,rs1,offset |
| bgtu rs1,rs2,offset   | Branch if greater than signed         | bltu rs2,rs1,offset |
| bleu rs1,rs2,offset   | Branch if less or equal to signed     | bgeu rs2,rs1,offset |
| j offset              | Jump                                  | jal Z,offset |
| jr rs1,offset         | Jump register                         | jalr Z,rs1,offset |
| call rd,address       | Call subroutine                       | auipc rd,address[pcrel_hi] <br> jalr rd,rd,address[pcrel_near_lo] |
| ret rs1               | Return from subroutine                | jalr Z,rs1 |
| ecalli rd,rs1,extid   | Extension call immediate              | lui rd,extid[hi] <br> ecall rd,rs1,rd,extid[lo] |
