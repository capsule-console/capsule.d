/**

This module implements a virtual machine for executing Capsule bytecode.

*/

module capsule.core.engine;

private:

import capsule.bits.clz : clz;
import capsule.bits.ctz : ctz;
import capsule.bits.pcnt : pcnt;

import capsule.core.exception : CapsuleExceptionCode;
import capsule.core.exception : getCapsuleExceptionDescription;
import capsule.core.instruction : CapsuleInstruction;
import capsule.core.memory : CapsuleMemory;
import capsule.core.opcode : CapsuleOpcode;
import capsule.core.register : CapsuleRegister;

public:

alias CapsuleExtensionCallHandler = CapsuleExtensionCallResult function(
    void* data, CapsuleEngine* engine, in uint id, in uint arg
);

enum CapsuleEngineStatus: uint {
    /// Program is invalid or awaiting initialization
    None = 0,
    /// Program has been initialized but not yet started
    Initialized = 1,
    /// Program is running or in progress
    Running = 2,
    /// Program is temporarily paused or halted
    Suspended = 3,
    /// Program successfully finished execution (meta.exit_ok)
    ExitOk = 4,
    /// Program successfully finished execution (meta.exit_error)
    ExitError = 5,
    /// Program quit abnormally or due to an error
    Aborted = 6,
    /// Program forced to quit by an external process
    Terminated = 7,
}

struct CapsuleExtensionCallResult {
    nothrow @safe @nogc:
    
    alias ExceptionCode = CapsuleExceptionCode;
    
    static enum Error = typeof(this).Exception(ExceptionCode.ExtensionError);
    static enum Missing = typeof(this).Exception(ExceptionCode.ExtensionMissing);
    
    uint value = 0;
    CapsuleExceptionCode exc = ExceptionCode.None;
    
    static typeof(this) Ok(in uint value) {
        return typeof(this)(value, ExceptionCode.None);
    }
    
    static typeof(this) Exception(in ExceptionCode exc) {
        return typeof(this)(0, exc);
    }
    
    bool ok() const {
        return this.exc is ExceptionCode.None;
    }
}

/// Engine or "virtual machine" for executing a Capsule program.
struct CapsuleEngine {
    alias Memory = CapsuleMemory;
    
    alias ExceptionCode = CapsuleExceptionCode;
    alias ExtensionCallHandler = CapsuleExtensionCallHandler;
    alias Instruction = CapsuleInstruction;
    alias IntervalCallback = void function(void* data, CapsuleEngine* engine);
    alias Opcode = CapsuleOpcode;
    alias Register = CapsuleRegister;
    alias Status = CapsuleEngineStatus;
    
    /// Current program status
    Status status = Status.None;
    /// Handles load and store instructions
    Memory mem = Memory.init;
    /// Handles extension calls (ecall instructions)
    ExtensionCallHandler ecall = null;
    /// Data pointer passed to extension call handler
    void* ecallData = null;
    /// Most recent extension call ID
    uint ecallId = uint.max;
    /// Program counter at execution start
    int entry = 0;
    /// Program counter
    int pc = 0;
    /// Registers Z, A, B, C, R, S, X, Y
    int[8] reg;
    /// The most recently executed instruction
    Instruction instr;
    /// Status of the most recent attempt to load an instruction
    Memory.Status instrStatus = Memory.Status.Ok;
    /// Exception code indicating the reason for a fatal error
    ExceptionCode exception = ExceptionCode.None;
    
    /// Record the total number of executed instructions.
    ulong totalExecCount = 0;
    /// Record the number of times any given opcode was executed so far.
    ulong[128] opExecCount;
    /// Determines how often to invoke the intervalCallback.
    /// When totalExecCount & intervalCallbackMask == 0,
    /// the callback will be invoked.
    uint intervalCallbackMask = 0;
    /// Arbitrary user data to be passed to the interval callback function.
    void* intervalCallbackData = null;
    /// A callback that may be called once per every N instructions.
    IntervalCallback intervalCallback = null;
    
    void initialize(
        Memory mem, ExtensionCallHandler ecall, void* ecallData = null
    ) nothrow @safe @nogc {
        this.status = Status.Initialized;
        this.mem = mem;
        this.ecall = ecall;
        this.ecallData = ecallData;
    }
    
    /// Set status to Running
    bool begin(in int entry) nothrow @safe @nogc {
        if(!this.ok || entry < 0 || entry >= this.mem.length) {
            return false;
        }
        this.pc = entry;
        this.entry = entry;
        this.status = Status.Running;
        return true;
    }
    
