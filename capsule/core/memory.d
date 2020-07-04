/**

This module implements types used by the Capsule virtual machine to handle
loads and stores to memory.

*/

module capsule.core.memory;

private:

import core.stdc.stdlib : free, calloc, realloc;

public:

/// Enumeration of possible memory operation status values.
enum CapsuleMemoryStatus: uint {
    /// Successful read or write
    Ok = 0,
    /// Failure: Tried to write to read-only memory
    ReadOnly,
    /// Failure: Tried to read non-executable memory for execution
    NotExecutable,
    /// Failure: Tried to read or write on a misaligned address
    Misaligned,
    /// Failure: Memory address out of bounds
    OutOfBounds,
}

/// Couples a loaded value from memory with a status indicator.
struct CapsuleMemoryLoad(T) {
    nothrow @safe @nogc:
    
    alias Status = CapsuleMemoryStatus;
    
    static enum ReadOnly = typeof(this)(Status.ReadOnly, 0);
    static enum NotExecutable = typeof(this)(Status.NotExecutable, 0);
    static enum Misaligned = typeof(this)(Status.Misaligned, 0);
    static enum OutOfBounds = typeof(this)(Status.OutOfBounds, 0);
    
    /// The status of the load.
    Status status = Status.Ok;
    /// The loaded value, when the load was successful.
    T value;
    
    static typeof(this) Ok(in T value) {
        return typeof(this)(Status.Ok, value);
    }
    
    /// Returns true if the load status is "Ok".
    bool ok() const {
        return this.status is Status.Ok;
    }
    
    bool opCast(T: bool)() const {
        return this.status is Status.Ok;
    }
}

/// Data structure to represent and manage a Capsule program's memory
/// during execution.
@trusted struct CapsuleMemory {
    nothrow @nogc:
    
    alias Status = CapsuleMemoryStatus;
    alias Load = CapsuleMemoryLoad;
    
    /// Pointer to a memory buffer.
    ubyte* data = null;
    /// Length in bytes of the memory buffer.
    uint length = 0;
    /// Starting address of read-only memory.
    uint romStart = 0;
    /// Ending address of read-only memory.
    uint romEnd = 0;
    /// Starting address of executable memory.
    uint execStart = 0;
    /// Ending address of executable memory.
    uint execEnd = 0;
    /// Starting address of the BSS segment.
    uint bssStart = 0;
    
    bool alloc(in uint length) {
        assert(length <= int.max);
        this.length = length;
        this.data = cast(ubyte*) calloc(length, 1);
        return this.data !is null;
    }
    
    bool realloc(in uint length) {
        assert(length <= int.max);
        this.length = length;
        auto newData = cast(ubyte*) .realloc(this.data, length);
        if(newData !is null) {
            this.data = newData;
            return true;
        }
        else {
            return false;
        }
    }
    
    bool write(in uint offset, in ubyte[] bytes) {
        if(!this.data || cast(size_t) offset + bytes.length > this.length) {
            return false;
        }
        this.data[offset .. offset + bytes.length] = bytes;
        return true;
    }
    
    void free() {
        if(this.data !is null) {
            .free(this.data);
            this.data = null;
        }
    }
    
    bool ok() const {
        return (this.data !is null &&
            this.romStart <= this.romEnd &&
            this.execStart <= this.execEnd
        );
    }
    
    /// Load sign-extended byte
    Load!int loadByteSigned(in int address) const {
        if(address < 0 || address >= this.length) {
            return Load!int.OutOfBounds;
        }
        else {
            const value = cast(byte) (this.data[address]);
            return Load!int.Ok(cast(int) value);
        }
    }
    
    /// Load zero-extended byte
    Load!uint loadByteUnsigned(in int address) const {
        if(address < 0 || address >= this.length) {
            return Load!uint.OutOfBounds;
        }
        else {
            const value = *(cast(ubyte*) &this.data[address]);
            return Load!uint.Ok(cast(uint) value);
        }
    }
    
    /// Load sign-extended half word
    Load!int loadHalfWordSigned(in int address) const {
        if(address < 0 || address >= this.length) {
            return Load!int.OutOfBounds;
        }
        else if(address & 0x1) {
            return Load!int.Misaligned;
        }
        else {
            const value = *(cast(short*) &this.data[address]);
            return Load!int.Ok(cast(int) value);
        }
    }
    
    /// Load zero-extended half word
    Load!uint loadHalfWordUnsigned(in int address) const {
        if(address < 0 || address >= this.length) {
            return Load!uint.OutOfBounds;
        }
        else if(address & 0x1) {
            return Load!uint.Misaligned;
        }
        else {
            const value = *(cast(ushort*) &this.data[address]);
            return Load!uint.Ok(cast(uint) value);
        }
    }
    
    /// Load word
    Load!int loadWord(in int address) const {
        if(address < 0 || address >= this.length) {
            return Load!int.OutOfBounds;
        }
        else if(address & 0x3) {
            return Load!int.Misaligned;
        }
        else {
            const value = *(cast(int*) &this.data[address]);
            return Load!int.Ok(value);
        }
    }
    
    /// Load instruction
    Load!int loadInstructionWord(in int address) const {
        if(address < 0 || address >= this.length) {
            return Load!int.OutOfBounds;
        }
        else if(address & 0x3) {
            return Load!int.Misaligned;
        }
        else if(address < this.execStart || address >= this.execEnd) {
            return Load!int.NotExecutable;
        }
        else {
            const value = *(cast(int*) &this.data[address]);
            return Load!int.Ok(value);
        }
    }
    
    /// Store byte
    Status storeByte(in int address, in ubyte value) {
        if(address < 0 || address >= this.length) {
            return Status.OutOfBounds;
        }
        else if(address >= this.romStart && address < this.romEnd) {
            return Status.ReadOnly;
        }
        else {
            this.data[address] = value;
            return Status.Ok;
        }
    }
    
    /// Store half word
    Status storeHalfWord(in int address, in ushort value) {
        if(address < 0 || address >= this.length) {
            return Status.OutOfBounds;
        }
        else if(address & 0x1) {
            return Status.Misaligned;
        }
        else if(address >= this.romStart && address < this.romEnd) {
            return Status.ReadOnly;
        }
        else {
            *(cast(ushort*) &this.data[address]) = value;
            return Status.Ok;
        }
    }
    
    /// Store word
    Status storeWord(in int address, in int value) {
        if(address < 0 || address >= this.length) {
            return Status.OutOfBounds;
        }
        else if(address & 0x3) {
            return Status.Misaligned;
        }
        else if(address >= this.romStart && address < this.romEnd) {
            return Status.ReadOnly;
        }
        else {
            *(cast(int*) &this.data[address]) = value;
            return Status.Ok;
        }
    }
}
