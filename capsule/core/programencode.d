module capsule.core.programencode;

import capsule.core.crc : CRC64ISO;
import capsule.core.program : CapsuleProgram;

import capsule.core.encoding;

public:

mixin template CapsuleProgramCoderMixin() {
    alias stringToInt = capsuleHeaderStringToInt;
    
    static const FileVersion_2020_05_14 = stringToInt!ulong("20200514");
    
    static const ProgramHeader = stringToInt!ulong("CAPSPROG");
    static const TimestampHeader = stringToInt("TIME");
    static const CommentHeader = stringToInt("CMNT");
    static const TitleHeader = stringToInt("TITL");
    static const CreditHeader = stringToInt("CRED");
    static const EntryHeader = stringToInt("ENTR");
    static const NamesHeader = stringToInt("NAMS");
    static const SymbolsHeader = stringToInt("SYMB");
    static const BSSSegmentHeader = stringToInt("BSSG");
    static const DataSegmentHeader = stringToInt("DATA");
    static const ReadOnlyDataSegmentHeader = stringToInt("RODT");
    static const TextSegmentHeader = stringToInt("TEXT");
    static const StackSegmentHeader = stringToInt("STCK");
    static const HeapSegmentHeader = stringToInt("HEAP");
}

struct CapsuleProgramEncoder {
    mixin CapsuleProgramCoderMixin;
    mixin CapsuleEncoderMixin;
    
    void write(in CapsuleProgram program) {
        assert(program.bssSegment.type is CapsuleProgram.Segment.Type.BSS);
        assert(program.dataSegment.type is CapsuleProgram.Segment.Type.Data);
        assert(program.readOnlyDataSegment.type is CapsuleProgram.Segment.Type.ReadOnlyData);
        assert(program.textSegment.type is CapsuleProgram.Segment.Type.Text);
        assert(program.stackSegment.type is CapsuleProgram.Segment.Type.Stack);
        assert(program.heapSegment.type is CapsuleProgram.Segment.Type.Heap);
        FileHeader fileHeader = {
            name: ProgramHeader,
            versionName: FileVersion_2020_05_14,
            textEncoding: program.textEncoding,
            timeEncoding: program.timeEncoding,
            data: typeof(this).encodeFileHeaderData(program.architecture),
        };
        FileSectionHeader timestamp = {
            name: TimestampHeader,
            noContent: true,
            data: typeof(this).encodeFileSectionHeaderData(program.timestamp),
        };
        FileSectionHeader comment = {
            name: CommentHeader,
            omitSection: program.comment.length == 0,
            length: typeof(this).getPaddedBytesLength(program.comment.length),
            data: typeof(this).encodeFileSectionHeaderData(program.comment.length),
        };
        FileSectionHeader title = {
            name: TitleHeader,
            omitSection: program.title.length == 0,
            length: typeof(this).getPaddedBytesLength(program.title.length),
            data: typeof(this).encodeFileSectionHeaderData(program.title.length),
        };
        FileSectionHeader credit = {
            name: CreditHeader,
            omitSection: program.credit.length == 0,
            length: typeof(this).getPaddedBytesLength(program.credit.length),
            data: typeof(this).encodeFileSectionHeaderData(program.credit.length),
        };
        FileSectionHeader entry = {
            name: EntryHeader,
            noContent: true,
            data: typeof(this).encodeFileSectionHeaderData(program.entryOffset),
        };
        FileSectionHeader names = {
            name: NamesHeader,
            length: typeof(this).getNamesContentLength(program.names),
            entries: cast(uint) program.names.length,
            noContent: program.names.length == 0,
        };
        FileSectionHeader symbols = {
            name: SymbolsHeader,
            entryLength: SymbolEncodedLength,
            entries: cast(uint) program.symbols.length,
            noContent: program.symbols.length == 0,
        };
        FileSectionHeader bss = {
            name: BSSSegmentHeader,
            noContent: true,
            data: typeof(this).encodeFileSectionHeaderData(
                program.bssSegment.offset,
                program.bssSegment.length, 
                program.bssSegment.checksum,
            ),
        };
        FileSectionHeader data = {
            name: DataSegmentHeader,
            length: typeof(this).getPaddedBytesLength(program.dataSegment.bytes),
            noContent: program.dataSegment.bytes.length == 0,
            data: typeof(this).encodeFileSectionHeaderData(
                program.dataSegment.offset,
                program.dataSegment.length, 
                program.dataSegment.checksum,
            ),
        };
        FileSectionHeader readOnlyData = {
            name: ReadOnlyDataSegmentHeader,
            length: typeof(this).getPaddedBytesLength(program.readOnlyDataSegment.bytes),
            noContent: program.readOnlyDataSegment.bytes.length == 0,
            data: typeof(this).encodeFileSectionHeaderData(
                program.readOnlyDataSegment.offset,
                program.readOnlyDataSegment.length, 
                program.readOnlyDataSegment.checksum,
            ),
        };
        FileSectionHeader text = {
            name: TextSegmentHeader,
            length: typeof(this).getPaddedBytesLength(program.textSegment.bytes),
            noContent: program.textSegment.bytes.length == 0,
            data: typeof(this).encodeFileSectionHeaderData(
                program.textSegment.offset,
                program.textSegment.length, 
                program.textSegment.checksum,
            ),
        };
        FileSectionHeader stack = {
            name: StackSegmentHeader,
            noContent: true,
            data: typeof(this).encodeFileSectionHeaderData(
                program.stackSegment.offset,
                program.stackSegment.length, 
                program.stackSegment.checksum,
            ),
        };
        FileSectionHeader heap = {
            name: HeapSegmentHeader,
            noContent: true,
            data: typeof(this).encodeFileSectionHeaderData(
                program.heapSegment.offset,
                program.heapSegment.length, 
                program.heapSegment.checksum,
            ),
        };
        bool withHeader(
            in FileSectionHeader header, in uint name,
            void delegate() write
        ) {
            if(header.name == name) {
                write();
                return true;
            }
            else {
                return false;
            }
        }
        WriteSectionContentDelegate[] writers = [
            (header) => withHeader(header, TitleHeader, () => this.writeTextContent(program.title)),
            (header) => withHeader(header, CommentHeader, () => this.writeTextContent(program.comment)),
            (header) => withHeader(header, TitleHeader, () => this.writeTextContent(program.title)),
            (header) => withHeader(header, CreditHeader, () => this.writeTextContent(program.credit)),
            (header) => withHeader(header, NamesHeader, () => this.writeNamesContent(program.names)),
            (header) => withHeader(header, SymbolsHeader, () => this.writeSymbolsContent(program.symbols)),
            (header) => withHeader(header, DataSegmentHeader, () => this.writeSegmentContent(program.dataSegment)),
            (header) => withHeader(header, ReadOnlyDataSegmentHeader, () => this.writeSegmentContent(program.readOnlyDataSegment)),
            (header) => withHeader(header, TextSegmentHeader, () => this.writeSegmentContent(program.textSegment)),
        ];
        this.writeFile(fileHeader, [
            timestamp, comment, title, credit,
            entry, bss, data, readOnlyData, text, stack, heap,
            names, symbols,
        ], writers);
    }
    
