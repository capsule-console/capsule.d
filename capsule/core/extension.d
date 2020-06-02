module capsule.core.extension;

public nothrow @safe @nogc:

enum CapsuleExtension: uint {
    /// Meta module 0x0000 0x0000
    meta_noop = 0x0000,
    meta_exit_ok = 0x0001,
    meta_exit_error = 0x0002,
    meta_check_ext = 0x0003,
    meta_list_exts = 0x0004,
    meta_host_uuid = 0x0005,
    meta_host_name = 0x0006,
    // Exceptions module 0x0000 0x1000
    exc_init = 0x1000,
    exc_get_code = 0x1001,
    exc_set_edt = 0x1002,
    exc_set_edp = 0x1003,
    // System settings module 0x0000 0x2000
    conf_init = 0x2000,
    // Standard I/O module 0x0000 0x3000
    stdio_init = 0x3000,
    stdio_quit = 0x3001,
    stdio_put_byte = 0x3002,
    stdio_get_byte = 0x3003,
    stdio_flush = 0x3004,
    stdio_eof = 0x3005,
}
