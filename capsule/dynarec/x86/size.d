module capsule.dynarec.x86.size;

public pure nothrow @safe @nogc:

extern(C): // Make sure this works with --betterC

alias X86AddressSize = X86DataSize;

alias X86ImmediateSize = X86DataSize;

alias X86DisplacementSize = X86DataSize;

enum X86DataSize: ubyte {
    None = 0,
    Byte = 8,
    Word = 16,
    DWord = 32,
    QWord = 64,
}