    void writeTextContent(in string text) {
        this.writePaddedBytes(text);
    }
    
    void writeSegmentContent(in CapsuleProgram.Segment segment) {
        this.writePaddedBytes(segment.bytes);
    }
    
    static uint getNamesContentLength(in string[] names) {
        uint length = 4 * cast(uint) names.length;
        foreach(name; names) {
            length += typeof(this).getPaddedBytesLength(name.length);
        }
        return length;
    }
    
    void writeNamesContent(in string[] names) {
        foreach(name; names) {
            this.writeInt(cast(uint) name.length);
            this.writePaddedBytes(name);
        }
    }
    
    enum uint SymbolEncodedLength = 16;
    
    void writeSymbolsContent(in CapsuleProgram.Symbol[] symbols) {
        foreach(symbol; symbols) {
            this.writeShort(cast(ushort) symbol.type);
            this.writeShort(symbol.unused);
            this.writeInt(symbol.name);
            this.writeInt(symbol.length);
            this.writeInt(symbol.value);
        }
    }
}

struct CapsuleProgramDecoder {
    mixin CapsuleProgramCoderMixin;
    mixin CapsuleDecoderMixin;
    
    alias Segment = CapsuleProgram.Segment;
    
    CapsuleProgram program;
    
    typeof(this) read() {
        const fileHeader = this.readFileHeader();
        if(fileHeader.name != ProgramHeader) {
            this.setStatus(Status.UnexpectedFileType);
            return this;
        }
        if(fileHeader.versionName != FileVersion_2020_05_14) {
            this.setStatus(Status.UnknownFileVersion);
            return this;
        }
        this.program.textEncoding = (
            cast(CapsuleProgram.TextEncoding) fileHeader.textEncoding
        );
        this.program.timeEncoding = (
            cast(CapsuleProgram.TimeEncoding) fileHeader.timeEncoding
        );
        this.program.architecture = (
            cast(CapsuleProgram.Architecture) fileHeader.data[0]
        );
        // TODO: Check type, version, etc.
        ReadSectionContentDelegate[] readers = [
            (header) => (this.readTimestampSection(header)),
            (header) => (this.readCommentSection(header)),
            (header) => (this.readTitleSection(header)),
            (header) => (this.readCreditSection(header)),
            (header) => (this.readEntrySection(header)),
            (header) => (this.readNamesSection(header)),
            (header) => (this.readSymbolsSection(header)),
            (header) => (this.readBssSegmentSection(header)),
            (header) => (this.readDataSegmentSection(header)),
            (header) => (this.readReadOnlyDataSegmentSection(header)),
            (header) => (this.readTextSegmentSection(header)),
            (header) => (this.readStackSegmentSection(header)),
            (header) => (this.readHeapSegmentSection(header)),
        ];
        this.readFileContent(fileHeader, readers);
        return this;
    }
    
