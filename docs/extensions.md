# Capsule Extensions Documentation

_Please be aware that Capsule's standard set of extensions, as well as this
document, remain an incomplete work in progress for the time being._

A Capsule program receives input and sends output or otherwise
interfaces with its host system via _extensions_,
which are invoked using the **ecall**, or _extension call_
assembly instruction.

An ecall instruction specifies what extension should be called using
a 32-bit ID value.

Note that those extensions whose highest 17 ID bits are either all
zero or all one are special in that they can be invoked with a single
ecall instruction and with no need to modify a register, as their
entire ID value can fit within a signed-extended 16-bit immediate.

When invoking an extension with an ID value which cannot fit into a
single 16-bit immediate value, it becomes necessary to use both a
**lui** and an **ecall** instruction in combination, with a register
designated to hold the upper half of the extension ID value.

The _ecall_ instruction uses its immediate value and the second source
register to identify what extension is being called.
The instruction always requires a destination register.

The _ecall_ instruction treats the first source register as an input
value, or a pointer to a location in memory where some input data
resides. Extensions that don't involve any input value will ignore
the first source register and its value completely.

Many extensions will simply and unconditionally write a zero value to
the destination register, but others will write a status code or other
output value to the destination register.
The value of the destination register will always be overwritten by
an _ecall_ instruction, even if the extension has no meaningful output.
Typically, a zero value will be written in this case.

By convention:

- IDs 0x00000000 to 0x00007fff are for low-level system functionality.
- IDs 0x0000ffff to 0x0fffffff are for additional system functionality.
- IDs 0x10000000 to 0x1fffffff are for internet and networking functionality.
- IDs 0x20000000 to 0x2fffffff are for interfacing with input devices.
- IDs 0x30000000 to 0x3fffffff are for interfacing with output devices.
- IDs 0x40000000 to 0x5fffffff are reserved for future use.
- IDs 0x70000000 to 0xffffffff are available to use for custom ecall handlers.

By convention, identifiers are further divided for output-related extensions:

- IDs 0x30000000 to 0x30ffffff are for graphics or visual output.
- IDs 0x31000000 to 0x31ffffff are for audio or sound output.
- IDs 0x32000000 to 0x32ffffff are for thermal, tactile, or haptic output.
- IDs 0x34000000 to 0x33ffffff are for olfactory or gustatory output.
- IDs 0x35000000 to 0x3fffffff are reserved for other forms of output.

Though extension IDs 0x70000000 and up are reserved to be used by
custom extension call handlers, there is not currently any way for
a program to register such a handler. This may change in the future.

## Meta Module (00 00 00 xx)

### meta.noop (00 00 00 00)

No operation. Does nothing.

### meta.exit_ok (00 00 00 01)

Exit the program immediately with a success/normal status.

### meta.exit_error (00 00 00 02)

Exit the program immediately with an error/abnormal status.

### meta.check_ext (00 00 00 03)

If the virtual console recognizes and supports an extension identified
by the ID value in the source register, a nonzero value will be written
to the destination register.

Otherwise, a zero value will be written to the destination register.

### meta.defer (00 00 00 04)

Defers execution to the virtual console for a very short time, allowing
it to do essential bookkeeping, such as monitoring for a SIGTERM or
other signal to stop the program.

### meta.host_uuid (00 00 00 05)

_Not yet implemented._

### meta.host_name (00 00 00 06)

_Not yet implemented._

## Standard Input and Output Module (00 00 01 xx)

### stdio.init (00 00 01 00)

Initialize the _stdio_ module.

Atempting to invoke any other _stdio_ extension before initializating
the module may result in an error.

### stdio.quit (00 00 01 01)

Quit the _stdio_ module.

Atempting to invoke any other _stdio_ extension after terminating
the module and without reinitializing it may result in an error.

### stdio.put_byte (00 00 01 02)

Write the value of the first source register to standard output as
a single byte.

Typically, output will be written to the console application's standard
output stream.

### stdio.get_byte (00 00 01 03)

Read one byte from standard input and store its value in the destination
register. A negative value will be stored if there were no bytes available
to read.

Typically, input will be read from the console application's standard
input stream.

### stdio.flush (00 00 01 04)

_Not yet implemented._

### stdio.eof (00 00 01 05)

_Not yet implemented._

## Time Module (00 00 02 xx)

### time.init (00 00 02 00)

Initialize the _time_ module.

Atempting to invoke any other _time_ extension before initializating
the module may result in an error.

### time.quit (00 00 02 01)

Quit the _time_ module.

Atempting to invoke any other _time_ extension after terminating
the module and without reinitializing it may result in an error.

### time.sleep_ms (00 00 02 02)

Suspend program execution for an approximate number of milliseconds,
as indicated by the value in the source register.

Sleeping can be relied upon to be less demanding on a host's processor
and/or battery charge than simply looping until some desired amount of
time has elapsed.

### time.monotonic_ms (00 00 02 03)

Get the number of milliseconds on a
[monotonic clock](https://itnext.io/as-a-software-developer-why-should-you-care-about-the-monotonic-clock-7d9c8533595c),
and store that value in the destination register.

The source register indicates how many times to shift the value on the
monotonic clock right by 32 bits before storing its value in the destination
register, i.e. which word of the value to retrieve, starting at the lowest
or least significant word.

The console does not guarantee access to more than 32 meaningful bits
of a monotonic clock value. It is possible that _time.monotonic_ns_ calls
with a nonzero source register will always and unconditionally produce
a zero value in the destination register on some platforms.

## 2D Pixel Graphics Module (30 00 00 xx)

### pxgfx.init

Initializes displaying graphics using the pxgfx module.

The source register is expected to contain a pointer to settings data
formatted like so:

``` c
struct pxgfx_init_settings {
    // Output image width in pixels.
    int resolution_x;
    // Output image height in pixels.
    int resolution_y;
    // The number of bytes used to represent each row of pixels.
    // Pitch must be a power of two.
    int pitch;
    // Indicates the pixel display mode that should be used.
    int display_mode;
    // Used to indicate a pointer to pixel data.
    // This pointer is used by all display modes.
    // The value here must be an offset relative to the beginning
    // of the settings data, i.e. relative to the value given in
    // the first source register.
    int pixels_offset;
    // Used to indicate a pointer to palette data.
    // This pointer is used by indexed display modes.
    // The value here must be an offset relative to the beginning
    // of the settings data, i.e. relative to the value given in
    // the first source register.
    int palette_offset;
    // Sixteen bytes of padding, reserved for future use.
    int[2] padding;
}
```

Here is the list of recognized display modes:

| Name | Bits per pixel | Value |
| ---- | -------------- | ----- |
| Indexed 2-bit (RGB) | 2 | 0x01 |
| Indexed 4-bit (RGB) | 4 | 0x02 |
| Indexed 8-bit (RGB) | 8 | 0x03 |
| Truecolor 24-bit (RGB) | 32 | 0x80 |

_As of writing, only the Truecolor 24-bit mode is actually supported._

### pxgfx.quit

_Not yet implemented._

### pxgfx.check_mode

_Not yet implemented._

### pxgfx.check_res

_Not yet implemented._

### pxgfx.flip

Updates the displayed graphics to represent the pixel data indicated
by a _pxgfx.init_ extension call.

Without a _pxgfx.flip_ extension call, writing pixel data to the memory
area indicated with the _pxgfx.init_ extension call will not actually
result in any visual updates. The _pxgfx.flip_ extension _must_ be called
in order to update the image that is actually being displayed.
