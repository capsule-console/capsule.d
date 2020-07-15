module capsule.dynarec.x86.encode;

private:

import capsule.dynarec.x86.instruction : X86Instruction;
import capsule.dynarec.x86.instruction : X86InstructionMemoryAddressModeMod;
import capsule.dynarec.x86.opcode : X86Opcode;
import capsule.dynarec.x86.opcode : X86OpcodeEscape, X86OpcodeEscapeList;
import capsule.dynarec.x86.register : X86Register, X86SegmentRegister;;
import capsule.dynarec.x86.register : X86RegisterIsExtended, X86RegisterIsByteHigh;
import capsule.dynarec.x86.size : X86DisplacementSize, X86ImmediateSize;

public pure nothrow @safe @nogc:

enum X86EncoderMode: ubyte {
    None = 0,
    Legacy,
    Long,
}

enum X86EncodeLockPrefix: ubyte {
    /// No lock prefix byte
    None = 0x00,
    /// LOCK
    Lock = 0xf0,
    /// REPZ
    RepeatZ = 0xf3,
    /// REPNZ
    RepeatNZ = 0xf2,
}

shared immutable X86EncodeLockPrefix[4] X86LockPrefixList = [
    X86EncodeLockPrefix.None,
    X86EncodeLockPrefix.Lock,
    X86EncodeLockPrefix.RepeatZ,
    X86EncodeLockPrefix.RepeatNZ,
];

enum X86SegmentOverridePrefix: ubyte {
    None = 0x00,
    CSSegmentOverride = 0x2e,
    SSSegmentOverride = 0x36,
    DSSegmentOverride = 0x3e,
    ESSegmentOverride = 0x26,
    FSSegmentOverride = 0x64,
    GSSegmentOverride = 0x65,
    BranchNotTaken = 0x2e,
    BranchTaken = 0x3e,
}

X86SegmentOverridePrefix X86SegmentOverridePrefixForRegister(
    in X86SegmentRegister register
) {
    alias Prefix = X86SegmentOverridePrefix;
    alias Register = X86SegmentRegister;
    final switch(register) {
        case Register.es: return Prefix.ESSegmentOverride;
        case Register.cs: return Prefix.CSSegmentOverride;
        case Register.ss: return Prefix.SSSegmentOverride;
        case Register.ds: return Prefix.DSSegmentOverride;
        case Register.fs: return Prefix.FSSegmentOverride;
        case Register.gs: return Prefix.GSSegmentOverride;
    }
}

enum X86EncodeInstructionStatus: ubyte {
    // Instruction was encoded without a problem
    Ok = 0,
    /// Instruction was not valid
    Invalid,
    /// Instruction cannot be encoded in this mode
    ModeError,
    ///
    AddressSizeError,
}

struct X86EncodeInstruction {
    alias Instruction = X86Instruction;
    alias LockPrefix = X86EncodeLockPrefix;
    alias LockPrefixList = X86LockPrefixList;
    alias Mode = X86EncoderMode;
    alias SegmentOverridePrefix = X86SegmentOverridePrefix;
    alias Status = X86EncodeInstructionStatus;
    
    static enum ubyte OperandSizeOverridePrefix = 0x66;
    static enum ubyte AddressSizeOverridePrefix = 0x67;
    
    pure nothrow @safe @nogc:
    
    align(2):
    ubyte[2] opcodeEscape;
    align(1):
    LockPrefix lockPrefix;
    SegmentOverridePrefix segmentOverridePrefix;
    ubyte addressSizeOverridePrefix;
    ubyte operandSizeOverridePrefix;
    ubyte rexPrefix;
    ubyte opcode;
    ubyte modRMByte;
    ubyte sibByte;
    
    bool hasLockPrefix() const {
        return this.lockPrefix !is LockPrefix.None;
    }
    
    bool hasSegmentOverridePrefix() const {
        return this.segmentOverridePrefix !is SegmentOverridePrefix.None;
    }
    