    bool ok() const nothrow @safe @nogc {
        return this.mem.ok && this.ecall !is null && (
            this.status !is Status.None &&
            this.status !is Status.Aborted &&
            this.status !is Status.Terminated
        );
    }
    
    void setException(in CapsuleExceptionCode exception) nothrow @safe @nogc {
        this.exception = exception;
        this.status = Status.Aborted;
    }
    
    /// Set the full value of a register
    pragma(inline, true) void rset(T)(
        in uint register, in T value
    ) nothrow @safe @nogc {
        assert(register < this.reg.length);
        if(register !is Register.Z) {
            this.reg[register] = cast(uint) value;
        }
    }
    
    /// Get the value of a register
    pragma(inline, true) T rget(T = uint)(
        in uint register
    ) nothrow @safe @nogc {
        assert(register < this.reg.length);
        return cast(T) this.reg[register];
    }
    
    /// Get the value of a register as a signed integer
    alias ri = rget!int;
    /// Get the value of a register as an usigned integer
    alias ru = rget!uint;
    
    /// Decode and record the instruction under the PC
    alias next = typeof(this).operate!(true, false, false);
    
    /// Execute a single instruction
    alias exec = typeof(this).operate!(false, true, false);
    
    /// Update VM metrics and invoke an interval callback, if applicable
    alias metrics = typeof(this).operate!(false, false, true);
    
    /// Execute a single instruction, then update metrics
    alias execMetrics = typeof(this).operate!(false, true, true);
    
    /// Decode and execute the instruction under the PC
    alias step = typeof(this).operate!(true, true, false);
    
    /// Decode and execute the instruction under the PC, then update metrics
    alias stepMetrics = typeof(this).operate!(true, true, true);
    
