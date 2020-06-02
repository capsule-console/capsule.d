module capsule.core.memory;

import core.stdc.stdlib : free, calloc;

public pure nothrow @safe @nogc:

enum CapsuleMemoryStatus: uint {
    /// Successful read or write
    Ok = 0,
    /// Failure: Tried to write to read-only memory
    ReadOnly = 1,
    /// Failure: Tried to read or write on a misaligned address
    Misaligned = 2,
    /// Failure: Memory address out of bounds
    OutOfBounds = 3,
}

/// Couples a loaded value from memory with a status indicator.
struct CapsuleMemoryLoad(T) {
    nothrow @safe @nogc:
    
    alias Status = CapsuleMemoryStatus;
    
    static enum ReadOnly = typeof(this)(Status.ReadOnly, 0);
    static enum Misaligned = typeof(this)(Status.Misaligned, 0);
    static enum OutOfBounds = typeof(this)(Status.OutOfBounds, 0);
    
    Status status = Status.Ok;
    T value;
    
    static typeof(this) Ok(in T value) {
        return typeof(this)(Status.Ok, value);
    }
    
    @property bool ok() const {
        return this.status is Status.Ok;
    }
    
    bool opCast(T: bool)() const {
        return this.status is Status.Ok;
    }
}

/// Split memory:
/// Memory up to address X is ROM.
/// Memory from X to Y is RAM.
/// ROM and RAM lengths are determined by cartridge metadata.
@trusted struct CapsuleMemory {
    nothrow @nogc:
    
    alias Status = CapsuleMemoryStatus;
    alias Load = CapsuleMemoryLoad;
    
    ubyte* data = null;
    uint length = 0;
    uint romStart = 0;
    uint romEnd = 0;
    
    void allocate(in uint length) {
        assert(length <= int.max);
        this.length = length;
        this.data = cast(ubyte*) calloc(length, 1);
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
        return this.data !is null;
    }
    
    /// Load sign-extended byte
    Load!int lb(in int address) const {
        if(address < 0 || address >= this.length) {
            return Load!int.OutOfBounds;
        }
        else {
            const value = cast(byte) (this.data[address]);
            return Load!int.Ok(cast(int) value);
        }
    }
    
    /// Load zero-extended byte
    Load!uint lbu(in int address) const {
        if(address < 0 || address >= this.length) {
            return Load!uint.OutOfBounds;
        }
        else {
            const value = *(cast(ubyte*) &this.data[address]);
            return Load!uint.Ok(cast(uint) value);
        }
    }
    
    /// Load sign-extended half word
    Load!int lh(in int address) const {
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
    Load!uint lhu(in int address) const {
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
    Load!int lw(in int address) const {
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
    
    /// Store byte
    Status sb(in int address, in ubyte value) {
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
    Status sh(in int address, in ushort value) {
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
    Status sw(in int address, in int value) {
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
