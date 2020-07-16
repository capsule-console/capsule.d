module capsule.dynarec.x86.mode;

public pure nothrow @safe @nogc extern(C):

enum X86Mode: ubyte {
    None = 0x0,
    Legacy = 0x1,
    Long = 0x2,
}
