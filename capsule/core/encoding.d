/**

The declarations in this module are used commonly by other
modules that read or write data using a standard Capsule
file format.

A standard Capsule file begins with a 64-byte file header,
which is followed by any number of 32-bit section headers.
The section headers may indicate an offset to related binary
data which, if so indicated, will follow after all headers.

*/

module capsule.core.encoding;

public nothrow @safe @nogc:

T capsuleHeaderStringToInt(T = uint)(in string header) @trusted {
    assert(header.length == T.sizeof);
    T value = 0;
    for(size_t i = 0; i < T.sizeof && i < header.length; i++) {
        value = value | ((cast(T) header[i]) << (i << 3));
    }
    return value;
}

auto capsuleHeaderIntToString(T = uint)(in T value) {
    char[T.sizeof] header;
    for(size_t i = 0; i < T.sizeof; i ++) {
        header[i] = cast(char) (value >> (i << 3));
    }
    return header;
}

enum CapsuleArchitecture: uint {
    /// No architecture or missing architecture
    None = 0,
    /// Capsule bytecode (standard ABI)
    Capsule = 1,
}

/// Enumeration of recognized hash types
enum CapsuleHashType: uint {
    None = 0x00,
    CRC32 = 0x01,
    CRC64ISO = 0x02,
    CRC64EMCA = 0x03,
}

/// Enumeration of recognized text encodings
enum CapsuleTextEncoding: ushort {
    /// No text encoding or unknown encoding
    @("none") None = 0x0000,
    /// Text is ASCII-encoded
    @("ascii") Ascii = 0x0001,
    /// Text is UTF-8 encoded
    @("utf-8") UTF8 = 0x0002,
}

/// Enumeration of recognized timestamp representations
enum CapsuleTimeEncoding: ushort {
    /// No date/time encoding or unknown encoding
    @("none") None = 0x0000,
    /// Timestamps are a 64-bit signed number of seconds since
    /// Unix epoch (ISO 8601: 1970-01-01T00:00:00Z) on Earth
    @("unix-seconds") UnixEpochSeconds = 0x0001,
}

/// Enumeration of possible status codes for file encoders and decoders
enum CapsuleEncoderStatus: uint {
    /// No errors
    Ok = 0,
    /// Unspecified error or failure
    UnspecifiedError,
    /// Error reading a file, e.g. file is nonexistent
    FileReadError,
    /// Error writing to a file, e.g. file is write-protected
    FileWriteError,
    /// Tried to encode a malformed or invalid input
    InvalidInput,
    /// Encountered end-of-file but expected to find more content
    UnexpectedEOF,
    /// Expected a different file type (i.e. found wrong header name)
    UnexpectedFileType,
    /// File has an unknown version name
    UnknownFileVersion,
    /// File has a version name that is known but not handled
    /// by this particular implementation
    UnhandledFileVersion,
    /// The file header is malformed
    BadFileHeader,
    /// A section header in the file is malformed
    BadSectionHeader,
    /// A section header indicated a content offset and length that
    /// wasn't valid or wasn't consistent with or that overlapped
    /// with other section content
    BadSectionContent,
    /// File has a section of an unknown type
    UnknownSectionType,
    /// File has a section of a type that is known but not handled
    UnhandledSectionType,
    /// File has an unknown text encoding indicator
    UnknownTextEncoding,
    /// File has a text encoding that is known but not handled
    UnhandledTextEncoding,
    /// File has an unknown timestamp encoding indicator
    UnknownTimeEncoding,
    /// File has a timestamp encoding that is known but not handled
    UnhandledTimeEncoding,
}

struct CapsuleFileHeader {
    alias TextEncoding = CapsuleTextEncoding;
    alias TimeEncoding = CapsuleTimeEncoding;
    
    enum uint EncodedLength = 64;
    
