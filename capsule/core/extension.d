/**

This module provides an enumeration of extension IDs that should be
recognized by a Capsule virtual machine.

Extension IDs are used to identify what should happen when the Capsule
virtual machine encounters an ecall (extension call) instruction.

*/

module capsule.core.extension;

public nothrow @safe @nogc:

/// Enumeration of Capsule extension IDs.
enum CapsuleExtension: uint {
    // Meta Module (00 00 00 xx)
    meta_noop = 0x0000,
    meta_exit_ok = 0x0001,
    meta_exit_error = 0x0002,
    meta_check_ext = 0x0003,
    meta_host_uuid = 0x0004,
    meta_host_name = 0x0005,
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
