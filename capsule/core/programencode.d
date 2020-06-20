/**

The functions in this module can be used to encode or decode
a Capsule program file using a condensed binary format.

*/

module capsule.core.programencode;

private:

import capsule.digest.crc : CRC64ISO;

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
    static const SourceHeader = stringToInt("SRCF");
    static const SourceLocationsHeader = stringToInt("SLOC");
}

struct CapsuleProgramEncoder {
    mixin CapsuleProgramCoderMixin;
    mixin CapsuleEncoderMixin;
    
    void write(in CapsuleProgram program) {
        assert(program.bssSegment.type is CapsuleProgram.Segment.Type.BSS);
        assert(program.dataSegment.type is CapsuleProgram.Segment.Type.Data);
        assert(program.readOnlyDataSegment.type is CapsuleProgram.Segment.Type.ReadOnlyData);
        assert(program.textSegment.type is CapsuleProgram.Segment.Type.Text);
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
            data: typeof(this).encodeFileSectionHeaderData(
                cast(uint) program.comment.length
            ),
        };
        FileSectionHeader title = {
            name: TitleHeader,
            omitSection: program.title.length == 0,
            length: typeof(this).getPaddedBytesLength(program.title.length),
            data: typeof(this).encodeFileSectionHeaderData(
                cast(uint) program.title.length
            ),
        };
        FileSectionHeader credit = {
            name: CreditHeader,
            omitSection: program.credit.length == 0,
            length: typeof(this).getPaddedBytesLength(program.credit.length),
            data: typeof(this).encodeFileSectionHeaderData(
                cast(uint) program.credit.length
            ),
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
        FileSectionHeader sourceLocations = {
            name: SourceLocationsHeader,
            omitSection: program.sourceMap.locations.length == 0,
            entries: cast(uint) program.sourceMap.locations.length,
            entryLength: SourceLocationEncodedLength,
            data: typeof(this).encodeFileSectionHeaderData(
                cast(uint) program.sourceMap.locations.length,
            ),
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
        FileSectionHeader[] fileSections = [
            timestamp, comment, title, credit,
            names, symbols, sourceLocations,
            entry, text, readOnlyData, data, bss,
        ];
        for(uint i = 0; i < program.sourceMap.sources.length; i++) {
            const source = program.sourceMap.sources[i];
            const textLength = 4 + (
                typeof(this).getPaddedBytesLength(source.name) +
                typeof(this).getPaddedBytesLength(source.content)
            );
            FileSectionHeader sourceSection = {
                name: SourceHeader,
                length: textLength,
                data: typeof(this).encodeFileSectionHeaderData(
                    i, source.encoding, source.unused,
                    cast(uint) source.name.length,
                    cast(uint) source.content.length,
                ),
            };
            fileSections ~= sourceSection;
        }
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
            (header) => withHeader(header, TitleHeader,
                () => this.writeTextContent(program.title)
            ),
            (header) => withHeader(header, CommentHeader,
                () => this.writeTextContent(program.comment)
            ),
            (header) => withHeader(header, TitleHeader,
                () => this.writeTextContent(program.title)
            ),
            (header) => withHeader(header, CreditHeader,
                () => this.writeTextContent(program.credit)
            ),
            (header) => withHeader(header, NamesHeader,
                () => this.writeNamesContent(program.names)
            ),
            (header) => withHeader(header, SymbolsHeader,
                () => this.writeSymbolsContent(program.symbols)
            ),
            (header) => withHeader(header, DataSegmentHeader,
                () => this.writeSegmentContent(program.dataSegment)
            ),
            (header) => withHeader(header, ReadOnlyDataSegmentHeader,
                () => this.writeSegmentContent(program.readOnlyDataSegment)
            ),
            (header) => withHeader(header, TextSegmentHeader,
                () => this.writeSegmentContent(program.textSegment)
            ),
            (header) => withHeader(header, SourceLocationsHeader,
                () => this.writeSourceLocationsContent(program.sourceMap.locations)
            ),
            (header) => withHeader(header, SourceHeader,
                () => this.writeSourceContent(program.sourceMap.sources[header.intData[0]], header)
            ),
        ];
        this.writeFile(fileHeader, fileSections, writers);
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
    
    enum SourceLocationEncodedLength = 24;
    
    void writeSourceLocationsContent(
        in CapsuleProgram.Source.Location[] locations
    ) {
        foreach(location; locations) {
            this.writeInt(location.source);
            this.writeInt(location.startAddress);
            this.writeInt(location.endAddress);
            this.writeInt(location.contentStartIndex);
            this.writeInt(location.contentEndIndex);
            this.writeInt(location.contentLineNumber);
        }
    }
    
    void writeSourceContent(
        in CapsuleProgram.Source source, in FileSectionHeader header
    ) @trusted {
        this.writeInt(source.checksum);
        this.writePaddedBytes(source.name);
        this.writePaddedBytes(source.content);
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
            (header) => (this.readSourceLocationsSection(header)),
            (header) => (this.readSourceSection(header)),
            (header) => (this.readBssSegmentSection(header)),
            (header) => (this.readDataSegmentSection(header)),
            (header) => (this.readReadOnlyDataSegmentSection(header)),
            (header) => (this.readTextSegmentSection(header)),
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
    
    bool readSourceLocationsSection(in FileSectionHeader header) {
        if(header.name != SourceLocationsHeader) return false;
        const length = header.intData[0];
        this.program.sourceMap.locations.length = length;
        for(size_t i = 0; i < length; i++) {
            CapsuleProgram.Source.Location location;
            location.source = this.readInt();
            location.startAddress = this.readInt();
            location.endAddress = this.readInt();
            location.contentStartIndex = this.readInt();
            location.contentEndIndex = this.readInt();
            location.contentLineNumber = this.readInt();
            this.program.sourceMap.locations[i] = location;
        }
        return true;
    }
    
    bool readSourceSection(in FileSectionHeader header) @trusted {
        if(header.name != SourceHeader) return false;
        CapsuleProgram.Source source;
        const index = header.intData[0];
        source.encoding = cast(CapsuleProgram.Source.Encoding) header.shortData[2];
        source.unused = header.shortData[2];
        const nameLength = header.intData[2];
        const contentLength = header.intData[3];
        source.checksum = this.readInt();
        source.name = cast(string) this.readPaddedBytes(nameLength);
        source.content = cast(string) this.readPaddedBytes(contentLength);
        if(index >= uint.max) {
            this.setStatus(Status.BadSectionContent);
            return true;
        }
        if(index >= this.program.sourceMap.sources.length) {
            this.program.sourceMap.sources.length = 1 + index;
        }
        this.program.sourceMap.sources[index] = source;
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
}

private version(unittest) {
    import capsule.meta.enums : getEnumMemberName;
    import capsule.core.programstring : capsuleProgramToString;
    import capsule.io.stdio;
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
    CapsuleProgram.Source src0 = {
        encoding: CapsuleProgram.Source.Encoding.None,
        checksum: 0x112211ff,
        name: "hello/world.d",
        content: "content content content content content",
    };
    CapsuleProgram.Source src1 = {
        encoding: CapsuleProgram.Source.Encoding.None,
        checksum: 0x4321abcd,
        name: "test/name.txt",
        content: "test source file content hello",
    };
    CapsuleProgram.Source src2 = {
        encoding: CapsuleProgram.Source.Encoding.None,
        checksum: 0x4321abcd,
        name: "fake/file/path",
        content: "bump",
    };
    CapsuleProgram.Source.Location srcLoc0 = {
        source: 0,
        startAddress: 1,
        endAddress: 8,
        contentStartIndex: 2,
        contentEndIndex: 10,
        contentLineNumber: 4,
    };
    CapsuleProgram.Source.Location srcLoc1 = {
        source: 1,
        startAddress: 2,
        endAddress: 4,
        contentStartIndex: 5,
        contentEndIndex: 6,
        contentLineNumber: 3,
    };
    CapsuleProgram.Source.Location srcLoc2 = {
        source: 2,
        startAddress: 0,
        endAddress: 200,
        contentStartIndex: 1234,
        contentEndIndex: 55,
        contentLineNumber: 70,
    };
    original.symbols = [sym0, sym1];
    original.sourceMap.sources = [src0, src1, src2];
    original.sourceMap.locations = [srcLoc0, srcLoc1, srcLoc2];
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