    /// Identify the file type, e.g. "CAPSOBJT"
    ulong name = 0;
    /// Identify the file format version
    ulong versionName = 0;
    /// The length of this file header
    ushort headerLength = CapsuleFileHeader.EncodedLength;
    /// The length of each file section header
    ushort entryLength = CapsuleFileSectionHeader.EncodedLength;
    /// Length of the file, not counting the file header
    uint contentLength = 0;
    /// The total number of file sections
    uint entries = 0;
    /// Indicate text encoding used
    TextEncoding textEncoding = TextEncoding.None;
    /// Indicate timestamp encoding used
    TimeEncoding timeEncoding = TimeEncoding.None;
    /// Usage depends on file type
    union {
        ubyte[32] data;
        ushort[16] shortData;
        uint[8] intData;
        ulong[4] longData;
    }
}

struct CapsuleFileSectionHeader {
    enum uint EncodedLength = 32;
    
    /// Section header name, e.g. "NAMS"
    uint name = 0;
    /// The byte offset where the section's content begins
    /// Sections may set this to zero and then store any
    /// data in the remaining bytes of the header rather than
    /// storing any content elsewhere
    uint offset = 0;
    /// Number of bytes in the section content
    uint length = 0;
    /// The number of entries represented in the section, when relevant
    uint entries = 0;
    /// Usage depends on section type
    union {
        ubyte[16] data;
        ushort[8] shortData;
        uint[4] intData;
        ulong[2] longData;
    }
    
    /// May be used by the encoder to indicate whether a section
    /// has any content associated with it or not
    bool noContent = false;
    /// May be used by the encoder to indicate whether a section
    /// should be written to the file or not
    bool omitSection = false;
    /// May be used by the encoder to indicate the length of 
    /// an individual entry in the section's content
    uint entryLength = 0;
}

mixin template CapsuleCoderMixin() {
    alias FileHeader = CapsuleFileHeader;
    alias FileSectionHeader = CapsuleFileSectionHeader;
    alias HashType = CapsuleHashType;
    alias Status = CapsuleEncoderStatus;
    alias TextEncoding = CapsuleTextEncoding;
    alias TimeEncoding = CapsuleTimeEncoding;
    
    alias ReadSectionContentDelegate = bool delegate(in FileSectionHeader header);
    alias WriteSectionContentDelegate = bool delegate(in FileSectionHeader header);
    
    alias ReadByteDelegate = int delegate();
    alias WriteByteDelegate = void delegate(in ubyte value);
    
    Status status = Status.Ok;
    uint length = 0;
    
    bool ok() const {
        return this.status is Status.Ok;
    }
    
    void setStatus(in Status status) {
        this.status = status;
    }
    
    static uint getPaddingBytes(T)(in T[] data) {
        return typeof(this).getPaddingBytes(data.length);
    }
    
    static uint getPaddingBytes(T)(in T length) if(is(T == uint) || is(T == ulong)) {
        return (4 - (cast(uint) length & 0x3)) & 0x3;
    }
    
    static uint getPaddedBytesLength(T)(in T[] data) {
        return typeof(this).getPaddedBytesLength(data.length);
    }
    
    static uint getPaddedBytesLength(T)(in T length) if(is(T == uint) || is(T == ulong)) {
        const padding = typeof(this).getPaddingBytes(length);
        return (cast(uint) length) + padding;
    }
}