    // before - 32998572 (32 MHz)
    // move instr load status switch - 32653218 (32 MHz)
    // improve address range check -  32989412 (32 MHz)
    void operate(
        bool nextInstruction, bool execInstruction, bool updateMetrics
    )() @trusted {
        static if(nextInstruction) {
            const idata = this.mem.loadInstructionWord(this.pc);
            this.instrStatus = idata.status;
            this.instr = Instruction(idata.value);
        }
        static if(execInstruction) {
            alias i = this.instr;
            switch(i.opcode) {
                case Opcode.And:
                    rset(i.rd, ru(i.rs1) & ru(i.rs2));
                    pc += 4;
                    break;
                case Opcode.AndImmediate:
                    rset(i.rd, ru(i.rs1) & i.imm32);
                    pc += 4;
                    break;
                case Opcode.Or:
                    rset(i.rd, ru(i.rs1) | ru(i.rs2));
                    pc += 4;
                    break;
                case Opcode.OrImmediate:
                    rset(i.rd, ru(i.rs1) | i.imm32);
                    pc += 4;
                    break;
                case Opcode.Xor:
                    rset(i.rd, ru(i.rs1) ^ ru(i.rs2));
                    pc += 4;
                    break;
                case Opcode.XorImmediate:
                    rset(i.rd, ru(i.rs1) ^ i.imm32);
                    pc += 4;
                    break;
                case Opcode.ShiftLeftLogical:
                    rset(i.rd, (ri(i.rs1) << (i.imm32 & 0x1f)) << (ru(i.rs2) & 0x1f));
                    pc += 4;
                    break;
                case Opcode.ShiftRightLogical:
                    rset(i.rd, (ri(i.rs1) >>> (i.imm32 & 0x1f)) >>> (ru(i.rs2) & 0x1f));
                    pc += 4;
                    break;
                case Opcode.ShiftRightArithmetic:
                    rset(i.rd, (ri(i.rs1) >> (i.imm32 & 0x1f)) >> (ru(i.rs2) & 0x1f));
                    pc += 4;
                    break;
                case Opcode.SetMinimumSigned:
                    const int left = ri(i.rs1);
                    const int right = ri(i.rs2);
                    rset(i.rd, left < right ? left : right);
                    pc += 4;
                    break;
                case Opcode.SetMinimumUnsigned:
                    const uint left = ru(i.rs1);
                    const uint right = ru(i.rs2);
                    rset(i.rd, left < right ? left : right);
                    pc += 4;
                    break;
                case Opcode.SetMaximumSigned:
                    const int left = ri(i.rs1);
                    const int right = ri(i.rs2);
                    rset(i.rd, left >= right ? left : right);
                    pc += 4;
                    break;
                case Opcode.SetMaximumUnsigned:
                    const uint left = ru(i.rs1);
                    const uint right = ru(i.rs2);
                    rset(i.rd, left >= right ? left : right);
                    pc += 4;
                    break;
                case Opcode.SetLessThanSigned:
                    rset(i.rd, ri(i.rs1) < ri(i.rs2) ? 1 : 0);
                    pc += 4;
                    break;
                case Opcode.SetLessThanUnsigned:
                    rset(i.rd, ru(i.rs1) < ru(i.rs2) ? 1 : 0);
                    pc += 4;
                    break;
                case Opcode.SetLessThanImmediateSigned:
                    rset(i.rd, ri(i.rs1) < i.imm32 ? 1 : 0);
                    pc += 4;
                    break;
                case Opcode.SetLessThanImmediateUnsigned:
                    rset(i.rd, ru(i.rs1) < cast(uint) i.imm32 ? 1 : 0);
                    pc += 4;
                    break;
                case Opcode.Add:
                    rset(i.rd, ri(i.rs1) + ri(i.rs2) + i.imm32);
                    pc += 4;
                    break;
                case Opcode.Subtract:
                    rset(i.rd, ri(i.rs1) - ri(i.rs2));
                    pc += 4;
                    break;
                case Opcode.LoadUpperImmediate:
                    rset(i.rd, i.imm32 << 16);
                    pc += 4;
                    break;
                case Opcode.AddUpperImmediateToPC:
                    rset(i.rd, pc + (i.imm32 << 16));
                    pc += 4;
                    break;
                case Opcode.MultiplyAndTruncate:
                    rset(i.rd, ru(i.rs1) * ru(i.rs2));
                    pc += 4;
                    break;
                case Opcode.MultiplySignedAndShift:
                    const product = rget!long(i.rs1) * rget!long(i.rs2);
                    rset(i.rd, cast(uint) (product >>> 32));
                    pc += 4;
                    break;
                case Opcode.MultiplyUnsignedAndShift:
                    const product = rget!ulong(i.rs1) * rget!ulong(i.rs2);
                    rset(i.rd, cast(uint) (product >>> 32));
                    pc += 4;
                    break;
                case Opcode.MultiplySignedUnsignedAndShift:
                    const product = rget!long(i.rs1) * rget!ulong(i.rs2);
                    rset(i.rd, cast(uint) (product >>> 32));
                    pc += 4;
                    break;
                case Opcode.DivideSigned:
                    const dividend = ri(i.rs1);
                    const divisor = ri(i.rs2);
                    // Inputs that cause D to crash
                    if(divisor == 0) rset(i.rd, -1);
                    // int.min / -1 crashes
                    else if(divisor == -1) rset(i.rd, -dividend);
                    // Everything else
                    else rset(i.rd, dividend / divisor);
                    pc += 4;
                    break;
                case Opcode.DivideUnsigned:
                    const divisor = ru(i.rs2);
                    rset(i.rd, divisor == 0 ? uint.max : ru(i.rs1) / divisor);
                    pc += 4;
                    break;
                case Opcode.RemainderSigned:
                    const dividend = ri(i.rs1);
                    const divisor = ri(i.rs2);
                    // Inputs that cause D to crash
                    if(divisor == 0) rset(i.rd, dividend);
                    // int.min % -1 crashes
                    else if(divisor == -1) rset(i.rd, 0);
                    // Everything else
                    else rset(i.rd, dividend % divisor);
                    pc += 4;
                    break;
                case Opcode.RemainderUnsigned:
                    const dividend = ri(i.rs1);
                    const divisor = ru(i.rs2);
                    rset(i.rd, divisor == 0 ? dividend : dividend % divisor);
                    pc += 4;
                    break;
                case Opcode.ReverseByteOrder:
                    union Bytes {uint u32; ubyte[4] u8;}
                    const b = Bytes(ru(i.rs1)).u8;
                    rset(i.rd, (b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3]);
                    pc += 4;
                    break;
                case Opcode.ReverseHalfWordOrder:
                    const value = ru(i.rs1);
                    rset(i.rd, (value << 16) | (value >>> 16));
                    pc += 4;
                    break;
                case Opcode.CountLeadingZeroes:
                    rset(i.rd, clz(ru(i.rs1)));
                    pc += 4;
                    break;
                case Opcode.CountTrailingZeroes:
                    rset(i.rd, ctz(ru(i.rs1)));
                    pc += 4;
                    break;
                case Opcode.CountSetBits:
                    rset(i.rd, pcnt(ru(i.rs1)));
                    pc += 4;
                    break;
                case Opcode.LoadByteSignExt:
                    const load = this.mem.loadByteSigned(ri(i.rs1) + i.imm32);
                    final switch(load.status) {
                        case Memory.Status.Ok:
                            rset(i.rd, cast(int) load.value);
                            pc += 4;
                            break;
                        case Memory.Status.ReadOnly:
                            assert(false);
                        case Memory.Status.NotExecutable:
                            assert(false);
                        case Memory.Status.Misaligned:
                            this.setException(ExceptionCode.LoadMisaligned);
                            break;
                        case Memory.Status.OutOfBounds:
                            this.setException(ExceptionCode.LoadOutOfBounds);
                            break;
                    }
                    break;
                case Opcode.LoadByteZeroExt:
                    const load = this.mem.loadByteUnsigned(ri(i.rs1) + i.imm32);
                    final switch(load.status) {
                        case Memory.Status.Ok:
                            rset(i.rd, cast(uint) load.value);
                            pc += 4;
                            break;
                        case Memory.Status.ReadOnly:
                            assert(false);
                        case Memory.Status.NotExecutable:
                            assert(false);
                        case Memory.Status.Misaligned:
                            this.setException(ExceptionCode.LoadMisaligned);
                            break;
                        case Memory.Status.OutOfBounds:
                            this.setException(ExceptionCode.LoadOutOfBounds);
                            break;
                    }
                    break;
                case Opcode.LoadHalfWordSignExt:
                    const load = this.mem.loadHalfWordSigned(ri(i.rs1) + i.imm32);
                    final switch(load.status) {
                        case Memory.Status.Ok:
                            rset(i.rd, cast(int) load.value);
                            pc += 4;
                            break;
                        case Memory.Status.ReadOnly:
                            assert(false);
                        case Memory.Status.NotExecutable:
                            assert(false);
                        case Memory.Status.Misaligned:
                            this.setException(ExceptionCode.LoadMisaligned);
                            break;
                        case Memory.Status.OutOfBounds:
                            this.setException(ExceptionCode.LoadOutOfBounds);
                            break;
                    }
                    break;
                case Opcode.LoadHalfWordZeroExt:
                    const load = this.mem.loadHalfWordUnsigned(ri(i.rs1) + i.imm32);
                    final switch(load.status) {
                        case Memory.Status.Ok:
                            rset(i.rd, cast(uint) load.value);
                            pc += 4;
                            break;
                        case Memory.Status.ReadOnly:
                            assert(false);
                        case Memory.Status.NotExecutable:
                            assert(false);
                        case Memory.Status.Misaligned:
                            this.setException(ExceptionCode.LoadMisaligned);
                            break;
                        case Memory.Status.OutOfBounds:
                            this.setException(ExceptionCode.LoadOutOfBounds);
                            break;
                    }
                    break;
                case Opcode.LoadWord:
                    const load = this.mem.loadWord(ri(i.rs1) + i.imm32);
                    final switch(load.status) {
                        case Memory.Status.Ok:
                            rset(i.rd, load.value);
                            pc += 4;
                            break;
                        case Memory.Status.ReadOnly:
                            assert(false);
                        case Memory.Status.NotExecutable:
                            assert(false);
                        case Memory.Status.Misaligned:
                            this.setException(ExceptionCode.LoadMisaligned);
                            break;
                        case Memory.Status.OutOfBounds:
                            this.setException(ExceptionCode.LoadOutOfBounds);
                            break;
                    }
                    break;
                case Opcode.StoreByte:
                    const status = this.mem.storeByte(
                        ri(i.rs1) + i.imm32, cast(ubyte) ru(i.rs2)
                    );
                    final switch(status) {
                        case Memory.Status.Ok:
                            pc += 4;
                            break;
                        case Memory.Status.ReadOnly:
                            this.setException(ExceptionCode.StoreToReadOnly);
                            break;
                        case Memory.Status.NotExecutable:
                            assert(false);
                        case Memory.Status.Misaligned:
                            this.setException(ExceptionCode.StoreMisaligned);
                            break;
                        case Memory.Status.OutOfBounds:
                            this.setException(ExceptionCode.StoreOutOfBounds);
                            break;
                    }
                    break;
                case Opcode.StoreHalfWord:
                    const status = this.mem.storeHalfWord(
                        (ri(i.rs1) + i.imm32), cast(ushort) ru(i.rs2)
                    );
                    final switch(status) {
                        case Memory.Status.Ok:
                            pc += 4;
                            break;
                        case Memory.Status.ReadOnly:
                            this.setException(ExceptionCode.StoreToReadOnly);
                            break;
                        case Memory.Status.NotExecutable:
                            assert(false);
                        case Memory.Status.Misaligned:
                            this.setException(ExceptionCode.StoreMisaligned);
                            break;
                        case Memory.Status.OutOfBounds:
                            this.setException(ExceptionCode.StoreOutOfBounds);
                            break;
                    }
                    break;
                case Opcode.StoreWord:
                    const status = this.mem.storeWord(
                        (ri(i.rs1) + i.imm32), ru(i.rs2)
                    );
                    final switch(status) {
                        case Memory.Status.Ok:
                            pc += 4;
                            break;
                        case Memory.Status.ReadOnly:
                            this.setException(ExceptionCode.StoreToReadOnly);
                            break;
                        case Memory.Status.NotExecutable:
                            assert(false);
                        case Memory.Status.Misaligned:
                            this.setException(ExceptionCode.StoreMisaligned);
                            break;
                        case Memory.Status.OutOfBounds:
                            this.setException(ExceptionCode.StoreOutOfBounds);
                            break;
                    }
                    break;
                case Opcode.JumpAndLink:
                    rset(i.rd, 4 + pc);
                    pc = (i.imm32 + pc);
                    return;
                case Opcode.JumpAndLinkRegister:
                    const next = 4 + pc;
                    pc = (i.imm32 + ri(i.rs1));
                    rset(i.rd, next);
                    return;
                case Opcode.BranchEqual:
                    if(ru(i.rs1) == ru(i.rs2)) pc += i.imm32;
                    else pc += 4;
                    break;
                case Opcode.BranchNotEqual:
                    if(ru(i.rs1) != ru(i.rs2)) pc += i.imm32;
                    else pc += 4;
                    break;
                case Opcode.BranchLessSigned:
                    if(ri(i.rs1) < ri(i.rs2)) pc += i.imm32;
                    else pc += 4;
                    break;
                case Opcode.BranchLessUnsigned:
                    if(ru(i.rs1) < ru(i.rs2)) pc += i.imm32;
                    else pc += 4;
                    break;
                case Opcode.BranchGreaterEqualSigned:
                    if(ri(i.rs1) >= ri(i.rs2)) pc += i.imm32;
                    else pc += 4;
                    break;
                case Opcode.BranchGreaterEqualUnsigned:
                    if(ru(i.rs1) >= ru(i.rs2)) pc += i.imm32;
                    else pc += 4;
                    break;
                case Opcode.ExtensionCall:
                    assert(this.ecall !is null);
                    this.ecallId = ru(i.rs2) + i.imm32;
                    const result = this.ecall(
                        this.ecallData, &this, this.ecallId, ru(i.rs1)
                    );
                    if(result.ok) {
                        rset(i.rd, result.value);
                        pc += 4;
                    }
                    else {
                        this.setException(result.exc);
                    }
                    break;
                case Opcode.Breakpoint:
                    pc += 4;
                    break;
                default: // Unknown opcode, or load failure
                    final switch(this.instrStatus) {
                        case Memory.Status.Ok:
                            this.setException(ExceptionCode.InvalidInstruction);
                            return;
                        case Memory.Status.ReadOnly:
                            assert(false);
                        case Memory.Status.NotExecutable:
                            this.setException(ExceptionCode.PCNotExecutable);
                            return;
                        case Memory.Status.Misaligned:
                            this.setException(ExceptionCode.PCMisaligned);
                            return;
                        case Memory.Status.OutOfBounds:
                            this.setException(ExceptionCode.PCOutOfBounds);
                            return;
                    }
            }
        }
        static if(updateMetrics) {
            assert(this.instr.opcode < this.opExecCount.length);
            this.totalExecCount++;
            this.opExecCount[this.instr.opcode]++;
            if(this.intervalCallback !is null &&
                (this.totalExecCount & this.intervalCallbackMask) == 0
            ) {
                this.intervalCallback(this.intervalCallbackData, &this);
            }
        }
    }
}
