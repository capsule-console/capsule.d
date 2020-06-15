# Capsule Assembly Instruction Listing

Here is a list of all the instructions recognized by the Capsule assembler
and runtime in a brief and condensed format.

Note the following abbreviations:

- rd, meaning the destination register.
- rs1, meaning the first source register.
- rs2, meaning the second source register.
- imm, meaning an immediate value.
- i32 meaning the immediate value, sign-extended to 32 bits.
- m8[x], meaning a signed-extended byte in memory at address x.
- mu8[x], meaning a zero-extended byte in memory at address x.
- m16[x], meaning a signed-extended half word in memory in memory at address x.
- mu16[x], meaning a zero-extended half word in memory in memory at address x.
- m32[x], meaning a word in memory in memory at address x.

## Instructions

| Code | Mnemonic               | Name                                      | Operation |
| ---- | ---------------------- | ----------------------------------------- | --------- |
| 0x00 | \-                     | Missing or invalid instruction            | \- |
| 0x01 | \-                     | _Reserved_                                | \- |
| 0x02 | \-                     | _Reserved_                                | \- |
| 0x03 | \-                     | _Reserved_                                | \- |
| 0x04 | and rd,rs1,rs2         | Bitwise AND                               | rd = rs1 AND rs2 |
| 0x05 | andi rd,rs1,imm        | Bitwise AND immediate                     | rd = rs1 AND i32 |
| 0x06 | or rd,rs1,rs2          | Bitwise OR                                | rd = rs1 OR rs2 |
| 0x07 | ori rd,rs1,imm         | Bitwise OR immediate                      | rd = rs1 OR i32 |
| 0x08 | xor rd,rs1,rs2         | Bitwise XOR                               | rd = rs1 XOR rs2 |
| 0x09 | xori rd,rs1,imm        | Bitwise XOR immediate                     | rd = rs1 XOR i32 |
| 0x0a | \-                     | _Reserved_                                | \- |
| 0x0b | \-                     | _Reserved_                                | \- |
| 0x0c | \-                     | _Reserved_                                | \- |
| 0x0d | sll rd,rs1,rs2,imm     | Shift logical left                        | rd = (rs1 << (i32 & 0x1F)) << (rs2 & 0x1F) |
| 0x0e | srl rd,rs1,rs2,imm     | Shift logical right                       | rd = (rs1 >>> (i32 & 0x1F)) >>> (rs2 & 0x1F) |
| 0x0f | sra rd,rs1,rs2,imm     | Shift arithmetic right                    | rd = (rs1 >> (i32 & 0x1F)) >> (rs2 & 0x1F) |
| 0x10 | min rd,rs1,rs2         | Set to minimum                            | rd = rs1 < rs2 ? rs1 : rs2 |
| 0x11 | minu rd,rs1,rs2        | Set to minimum unsigned                   | rd = rs1 < rs2 ? rs1 : rs2 |
| 0x12 | max rd,rs1,rs2         | Set to maximum                            | rd = rs1 >= rs2 ? rs1 : rs2 |
| 0x13 | maxu rd,rs1,rs2        | Set to maximum unsigned                   | rd = rs1 >= rs2 ? rs1 : rs2 |
| 0x14 | slt rd,rs1,rs2         | Set if less than                          | rd = rs1 < rs2 ? 1 : 0 |
| 0x15 | sltu rd,rs1,rs2        | Set if less than unsigned                 | rd = rs1 < rs2 ? 1 : 0 |
| 0x16 | slti rd,rs1,imm        | Set if less than immediate                | rd = rs1 < i32 ? 1 : 0 |
| 0x17 | sltiu rd,rs1,imm       | Set if less than immediate unsigned       | rd = rs1 < i32 ? 1 : 0 |
| 0x18 | add rd,rs1,rs2,imm     | Add                                       | rd = rs1 + rs2 + i32 |
| 0x19 | sub rd,rs1,rs2         | Subtract                                  | rd = rs1 - rs2 |
| 0x1a | lui rd,imm             | Load upper immediate                      | rd = i32 << 16 |
| 0x1b | auipc rd,imm           | Add upper immediate to program counter    | rd = PC + (i32 << 16) |
| 0x1c | mul rd,rs1,rs2         | Multiply and truncate                     | rd = (rs1 * rs2) & 0x00000000FFFFFFFF |
| 0x1d | mulh rd,rs1,rs2        | Multiply signed and shift                 | rd = (rs1 * rs2) >> 32 |
| 0x1e | mulhu rd,rs1,rs2       | Multiply unsigned and shift               | rd = (rs1 * rs2) >> 32 |
| 0x1f | mulhsu rd,rs1,rs2      | Multiply signed by unsigned and shift     | rd = (rs1 * rs2) >> 32 |
| 0x20 | div rd,rs1,rs2         | Divide                                    | rd = rs2 == 0 ? 0 : rs1 / rs2 |
| 0x21 | divu rd,rs1,rs2        | Divide unsigned                           | rd = rs2 == 0 ? 0 : rs1 / rs2 |
| 0x22 | rem rd,rs1,rs2         | Remainder                                 | rd = rs2 == 0 ? 0 : rs1 % rs2 |
| 0x23 | remu rd,rs1,rs2        | Remainder unsigned                        | rd = rs2 == 0 ? 0 : rs1 % rs2 |
| 0x24 | revb rd,rs1            | Reverse byte order                        | rd = revb(rs1) |
| 0x25 | revh rd,rs1            | Reverse half word order                   | rd = revh(rs1) |
| 0x26 | \-                     | _Reserved_                                | \- |
| 0x27 | \-                     | _Reserved_                                | \- |
| 0x28 | \-                     | _Reserved_                                | \- |
| 0x29 | clz rd,rs1             | Count leading zeros                       | rd = clz(rs1) |
| 0x2a | ctz rd,rs1             | Count trailing zeros                      | rd = ctz(rs1) |
| 0x2b | pcnt rd,rs1            | Count set bits                            | rd = pcnt(rs1) |
| 0x2c | lb rd,rs1,imm          | Load sign-extended byte                   | rd = m8[rs1 + i32] |
| 0x2d | lbu rd,rs1,imm         | Load zero-extended byte                   | rd = mu8[rs1 + i32] |
| 0x2e | lh rd,rs1,imm          | Load sign-extended half word              | rd = m16[(rs1 + i32)] |
| 0x2f | lhu rd,rs1,imm         | Load zero-extended half word              | rd = mu16[(rs1 + i32)] |
| 0x30 | lw rd,rs1,imm          | Load word                                 | rd = m32[(rs1 + i32)] |
| 0x31 | sb rs1,rs2,imm         | Store byte                                | m8[rs2 + i32] = rs1 |
| 0x32 | sh rs1,rs2,imm         | Store half word                           | m16[(rs2 + i32)] = rs1 |
| 0x33 | sw rs1,rs2,imm         | Store word                                | m32[(rs2 + i32)] = rs1 |
| 0x34 | jal rd,imm             | Jump and link                             | rd = PC + 4, PC = (PC + i32) |
| 0x35 | jalr rd,rs1,imm        | Jump and link register                    | rd = PC + 4, PC = (rs1 + i32) |
| 0x36 | beq rs1,rs2,imm        | Branch if equal                           | if rs1 == rs2: PC = PC + (i32) |
| 0x37 | bne rs1,rs2,imm        | Branch if not equal                       | if rs1 != rs2: PC = PC + (i32) |
| 0x38 | blt rs1,rs2,imm        | Branch if less than signed                | if rs1 < rs2: PC = PC + (i32) |
| 0x39 | bltu rs1,rs2,imm       | Branch if less than unsigned              | if rs1 < rs2: PC = PC + (i32) |
| 0x3a | bge rs1,rs2,imm        | Branch if greater or equal signed         | if rs1 >= rs2: PC = PC + (i32) |
| 0x3b | bgeu rs1,rs2,imm       | Branch if greater or equal unsigned       | if rs1 >= rs2: PC = PC + (i32) |
| 0x3c | ecall rd,rs1,rs2,imm   | Call extension                            | rd = ecall(extid: rs2 + i32, input: rs1) |
| 0x3d | ebreak                 | Breakpoint                                | Reserved for debugging tools to represent a breakpoint |
| 0x3e | \-                     | _Reserved_                                | \- |
| 0x3f | \-                     | _Reserved_                                | \- |
| 0x40 | \-                     | _Reserved_, and so on through 0x7F.       | \- |

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
| sba rs1,address       | Store byte to address                 | auipc rd,address[pcrel_hi] <br> sb rd,rd,rs1,address[pcrel_near_lo] |
| sha rs1,address       | Store half word to address            | auipc rd,address[pcrel_hi] <br> sh rd,rd,rs1,address[pcrel_near_lo] |
| swa rs1,address       | Store word to address                 | auipc rd,address[pcrel_hi] <br> sw rd,rd,rs1,address[pcrel_near_lo] |
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