    bool readTimestampSection(in FileSectionHeader header) {
        if(header.name != TimestampHeader) return false;
        this.program.timestamp = header.longData[0];
        return true;
    }
    
    bool readCommentSection(in FileSectionHeader header) @trusted {
        if(header.name != CommentHeader) return false;
        const length = header.intData[0];
        this.program.comment = cast(string) this.readPaddedBytes(
            length <= header.length ? length : header.length
        );
        return true;
    }
    
    bool readTitleSection(in FileSectionHeader header) {
        if(header.name != TitleHeader) return false;
        const length = header.intData[0];
        this.program.title = cast(string) this.readPaddedBytes(
            length <= header.length ? length : header.length
        );
        return true;
    }
    
    bool readCreditSection(in FileSectionHeader header) {
        if(header.name != CreditHeader) return false;
        const length = header.intData[0];
        this.program.credit = cast(string) this.readPaddedBytes(
            length <= header.length ? length : header.length
        );
        return true;
    }
    
    bool readEntrySection(in FileSectionHeader header) {
        if(header.name != EntryHeader) return false;
        this.program.entryOffset = header.intData[0];
        return true;
    }
    
    bool readNamesSection(in FileSectionHeader header) @trusted {
        if(header.name != NamesHeader) return false;
        this.program.names.length = header.entries;
        for(uint i = 0; i < header.entries; i++) {
            const nameLength = this.readInt();
            this.program.names[i] = cast(string) this.readPaddedBytes(nameLength);
        }
        return true;
    }
    
    CapsuleProgram.Symbol readSymbol() {
        CapsuleProgram.Symbol symbol;
        symbol.type = cast(CapsuleProgram.Symbol.Type) this.readShort();
        symbol.unused = this.readShort();
        symbol.name = this.readInt();
        symbol.length = this.readInt();
        symbol.value = this.readInt();
        return symbol;
    }
    
    bool readSymbolsSection(in FileSectionHeader header) {
        if(header.name != SymbolsHeader) return false;
        this.program.symbols.length = header.entries;
        for(uint i = 0; i < header.entries; i++) {
            this.program.symbols[i] = this.readSymbol();
        }
        return true;
    }
    
    Segment readSegmentSection(
        in FileSectionHeader header, in Segment.Type type
    ) {
        Segment segment;
        segment.type = type;
        segment.offset = header.intData[0];
        segment.length = header.intData[1];
        segment.checksum = header.intData[2];
        if(Segment.typeIsInitialized(type)) {
            segment.bytes = this.readPaddedBytes(
                segment.length <= header.length ? segment.length : header.length
            );
        }
        return segment;
    }
    
    bool readBssSegmentSection(in FileSectionHeader header) {
        if(header.name != BSSSegmentHeader) return false;
        this.program.bssSegment = this.readSegmentSection(
            header, Segment.Type.BSS
        );
        return true;
    }
    
    bool readDataSegmentSection(in FileSectionHeader header) {
        if(header.name != DataSegmentHeader) return false;
        this.program.dataSegment = this.readSegmentSection(
            header, Segment.Type.Data
        );
        return true;
    }
    
