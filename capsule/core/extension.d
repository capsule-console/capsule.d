module capsule.core.extension;

public nothrow @safe @nogc:

/* Tentatively planned extensions

Exception Handling Module 00 00 .. .. (exc_init, exc_quit, exc_get_code)

Memory management module (00 00 .. ..) (mem_brk)

Configuration Preferences Module

Saved Data Module

External Assets Module

*/

enum CapsuleExtension: uint {
    // Meta Module (00 00 00 xx)
    meta_noop = 0x0000,
    meta_exit_ok = 0x0001,
    meta_exit_error = 0x0002,
    meta_check_ext = 0x0003,
    meta_list_exts = 0x0004,
    meta_host_uuid = 0x0005,
    meta_host_name = 0x0006,
    // Standard Input and Output Module (00 00 01 xx)
    stdio_init = 0x0100,
    stdio_quit = 0x0101,
    stdio_put_byte = 0x0102,
    stdio_get_byte = 0x0103,
    stdio_flush = 0x0104,
    stdio_eof = 0x0105,
    // 2D Pixel Graphics Module (30 00 00 xx)
    pxgfx_init = 0x30000000,
    pxgfx_quit = 0x30000001,
    pxgfx_check_mode = 0x30000002,
    pxgfx_list_res = 0x30000003,
    pxgfx_flip = 0x30000004,
}
