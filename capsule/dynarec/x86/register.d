module capsule.dynarec.x86.register;

private:

import capsule.dynarec.x86.size : X86DataSize;

public pure nothrow @safe @nogc:

extern(C): // Make sure this works with --betterC

enum X86SegmentRegister: ubyte {
    /// Extra Segment (ES). Pointer to extra data ('E' stands for 'Extra').
    es = 0x0,
    /// Code Segment (CS). Pointer to the code.
    cs = 0x1,
    /// Stack Segment (SS). Pointer to the stack.
    ss = 0x2,
    /// Data Segment (DS). Pointer to the data.
    ds = 0x3,
    /// F Segment (FS). Pointer to more extra data ('F' comes after 'E').
    fs = 0x4,
    /// G Segment (GS). Pointer to still more extra data ('G' comes after 'F').
    gs = 0x5,
}

enum X86RegisterFlag: ubyte {
    /// Carry Flag
    CF = 0,
    /// Parity Flag
    PF = 2,
    /// Adjust Flag
    AF = 4,
    /// Zero Flag
    ZF = 6,
    /// Sign Flag
    SF = 7,
    /// Trap Flag
    TF = 8,
    /// Interruption Flag
    IF = 9,
    /// Direction Flag
    DF = 10,
    /// Overflow Flag
    OF = 11,
    /// Nested Task Flag
    NT = 14,
    /// Resume Flag
    RF = 16,
    /// Virtual-8086 Mode Flag
    VM = 17,
    /// Alignment Check Flag
    AC = 18,
    /// Virtual Interrupt Flag
    VIF = 19,
    /// Virtual Interrupt Pending Flag
    VIP = 20,
    /// Identification Flag
    ID = 21,
}

/// Enumeration of X86 general-purpose registers.
enum X86Register: ubyte {
    // 64-bit registers.
    rax = 0x0,
    rcx = 0x1,
    rdx = 0x2,
    rbx = 0x3,
    rsp = 0x4,
    rbp = 0x5,
    rsi = 0x6,
    rdi = 0x7,
    // Extended 64-bit registers.
    r8 = 0x8,
    r9 = 0x9,
    r10 = 0xa,
    r11 = 0xb,
    r12 = 0xc,
    r13 = 0xd,
    r14 = 0xe,
    r15 = 0xf,
    // 32-bit registers.
    eax = 0x10,
    ecx = 0x11,
    edx = 0x12,
    ebx = 0x13,
    esp = 0x14,
    ebp = 0x15,
    esi = 0x16,
    edi = 0x17,
    // Extended 32-bit registers.
    r8d = 0x18,
    r9d = 0x19,
    r10d = 0x1a,
    r11d = 0x1b,
    r12d = 0x1c,
    r13d = 0x1d,
    r14d = 0x1e,
    r15d = 0x1f,
    // 16-bit registers.
    ax = 0x20,
    cx = 0x21,
    dx = 0x22,
    bx = 0x23,
    sp = 0x24,
    bp = 0x25,
    si = 0x26,
    di = 0x27,
    // Extended 16-bit registers.
    r8w = 0x28,
    r9w = 0x29,
    r10w = 0x2a,
    r11w = 0x2b,
    r12w = 0x2c,
    r13w = 0x2d,
    r14w = 0x2e,
    r15w = 0x2f,
    // 8-bit registers.
    al = 0x30,
    cl = 0x31,
    dl = 0x32,
    bl = 0x33,
    ah = 0x34,
    ch = 0x35,
    dh = 0x36,
    bh = 0x37,
    // Extended 8-bit registers.
    r8b = 0x38,
    r9b = 0x39,
    r10b = 0x3a,
    r11b = 0x3b,
    r12b = 0x3c,
    r13b = 0x3d,
    r14b = 0x3e,
    r15b = 0x3f,
}

/// Get the ID or index for a given register.
/// IDs can be up to four bits. If the highest bit is set,
/// then a REX prefix byte must be present.
/// The low three bits appear in the ModR/M byte and the
/// high bit, if there is one, appears in the REX byte.
uint X86RegisterId(in X86Register register) {
    return (cast(uint) register) & 0xf;
}

/// Returns true if the highest bit of a register ID is
/// set, necessitating an REX prefix byte to encode it.
bool X86RegisterIsExtended(in X86Register register) {
    return (register & 0x8) != 0;
}

/// Returns true for registers that are supported only in long mode,
/// which includes 64-bit registers and extended registers.
bool X86RegisterLongModeOnly(in X86Register register) {
    return register < 16 || ((register & 0x8) != 0);
}

bool X86RegisterIsByteHigh(in X86Register register) {
    return register >= X86Register.ah && register <= X86Register.bh; 
}

/// Get the size in bits of the value held in a register,
/// e.g. 64 for rax and 32 for eax.
X86DataSize X86RegisterSize(in X86Register register) {
    if(register < 16) {
        return X86DataSize.QWord;
    }
    else if(register < 32) {
        return X86DataSize.DWord;
    }
    else if(register < 48) {
        return X86DataSize.Word;
    }
    else {
        assert(register < 64);
        return X86DataSize.Byte;
    }
}