    bool readReadOnlyDataSegmentSection(in FileSectionHeader header) {
        if(header.name != ReadOnlyDataSegmentHeader) return false;
        this.program.readOnlyDataSegment = this.readSegmentSection(
            header, Segment.Type.ReadOnlyData
        );
        return true;
    }
    
    bool readTextSegmentSection(in FileSectionHeader header) {
        if(header.name != TextSegmentHeader) return false;
        this.program.textSegment = this.readSegmentSection(
            header, Segment.Type.Text
        );
        return true;
    }
    
    bool readStackSegmentSection(in FileSectionHeader header) {
        if(header.name != StackSegmentHeader) return false;
        this.program.stackSegment = this.readSegmentSection(
            header, Segment.Type.Stack
        );
        return true;
    }
    
    bool readHeapSegmentSection(in FileSectionHeader header) {
        if(header.name != HeapSegmentHeader) return false;
        this.program.heapSegment = this.readSegmentSection(
            header, Segment.Type.Heap
        );
        return true;
    }
}

private version(unittest) {
    import capsule.core.enums : getEnumMemberName;
    import capsule.core.programstring : capsuleProgramToString;
    import capsule.core.stdio;
}

/// Test that encoding and then decoding
/// an program produces an identical result.
unittest {
    // Mock up an program file representation
    CapsuleProgram original;
    original.timestamp = 0x0011223344556677;
    original.entryOffset = 4;
    original.architecture = CapsuleProgram.Architecture.Capsule;
    original.textEncoding = CapsuleProgram.TextEncoding.Ascii;
    original.timeEncoding = CapsuleProgram.TimeEncoding.UnixEpochSeconds;
    original.title = "Test Title";
    original.comment = "Test Comment";
    CapsuleProgram.Segment bss = {
        type: CapsuleProgram.Segment.Type.BSS,
        offset: 0,
        length: 2,
        checksum: 0,
    };
    original.bssSegment = bss;
    CapsuleProgram.Segment data = {
        type: CapsuleProgram.Segment.Type.Data,
        offset: 2,
        length: 4,
        checksum: 0x12345678,
        bytes: [0, 3, 255, 15],
    };
    original.dataSegment = data;
    CapsuleProgram.Segment readOnlyData = {
        type: CapsuleProgram.Segment.Type.ReadOnlyData,
        offset: 8,
        length: 4,
        checksum: 0xaabbccdd,
        bytes: [30, 20, 10, 40],
    };
    original.readOnlyDataSegment = readOnlyData;
    CapsuleProgram.Segment text = {
        type: CapsuleProgram.Segment.Type.Text,
        offset: 12,
        length: 8,
        checksum: 0x00100100,
        bytes: [1, 2, 3, 4, 5, 6, 7, 8],
    };
    original.textSegment = text;
    CapsuleProgram.Segment stack = {
        type: CapsuleProgram.Segment.Type.Stack,
        offset: 32,
        length: 32,
        checksum: 0,
    };
    original.stackSegment = stack;
    CapsuleProgram.Segment heap = {
        type: CapsuleProgram.Segment.Type.Heap,
        offset: 64,
        length: 0,
        checksum: 0,
    };
    original.heapSegment = heap;
    // Add debug data
    original.names = ["one", "two", "three", "four", "five", "six"];
    CapsuleProgram.Symbol sym0 = {
        type: CapsuleProgram.Symbol.Type.Label,
        name: 0,
        length: 0,
        value: 0xff,
    };
    CapsuleProgram.Symbol sym1 = {
        type: CapsuleProgram.Symbol.Type.Procedure,
        name: 2,
        length: 64,
        value: 16,
    };
    original.symbols = [sym0, sym1];
    // Encode it and decode it back
    ubyte[] encoded;
    size_t readIndex = 0;
    void writeByte(in ubyte value) {
        encoded ~= value;
    }
    int readByte() {
        return readIndex >= encoded.length ? -1 : encoded[readIndex++];
    }
    CapsuleProgramEncoder(&writeByte).write(original);
    const decode = CapsuleProgramDecoder(&readByte).read();
    // Check the result
    //stdio.writeln("Status: ", getEnumMemberName(decode.status));
    //stdio.writeln(capsuleProgramToString(original, true));
    //stdio.writeln(capsuleProgramToString(decode.program, true));
    assert(decode.status is CapsuleProgramDecoder.Status.Ok);
    assert(decode.program == original);
}
