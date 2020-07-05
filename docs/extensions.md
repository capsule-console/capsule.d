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

## Meta Module (0x000000**)

### meta.noop (0x00000000)

No operation. Does nothing.

### meta.exit_ok (0x00000001)

Exit the program immediately with a success/normal status.

### meta.exit_error (0x00000002)

Exit the program immediately with an error/abnormal status.

### meta.check_ext (0x00000003)

If the virtual console recognizes and supports an extension identified
by the ID value in the source register, a nonzero value will be written
to the destination register.

Otherwise, a zero value will be written to the destination register.

### meta.defer (0x00000004)

Defers execution to the virtual console for a very short time, allowing
it to do essential bookkeeping, such as monitoring for a SIGTERM or
other signal to stop the program.

### meta.host_uuid (0x00000005)

_Not yet implemented._

### meta.host_name (0x00000006)

_Not yet implemented._

## Standard Input and Output Module (0x000001**)

### stdio.init (0x00000100)

Initialize the _stdio_ module.

Atempting to invoke any other _stdio_ extension before initializating
the module may result in an error.

### stdio.quit (0x00000101)

Quit the _stdio_ module.

Atempting to invoke any other _stdio_ extension after terminating
the module and without reinitializing it may result in an error.

### stdio.put_byte (0x00000102)

Write the value of the first source register to standard output as
a single byte.

Typically, output will be written to the console application's standard
output stream.

### stdio.get_byte (0x00000103)

Read one byte from standard input and store its value in the destination
register. A negative value will be stored if there were no bytes available
to read.

Typically, input will be read from the console application's standard
input stream.

### stdio.flush (0x00000104)

_Not yet implemented._

### stdio.eof (0x00000105)

_Not yet implemented._

## Time Module (0x000002**)

### time.init (0x00000200)

Initialize the _time_ module.

Atempting to invoke any other _time_ extension before initializating
the module may result in an error.

### time.quit (0x00000201)

Quit the _time_ module.

Atempting to invoke any other _time_ extension after terminating
the module and without reinitializing it may result in an error.

### time.sleep_rough_ms (0x00000202)

Suspend program execution for an approximate number of milliseconds,
as indicated by the value in the source register.

On some platforms, the precision of the sleep interval may be as
low as fifteen milliseconds, or external factors may cause the sleep
to be interrupted before it is complete.

Sleeping can be relied upon to be less demanding on a host's processor
and/or battery charge than simply looping until some desired amount of
time has elapsed.

### time.sleep_precise_ms (0x00000203)

Suspend program execution for a precise number of milliseconds,
as indicated by the value in the source register.

Absolute precision cannot be universally guaranteed, but in general this
sleep function should be expected to have a precision of close to one
millisecond, and should not be subject to interruptions.

Sleeping can be relied upon to be less demanding on a host's processor
and/or battery charge than simply looping until some desired amount of
time has elapsed.

### time.monotonic_ms (0x00000204)

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

## Memory Management Module (0x000003**)

### memory.brk (0x00000301)

Change the location of the program break, using the value of the
source register as a new exclusive high boundary on program memory.
It behaves similarly to Unix's
[brk system call](https://man7.org/linux/man-pages/man2/brk.2.html).

This extension can, in effect, be used to expand or to shrink
the BSS segment.

Sets the destination register to 0 on success and to a nonzero value
when the program break was not moved, e.g. because the requested size
was unacceptably large, because the new break location would have
truncated a segment other than the program's BSS segment, or because
the new program break was not aligned on a word boundary.

## 2D Pixel Graphics Module (0x300000**)

### pxgfx.init (0x30000000)

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
| Truecolor 24-bit (RGB) | 32 | 0x40 |

_As of writing, only the Truecolor 24-bit mode is actually supported._

### pxgfx.quit (0x30000001)

Quits the pxgfx module, if previously initialized.

### pxgfx.check_display_mode

Check whether the host console supports a given pixel graphics display mode,
as represented by the value of the source register.

Sets the destination register to 1 if the display mode is supported and
sets the destination register to 0 if it is not supported.

Refer to the _pxgfx.init_ documentation for a list and description of
recognized display modes.

### pxgfx.check_res

Query the host console for information about its support for a given
display resolution.

The source register supplies an address to a resolution to query,
represented as two signed 32-bit integers, width first and height second.

If the supplied address is not valid, e.g. if it is out of bounds or not
word-aligned, then an exception will occur.

If the resolution is fully supported and can be displayed without any
issues, then the destination register is set to 1.

If the resolution has poor or partial support, e.g. because it exceeds
the maximum display size and so must be cropped or scaled down, then
the destination register is set to 0.

If the resolution is completely unsupported and is likely or certain to
result in an error when given to _pxgfx.init_ as a resolution setting, then
the destination register is set to -1.

### pxgfx.flip

Updates the displayed graphics to represent the pixel data indicated
by a _pxgfx.init_ extension call.

Without a _pxgfx.flip_ extension call, writing pixel data to the memory
area indicated with the _pxgfx.init_ extension call will not actually
result in any visual updates. The _pxgfx.flip_ extension _must_ be called
in order to update the image that is actually being displayed.

### pxgfx.ask_res

Query the host console and get a preferred display resolution.

The preferred resolution is stored as two signed 32-bit words at the
memory address indicated by the source register, first width and then
height.

If the supplied address is not valid, e.g. if it is out of bounds or not
word-aligned, then an exception will occur.

For the best cross-platform support, programs should ideally either
display at the preferred resolution or display at a smaller resolution that
can be scaled up by an integer amount to fill the preferred resolution.