    bool hasOperandSizeOverridePrefix() const {
        return this.operandSizeOverridePrefix != 0;
    }
    
    bool hasAddressSizeOverridePrefix() const {
        return this.addressSizeOverridePrefix != 0;
    }
    
    bool hasREXPrefix() const {
        return (this.rexPrefix & 0xf) != 0;
    }
    
    bool hasSIBByte(in Instruction instruction) const {
        return instruction.hasMemoryAddress && ((this.modRMByte & 0x7) == 0x4);
    }
    
    Status encode(in Mode mode, in Instruction instruction) {
        // Check that the instruction is valid
        assert(mode !is Mode.None);
        if(instruction.status !is Instruction.Status.Ok ||
            instruction.opcode is null
        ) {
            return Status.Invalid;
        }
        // Check that the opcode is allowed in the given mode
        if((!instruction.opcode.validInLongMode && mode is Mode.Long) ||
            (!instruction.opcode.validInLegacyMode && mode is Mode.Legacy)
        ) {
            return Status.ModeError;
        }
        // Handle the operand size override prefix byte
        // Assumes legacy is 32-bit mode, as opposed to 16-bit (CS.d == 1)
        const operandSize = instruction.getOperandSize;
        this.operandSizeOverridePrefix = (operandSize == 16 ?
            OperandSizeOverridePrefix : 0x00
        );
        if(mode is Mode.Legacy && operandSize == 64) {
            return Status.ModeError;
        }
        // Lock prefix byte (LOCK/REPZ/REPNZ)
        const lockPrefix = instruction.opcode.getLockPrefix;
        if(lockPrefix !is X86Opcode.LockPrefix.None) {
            assert(lockPrefix < LockPrefixList.length);
            this.lockPrefix = LockPrefixList[lockPrefix];
        }
        // Segment override prefix byte
        if(instruction.hasSegmentOverride) {
            this.segmentOverridePrefix = (
                X86SegmentOverridePrefixForRegister(instruction.segmentRegister)
            );
        }
        // Initialize REX byte - later logic may set additional flags
        this.rexPrefix = (instruction.opcode.hasRexW ? 0x48 : 0x40);
        // Handle memory address operand related things:
        // Set the address size override prefix byte if needed.
        // Set some information in the ModR/M byte and the REX byte.
        // Set the SIB byte, if necessary.
        if(instruction.hasMemoryAddress) {
            // Handle address size override prefix
            const addressSize = instruction.getMemoryAddressSize;
            if(mode is Mode.Legacy) {
                // Assumes 32-bit mode, as opposed to 16-bit (CS.d == 1)
                if(addressSize == 64) {
                    return Status.ModeError;
                }
                else if(addressSize != 16 && addressSize != 32) {
                    return Status.AddressSizeError;
                }
                this.addressSizeOverridePrefix = (addressSize == 16 ?
                    AddressSizeOverridePrefix : 0x00
                );
            }
            else if(mode is Mode.Long) {
                if(addressSize == 16) {
                    return Status.ModeError;
                }
                else if(addressSize != 32 && addressSize != 64) {
                    return Status.AddressSizeError;
                }
                this.addressSizeOverridePrefix = (addressSize == 32 ?
                    AddressSizeOverridePrefix : 0x00
                );
            }
            // Handle the ModR/M byte's mod field
            this.modRMByte = cast(ubyte) (X86InstructionMemoryAddressModeMod(
                instruction.rmMemoryAddress.mode
            ) << 6);
            // Handle REX and SIB bytes and the ModR/M byte's r/m field
            if(instruction.rmMemoryAddress.hasIndex) {
                assert(instruction.rmMemoryAddress.scale <= 0x3);
                this.sibByte = cast(ubyte) (
                    ((instruction.rmMemoryAddress.scale) << 6) |
                    ((instruction.rmMemoryAddress.index & 0x7) << 3)
                );
                this.rexPrefix |= (
                    X86RegisterIsExtended(instruction.rmMemoryAddress.index) ?
                    0x2 : 0
                );
            }
            else {
                this.sibByte |= X86Register.rsp << 3;
            }
            if(instruction.rmMemoryAddress.hasBase) {
                this.modRMByte |= (instruction.rmMemoryAddress.base & 0x7);
                this.sibByte |= (instruction.rmMemoryAddress.base & 0x7);
                this.rexPrefix |= (
                    X86RegisterIsExtended(instruction.rmMemoryAddress.base) ?
                    0x1 : 0
                );
            }
            else {
                this.modRMByte |= 0x4;
                this.sibByte |= X86Register.rbp;
            }
        }
        // Handle r/m field of ModR/M byte for register operands
        else if(instruction.hasRMRegister) {
            this.modRMByte = cast(ubyte) (instruction.rmRegister & 0x7);
            this.rexPrefix |= X86RegisterIsExtended(instruction.rmRegister) ? 0x1 : 0;
        }
        // Handle reg field of ModR/M byte
        // Because of the X86Instruction type's union of its
        // register and segmentRegister fields, this will correctly set the
        // reg field for either an r8/r16/r32/r64 or Sreg operand.
        assert(instruction.register == 0 ||
            instruction.hasRegRegister || instruction.hasSegmentRegister
        );
        this.modRMByte |= cast(ubyte) ((instruction.register & 0x7) << 3);
        // Opcode
        this.opcode = instruction.opcode.opcode;
        if(instruction.opcode.addRegToOpcode) {
            this.opcode += instruction.register & 0x7;
        }
        // Opcode escape bytes 1 & 2
        const escape = instruction.opcode.getOpcodeEscape;
        if(escape) {
            assert(escape < X86OpcodeEscapeList.length);
            const escapeWord = X86OpcodeEscapeList[escape];
            this.opcodeEscape[0] = cast(ubyte) (escapeWord >> 8);
            this.opcodeEscape[1] = cast(ubyte) (escapeWord);
        }
        // Check for illegal combination of REX prefix and a
        // AH/CH/DH/BH register
        if((this.rexPrefix & 0xf) != 0 &&
            X86RegisterIsByteHigh(instruction.register) ||
            (instruction.hasRMRegister &&
                X86RegisterIsByteHigh(instruction.rmRegister)
            )
        ) {
            return Status.Invalid;
        }
        // All done
        return Status.Ok;
    }
}