mixin template CapsuleEncoderMixin() {
    private import capsule.meta.templates : Unconst;
    
    mixin CapsuleCoderMixin;
    
    WriteByteDelegate writeByteDelegate;
    
    this(WriteByteDelegate writeByteDelegate) {
        this.writeByteDelegate = writeByteDelegate;
    }
    
    void writeFile(
        FileHeader fileHeader, FileSectionHeader[] sections,
        WriteSectionContentDelegate[] writers,
    ) {
        // Fill in basic metadata about the file header if omitted
        if(fileHeader.headerLength == 0) {
            fileHeader.headerLength = FileHeader.EncodedLength;
        }
        if(fileHeader.entryLength == 0) {
            fileHeader.entryLength = FileSectionHeader.EncodedLength;
        }
        if(fileHeader.headerLength != FileHeader.EncodedLength ||
            fileHeader.entryLength != FileSectionHeader.EncodedLength
        ) {
            this.setStatus(Status.InvalidInput);
            return;
        }
        // Find the number of sections that were not omitted
        uint numSections = 0;
        foreach(section; sections) {
            numSections += section.omitSection ? 0 : 1;
        }
        // Populate content offsets for each section header
        uint contentOffset = fileHeader.entryLength * numSections;
        foreach(ref section; sections) {
            if(section.omitSection) {
                continue;
            }
            if(section.length == 0 && section.entries != 0 && section.entryLength != 0) {
                section.length = section.entries * section.entryLength;
            }
            if(section.length) {
                section.offset = contentOffset + fileHeader.headerLength;
            }
            contentOffset += section.length;
        }
        // Fill in length and entry count properties for the file header
        fileHeader.contentLength = contentOffset;
        fileHeader.entries = numSections;
        // Write the file and section headers
        this.writeFileHeader(fileHeader);
        assert(this.length == fileHeader.headerLength);
        foreach(section; sections) {
            if(!section.omitSection) {
                this.writeSectionHeader(section);
            }
        }
        assert(this.length == (
            fileHeader.headerLength + (fileHeader.entryLength * numSections)
        ));
        // Write content for each section
        foreach(section; sections) {
            if(this.status !is Status.Ok) break;
            if(section.length && !section.noContent && !section.omitSection) {
                assert(this.length == section.offset);
                foreach(writer; writers) {
                    const match = writer(section);
                    if(match) {
                        assert(this.length - section.offset == section.length,
                            "Wrong encoded length for section: " ~
                            cast(string) capsuleHeaderIntToString(section.name)
                        );
                        break;
                    }
                }
            }
        }
    }
    
    static auto encodeFileHeaderData(T...)(auto ref T values) {
        enum length = typeof(FileHeader.init.data).length;
        return typeof(this).encodeHeaderData!length(values);
    }
    
    static auto encodeFileSectionHeaderData(T...)(auto ref T values) {
        enum length = typeof(FileSectionHeader.init.data).length;
        return typeof(this).encodeHeaderData!length(values);
    }
    
    static ubyte[length] encodeHeaderData(size_t length, T...)(auto ref T values) {
        ubyte[length] bytes;
        uint offset = 0;
        foreach(i, value; values) {
            assert(offset + T[i].sizeof <= bytes.length);
            assert(offset % T[i].sizeof == 0, "Data values are not aligned.");
            *(cast(Unconst!(T[i])*) &bytes[offset]) = value;
            offset += T[i].sizeof;
        }
        return bytes;
    }
    
    void writeFileHeader(in FileHeader header) {
        this.writeLong(header.name);
        this.writeLong(header.versionName);
        this.writeShort(header.headerLength);
        this.writeShort(header.entryLength);
        this.writeInt(header.contentLength);
        this.writeInt(header.entries);
        this.writeShort(cast(ushort) header.textEncoding);
        this.writeShort(cast(ushort) header.timeEncoding);
        this.writeBytes(header.data);
    }
    
    void writeSectionHeader(in FileSectionHeader header) {
        this.writeInt(header.name);
        this.writeInt(header.offset);
        this.writeInt(header.length);
        this.writeInt(header.entries);
        this.writeBytes(header.data);
    }
    
    void writeBytes(T)(in T[] bytes) if(T.sizeof == 1) {
        foreach(ch; bytes) {
            this.writeByteDelegate(cast(ubyte) ch);
        }
        this.length += bytes.length;
    }
    
    void writeBytes(T)(in T[] bytes) @trusted if(T.sizeof != 1) {
        const byteLength = bytes.length * T.sizeof;
        for(uint i = 0; i < byteLength; i++) {
            const ch = (cast(ubyte*) bytes.ptr)[i];
            this.writeByteDelegate(ch);
        }
        this.length += byteLength;
    }
    
    uint writePaddedBytes(T)(in T[] bytes) {
        this.writeBytes(bytes);
        return this.writePaddingBytes(cast(uint) (bytes.length * T.sizeof));
    }
    
    uint writePaddingBytes(in uint length) {
        const padding = typeof(this).getPaddingBytes(length);
        for(uint i = 0; i < padding; i++) {
            this.writeByteDelegate(0);
        }
        this.length += padding;
        return length + padding;
    }
    
    void writeByte(in ubyte value) {
        this.writeByteDelegate(value);
        this.length++;
    }
    
    void writeShort(in ushort value) {
        this.writeByteDelegate(cast(ubyte) (value));
        this.writeByteDelegate(cast(ubyte) (value >> 8));
        this.length += 2;
    }
    
    void writeInt(in uint value) {
        this.writeByteDelegate(cast(ubyte) (value));
        this.writeByteDelegate(cast(ubyte) (value >> 8));
        this.writeByteDelegate(cast(ubyte) (value >> 16));
        this.writeByteDelegate(cast(ubyte) (value >> 24));
        this.length += 4;
    }
    
    void writeLong(in ulong value) {
        this.writeByteDelegate(cast(ubyte) (value));
        this.writeByteDelegate(cast(ubyte) (value >> 8));
        this.writeByteDelegate(cast(ubyte) (value >> 16));
        this.writeByteDelegate(cast(ubyte) (value >> 24));
        this.writeByteDelegate(cast(ubyte) (value >> 32));
        this.writeByteDelegate(cast(ubyte) (value >> 40));
        this.writeByteDelegate(cast(ubyte) (value >> 48));
        this.writeByteDelegate(cast(ubyte) (value >> 56));
        this.length += 8;
    }
}