struct X86Encoder {
    alias Instruction = X86Instruction;
    alias LockPrefix = X86EncodeLockPrefix;
    alias Mode = X86EncoderMode;
    alias Opcode = X86Opcode;
    
    Mode mode;
    ubyte* buffer = null;
    uint bufferLength = 0;
    uint length = 0;
    
    pure nothrow @safe @nogc:
    
    @trusted this(in Mode mode, ubyte[] buffer) {
        this(mode, buffer.ptr, cast(uint) buffer.length);
    }
    
    this(in Mode mode, ubyte* buffer, in uint bufferLength) {
        assert(mode !is Mode.None);
        assert(buffer !is null);
        this.mode = mode;
        this.buffer = buffer;
        this.bufferLength = bufferLength;
    }
    
    @trusted void pushByte(in ubyte value) {
        assert(this.buffer !is null);
        assert(this.length < this.bufferLength);
        this.buffer[this.length++] = value;
    }
    
    @trusted void pushWord(in ushort value) {
        assert(this.buffer !is null);
        assert(2 + this.length <= this.bufferLength);
        this.buffer[this.length++] = cast(ubyte) (value);
        this.buffer[this.length++] = cast(ubyte) (value >> 8);
    }
    
    @trusted void pushDWord(in uint value) {
        assert(this.buffer !is null);
        assert(4 + this.length <= this.bufferLength);
        this.buffer[this.length++] = cast(ubyte) (value);
        this.buffer[this.length++] = cast(ubyte) (value >> 8);
        this.buffer[this.length++] = cast(ubyte) (value >> 16);
        this.buffer[this.length++] = cast(ubyte) (value >> 24);
    }
    