mixin template CapsuleDecoderMixin() {
    private import capsule.algorithm.sort : sort;
    
    mixin CapsuleCoderMixin;
    
    ReadByteDelegate readByteDelegate;
    /// When set to false, an unrecognized file section tpye
    /// will produce a fatal error.
    /// When set to true, sections of unrecognized types
    /// will be silently ignored.
    bool ignoreUnknownSections = false;
    
    this(ReadByteDelegate readByteDelegate) {
        this.readByteDelegate = readByteDelegate;
    }
    
    void readFileContent(
        in FileHeader fileHeader, ReadSectionContentDelegate[] readers
    ) {
        if(fileHeader.headerLength != FileHeader.EncodedLength ||
            fileHeader.entryLength != FileSectionHeader.EncodedLength
        ) {
            this.setStatus(Status.InvalidInput);
            return;
        }
        auto sections = new FileSectionHeader[fileHeader.entries];
        for(uint i = 0; i < sections.length; i++) {
            sections[i] = this.readSectionHeader();
            if(this.status !is Status.Ok) return;
        }
        sections.sort!(
            (a, b) => (a.offset < b.offset)
        );
        foreach(section; sections) {
            version(assert) const startOffset = this.length;
            if(section.length) {
                if(this.length > section.offset) {
                    this.setStatus(Status.BadSectionContent);
                    return;
                }
                while(this.length < section.offset) {
                    const ch = this.readByteDelegate();
                    this.length++;
                    if(ch < 0) {
                        this.setStatus(Status.UnexpectedEOF);
                        return;
                    }
                }
                assert(this.length == section.offset);
            }
            foreach(reader; readers) {
                const match = reader(section);
                if(match) {
                    goto FoundMatchingSection;
                }
            }
            if(!this.ignoreUnknownSections) {
                this.setStatus(Status.UnknownSectionType);
            }
            FoundMatchingSection:
            if(this.status !is Status.Ok) return;
            version(assert) assert(this.length == startOffset + section.length,
                "Wrong section length: " ~
                cast(string) capsuleHeaderIntToString(section.name)
            );
        }
    }
    
    FileHeader readFileHeader() {
        FileHeader header;
        header.name = this.readLong();
        header.versionName = this.readLong();
        header.headerLength = this.readShort();
        header.entryLength = this.readShort();
        header.contentLength = this.readInt();
        header.entries = this.readInt();
        header.textEncoding = cast(TextEncoding) this.readShort();
        header.timeEncoding = cast(TimeEncoding) this.readShort();
        this.readBytes(header.data);
        return header;
    }
    
    FileSectionHeader readSectionHeader() {
        FileSectionHeader header;
        header.name = this.readInt();
        header.offset = this.readInt();
        header.length = this.readInt();
        header.entries = this.readInt();
        this.readBytes(header.data);
        return header;
    }
    
    ubyte[] readBytes(in uint length) {
        ubyte[] bytes = new ubyte[length];
        for(uint i = 0; i < length; i++) {
            const ch = this.readByteDelegate();
            if(ch < 0) {
                this.status = Status.UnexpectedEOF;
                return null;
            }
            bytes[i] = cast(ubyte) ch;
        }
        this.length += length;
        return bytes;
    }
    
    void readBytes(T, size_t length)(ref T[length] bytes) if(T.sizeof == 1) {
        for(uint i = 0; i < length; i++) {
            const ch = this.readByteDelegate();
            if(ch < 0) {
                this.status = Status.UnexpectedEOF;
                return;
            }
            bytes[i] = cast(ubyte) ch;
        }
        this.length += length;
    }
    
    void readBytes(T, size_t length)(
        ref T[length] bytes
    ) @trusted if(T.sizeof != 1) {
        const byteLength = length * T.sizeof;
        for(uint i = 0; i < byteLength; i++) {
            const ch = this.readByteDelegate();
            if(ch < 0) {
                this.status = Status.UnexpectedEOF;
                return;
            }
            (cast(ubyte*) bytes)[i] = cast(ubyte) ch;
        }
        this.length += byteLength;
    }
    
    ubyte[] readPaddedBytes(in uint length) {
        const padding = this.getPaddingBytes(length);
        auto bytes = this.readBytes(length);
        if(bytes.length == length) {
            for(uint i = 0; i < padding; i++) {
                const ch = this.readByteDelegate();
                if(ch < 0) {
                    this.status = Status.UnexpectedEOF;
                    return null;
                }
            }
            this.length += padding;
        }
        return bytes;
    }
    
    ubyte readByte() {
        const b0 = this.readByteDelegate();
        if(b0 < 0) {
            this.status = Status.UnexpectedEOF;
            return 0;
        }
        this.length++;
        return cast(ubyte) b0;
    }
    
    ushort readShort() {
        const b0 = this.readByteDelegate();
        const b1 = this.readByteDelegate();
        if(b0 < 0 || b1 < 0) {
            this.status = Status.UnexpectedEOF;
            return 0;
        }
        this.length += 2;
        return cast(ushort) (cast(ushort) b0 | ((cast(ushort) b1) << 8));
    }
    
    uint readInt() {
        const b0 = this.readByteDelegate();
        const b1 = this.readByteDelegate();
        const b2 = this.readByteDelegate();
        const b3 = this.readByteDelegate();
        if(b0 < 0 || b1 < 0 || b2 < 0 || b3 < 0) {
            this.status = Status.UnexpectedEOF;
            return 0;
        }
        this.length += 4;
        return (
            (cast(uint) b0) | (cast(uint) b1 << 8) |
            (cast(uint) b2 << 16) | (cast(uint) b3 << 24)
        );
    }
    
    ulong readLong() {
        const b0 = this.readByteDelegate();
        const b1 = this.readByteDelegate();
        const b2 = this.readByteDelegate();
        const b3 = this.readByteDelegate();
        const b4 = this.readByteDelegate();
        const b5 = this.readByteDelegate();
        const b6 = this.readByteDelegate();
        const b7 = this.readByteDelegate();
        if(
            b0 < 0 || b1 < 0 || b2 < 0 || b3 < 0 ||
            b4 < 0 || b5 < 0 || b6 < 0 || b7 < 0
        ) {
            this.status = Status.UnexpectedEOF;
            return 0;
        }
        this.length += 8;
        return (
            (cast(ulong) b0) | (cast(ulong) b1 << 8) |
            (cast(ulong) b2 << 16) | (cast(ulong) b3 << 24) |
            (cast(ulong) b4 << 32) | (cast(ulong) b5 << 40) |
            (cast(ulong) b6 << 48) | (cast(ulong) b7 << 56)
        );
    }
}