    @trusted void pushQWord(in ulong value) {
        assert(this.buffer !is null);
        assert(8 + this.length <= this.bufferLength);
        this.buffer[this.length++] = cast(ubyte) (value);
        this.buffer[this.length++] = cast(ubyte) (value >> 8);
        this.buffer[this.length++] = cast(ubyte) (value >> 16);
        this.buffer[this.length++] = cast(ubyte) (value >> 24);
        this.buffer[this.length++] = cast(ubyte) (value >> 32);
        this.buffer[this.length++] = cast(ubyte) (value >> 40);
        this.buffer[this.length++] = cast(ubyte) (value >> 48);
        this.buffer[this.length++] = cast(ubyte) (value >> 56);
    }
    
    X86EncodeInstructionStatus pushInstruction(in Instruction instruction) {
        assert(this.buffer !is null);
        assert(this.length < this.bufferLength);
        assert(this.mode !is Mode.None);
        // Use X86EncodeInstruction to do the heavy lifting
        X86EncodeInstruction encode;
        const encodeStatus = encode.encode(this.mode, instruction);
        if(encodeStatus !is X86EncodeInstructionStatus.Ok) {
            return encodeStatus;
        }
        assert(instruction.ok);
        assert(instruction.opcode !is null);
        // Lock prefix byte (LOCK/REPZ/REPNZ)
        if(encode.hasLockPrefix) {
            this.pushByte(encode.lockPrefix);
        }
        // Segment override prefix byte
        if(encode.hasSegmentOverridePrefix) {
            this.pushByte(encode.segmentOverridePrefix);
        }
        // Address size override prefix byte
        if(encode.hasOperandSizeOverridePrefix) {
            this.pushByte(encode.operandSizeOverridePrefix);
        }
        // Operand size override prefix byte
        if(encode.hasAddressSizeOverridePrefix) {
            this.pushByte(encode.addressSizeOverridePrefix);
        }
        // REX byte
        if(encode.hasREXPrefix) {
            this.pushByte(encode.rexPrefix);
        }
        // Opcode escape bytes 1 & 2
        if(encode.opcodeEscape[0] != 0x00) {
            this.pushByte(encode.opcodeEscape[0]);
        }
        if(encode.opcodeEscape[1] != 0x00) {
            this.pushByte(encode.opcodeEscape[1]);
        }
        // Opcode
        if(true) {
            this.pushByte(encode.opcode);
        }
        // ModR/M byte
        if(instruction.opcode.hasModRMByte) {
            this.pushByte(encode.modRMByte);
        }
        // SIB byte
        if(encode.hasSIBByte(instruction)) {
            this.pushByte(encode.sibByte);
        }
        // Displacement
        const displacement = instruction.rmMemoryAddress.displacement;
        final switch(instruction.getDisplacementSize) {
            case X86DisplacementSize.None:
                break;
            case X86DisplacementSize.Byte:
                this.pushByte(cast(ubyte) displacement);
                break;
            case X86DisplacementSize.Word:
                assert(false, "Invalid displacement size.");
            case X86DisplacementSize.DWord:
                this.pushDWord(cast(uint) displacement);
                break;
            case X86DisplacementSize.QWord:
                assert(false, "Invalid displacement size.");
        }
        // Immediate
        final switch(instruction.getImmediateSize) {
            case X86ImmediateSize.None:
                break;
            case X86ImmediateSize.Byte:
                this.pushByte(cast(ubyte) instruction.immediate);
                break;
            case X86ImmediateSize.Word:
                this.pushWord(cast(ushort) instruction.immediate);
                break;
            case X86ImmediateSize.DWord:
                this.pushDWord(cast(uint) instruction.immediate);
                break;
            case X86ImmediateSize.QWord:
                this.pushQWord(cast(ulong) instruction.immediate);
                break;
        }
        // All done
        return X86EncodeInstructionStatus.Ok;
    }
}
