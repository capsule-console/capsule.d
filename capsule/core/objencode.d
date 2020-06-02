module capsule.core.objencode;

import capsule.core.crc : CRC64ISO;
import capsule.core.obj : CapsuleObject;

import capsule.core.encoding;

public:

/// Mixin containing common definitions used by both the
/// CapsuleObjectEncoder and CapsuleObjectDecoder types.
mixin template CapsuleObjectCoderMixin() {
    alias stringToInt = capsuleHeaderStringToInt;
    
    static const FileVersion_2020_05_14 = stringToInt!ulong("20200514");
    
    static const ObjectHeader = stringToInt!ulong("CAPSOBJT");
    static const TimestampHeader = stringToInt("TIME");
    static const SourceURIHeader = stringToInt("SURI");
    static const SourceHashHeader = stringToInt("HASH");
    static const CommentHeader = stringToInt("CMNT");
    static const EntryHeader = stringToInt("ENTR");
    static const NamesHeader = stringToInt("NAMS");
    static const SymbolsHeader = stringToInt("SYMB");
    static const ReferencesHeader = stringToInt("REFS");
    static const SectionsHeader = stringToInt("SECT");
}

/// Provides an interface for encoding a CapsuleObject and all its
/// data to a binary format appropriate for writing to a file.
struct CapsuleObjectEncoder {
    mixin CapsuleObjectCoderMixin;
    mixin CapsuleEncoderMixin;
    
    void write(in CapsuleObject object) {
        FileHeader fileHeader = {
            name: ObjectHeader,
            versionName: FileVersion_2020_05_14,
            textEncoding: object.textEncoding,
            timeEncoding: object.timeEncoding,
            data: typeof(this).encodeFileHeaderData(object.architecture),
        };
        FileSectionHeader timestamp = {
            name: TimestampHeader,
            noContent: true,
            data: typeof(this).encodeFileSectionHeaderData(object.timestamp),
        };
        FileSectionHeader sourceUri = {
            name: SourceURIHeader,
            omitSection: !object.sourceUri || !object.sourceUri.length,
            length: typeof(this).getPaddedBytesLength(object.sourceUri.length),
            data: typeof(this).encodeFileSectionHeaderData(object.sourceUri.length),
        };
        FileSectionHeader sourceHash = {
            name: SourceHashHeader,
            noContent: true,
            data: typeof(this).encodeFileSectionHeaderData(
                object.sourceHashType, uint(0), object.sourceHash
            ),
        };
        FileSectionHeader comment = {
            name: CommentHeader,
            omitSection: object.comment.length == 0,
            length: typeof(this).getPaddedBytesLength(object.comment.length),
            data: typeof(this).encodeFileSectionHeaderData(object.comment.length),
        };
        FileSectionHeader entry = {
            name: EntryHeader,
            omitSection: !object.hasEntry,
            noContent: true,
            data: typeof(this).encodeFileSectionHeaderData(
                object.entrySection, object.entryOffset
            ),
        };
        FileSectionHeader names = {
            name: NamesHeader,
            length: typeof(this).getNamesContentLength(object.names),
            entries: cast(uint) object.names.length,
            noContent: object.names.length == 0,
        };
        FileSectionHeader symbols = {
            name: SymbolsHeader,
            entryLength: SymbolEncodedLength,
            entries: cast(uint) object.symbols.length,
            noContent: object.symbols.length == 0,
        };
        FileSectionHeader references = {
            name: ReferencesHeader,
            entryLength: ReferenceEncodedLength,
            entries: cast(uint) object.references.length,
            noContent: object.references.length == 0,
        };
        FileSectionHeader sections = {
            name: SectionsHeader,
            length: typeof(this).getSectionsContentLength(object.sections),
            entries: cast(uint) object.sections.length,
            noContent: object.sections.length == 0,
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
            (header) => withHeader(header, SourceURIHeader, () => this.writeTextContent(object.sourceUri)),
            (header) => withHeader(header, CommentHeader, () => this.writeTextContent(object.comment)),
            (header) => withHeader(header, NamesHeader, () => this.writeNamesContent(object.names)),
            (header) => withHeader(header, SymbolsHeader, () => this.writeSymbolsContent(object.symbols)),
            (header) => withHeader(header, ReferencesHeader, () => this.writeReferencesContent(object.references)),
            (header) => withHeader(header, SectionsHeader, () => this.writeSectionsContent(object.sections)),
        ];
        this.writeFile(fileHeader, [
            timestamp, sourceUri, sourceHash, comment,
            entry, names, symbols, references, sections,
        ], writers);
    }
    
    void writeTextContent(in string text) {
        this.writePaddedBytes(text);
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
    
    enum uint SymbolEncodedLength = 20;
    
    void writeSymbolsContent(in CapsuleObject.Symbol[] symbols) {
        foreach(symbol; symbols) {
            this.writeInt(symbol.section);
            this.writeShort(cast(ushort) symbol.type);
            this.writeShort(cast(ushort) symbol.visibility);
            this.writeInt(symbol.name);
            this.writeInt(symbol.length);
            this.writeInt(symbol.value);
        }
    }
    
    enum uint ReferenceEncodedLength = 20;
    
    void writeReferencesContent(in CapsuleObject.Reference[] references) {
        foreach(reference; references) {
            this.writeInt(reference.section);
            this.writeShort(cast(ushort) reference.type);
            this.writeByte(cast(ubyte) reference.localType);
            this.writeByte(reference.unused);
            this.writeInt(reference.name);
            this.writeInt(reference.offset);
            this.writeInt(cast(uint) reference.addend);
        }
    }
    
    static uint getSectionsContentLength(in CapsuleObject.Section[] sections) {
        uint length = 24 * cast(uint) sections.length;
        foreach(section; sections) {
            length += (section.isInitialized ?
                typeof(this).getPaddedBytesLength(section.bytes.length) : 0
            );
        }
        return length;
    }
    
    void writeSectionsContent(in CapsuleObject.Section[] sections) {
        foreach(section; sections) {
            this.writeShort(cast(ushort) section.type);
            this.writeShort(section.unused);
            this.writeInt(section.name);
            this.writeInt(section.alignment);
            this.writeInt(cast(uint) section.priority);
            this.writeInt(section.checksum);
            if(section.isInitialized) {
                this.writeInt(cast(uint) section.bytes.length);
                this.writePaddedBytes(section.bytes);
            }
            else {
                this.writeInt(section.length);
            }
        }
    }
}

/// Provides an interface for decoding a CapsuleObject and all its
/// data from a binary format, e.g. data read from a file.
struct CapsuleObjectDecoder {
    mixin CapsuleObjectCoderMixin;
    mixin CapsuleDecoderMixin;
    
    CapsuleObject object;
    
    typeof(this) read() {
        const fileHeader = this.readFileHeader();
        if(fileHeader.name != ObjectHeader) {
            this.setStatus(Status.UnexpectedFileType);
            return this;
        }
        if(fileHeader.versionName != FileVersion_2020_05_14) {
            this.setStatus(Status.UnknownFileVersion);
            return this;
        }
        this.object.textEncoding = (
            cast(CapsuleObject.TextEncoding) fileHeader.textEncoding
        );
        this.object.timeEncoding = (
            cast(CapsuleObject.TimeEncoding) fileHeader.timeEncoding
        );
        this.object.architecture = (
            cast(CapsuleObject.Architecture) fileHeader.data[0]
        );
        // TODO: Check type, version, etc.
        ReadSectionContentDelegate[] readers = [
            (header) => (this.readTimestampSection(header)),
            (header) => (this.readSourceUriSection(header)),
            (header) => (this.readSourceHashSection(header)),
            (header) => (this.readCommentSection(header)),
            (header) => (this.readEntrySection(header)),
            (header) => (this.readNamesSection(header)),
            (header) => (this.readSymbolsSection(header)),
            (header) => (this.readReferencesSection(header)),
            (header) => (this.readSectionsSection(header)),
        ];
        this.readFileContent(fileHeader, readers);
        return this;
    }
    
    bool readTimestampSection(in FileSectionHeader header) {
        if(header.name != TimestampHeader) return false;
        this.object.timestamp = header.longData[0];
        return true;
    }
    
    bool readSourceUriSection(in FileSectionHeader header) {
        if(header.name != SourceURIHeader) return false;
        const length = header.intData[0];
        this.object.sourceUri = cast(string) this.readPaddedBytes(
            length <= header.length ? length : header.length
        );
        return true;
    }
    
    bool readSourceHashSection(in FileSectionHeader header) {
        if(header.name != SourceHashHeader) return false;
        object.sourceHashType = cast(HashType) header.intData[0];
        object.sourceHash = header.longData[1];
        return true;
    }
    
    bool readCommentSection(in FileSectionHeader header) @trusted {
        if(header.name != CommentHeader) return false;
        const length = header.intData[0];
        this.object.comment = cast(string) this.readPaddedBytes(
            length <= header.length ? length : header.length
        );
        return true;
    }
    
    bool readEntrySection(in FileSectionHeader header) {
        if(header.name != EntryHeader) return false;
        this.object.hasEntry = true;
        this.object.entrySection = header.intData[0];
        this.object.entryOffset = header.intData[1];
        return true;
    }
    
    bool readNamesSection(in FileSectionHeader header) @trusted {
        if(header.name != NamesHeader) return false;
        this.object.names.length = header.entries;
        for(uint i = 0; i < header.entries; i++) {
            const nameLength = this.readInt();
            this.object.names[i] = cast(string) this.readPaddedBytes(nameLength);
        }
        return true;
    }
    
    CapsuleObject.Symbol readSymbol() {
        CapsuleObject.Symbol symbol;
        symbol.section = this.readInt();
        symbol.type = cast(CapsuleObject.Symbol.Type) this.readShort();
        symbol.visibility = cast(CapsuleObject.Symbol.Visibility) this.readShort();
        symbol.name = this.readInt();
        symbol.length = this.readInt();
        symbol.value = this.readInt();
        return symbol;
    }
    
    bool readSymbolsSection(in FileSectionHeader header) {
        if(header.name != SymbolsHeader) return false;
        this.object.symbols.length = header.entries;
        for(uint i = 0; i < header.entries; i++) {
            this.object.symbols[i] = this.readSymbol();
        }
        return true;
    }
    
    CapsuleObject.Reference readReference() {
        CapsuleObject.Reference reference;
        reference.section = this.readInt();
        reference.type = cast(CapsuleObject.Reference.Type) this.readShort();
        reference.localType = cast(CapsuleObject.Reference.LocalType) this.readByte();
        reference.unused = this.readByte();
        reference.name = this.readInt();
        reference.offset = this.readInt();
        reference.addend = cast(int) this.readInt();
        return reference;
    }
    
    bool readReferencesSection(in FileSectionHeader header) {
        if(header.name != ReferencesHeader) return false;
        this.object.references.length = header.entries;
        for(uint i = 0; i < header.entries; i++) {
            this.object.references[i] = this.readReference();
        }
        return true;
    }
    
    CapsuleObject.Section readSection() {
        CapsuleObject.Section section;
        section.type = cast(CapsuleObject.Section.Type) this.readShort();
        section.unused = this.readShort();
        section.name = this.readInt();
        section.alignment = this.readInt();
        section.priority = cast(int) this.readInt();
        section.checksum = this.readInt();
        section.length = this.readInt();
        if(section.isInitialized) {
            section.bytes = this.readPaddedBytes(section.length);
        }
        return section;
    }
    
    bool readSectionsSection(in FileSectionHeader header) {
        if(header.name != SectionsHeader) return false;
        this.object.sections.length = header.entries;
        for(uint i = 0; i < header.entries; i++) {
            this.object.sections[i] = this.readSection();
        }
        return true;
    }
}

private version(unittest) {
    import capsule.core.enums : getEnumMemberName;
    import capsule.core.objstring : capsuleObjectToString;
    import capsule.core.stdio;
}

/// Test that encoding and then decoding
/// an object produces an identical result.
unittest {
    // Mock up an object file representation
    CapsuleObject original;
    original.timestamp = 0x0011223344556677;
    original.sourceUri = "file://somewhere.casm";
    original.sourceHash = 0xfedcba987654321;
    original.hasEntry = true;
    original.entrySection = 0;
    original.entryOffset = 4;
    original.architecture = CapsuleObject.Architecture.Capsule;
    original.textEncoding = CapsuleObject.TextEncoding.Ascii;
    original.timeEncoding = CapsuleObject.TimeEncoding.UnixEpochSeconds;
    original.comment = "Test Comment";
    original.names = ["hello", "world", "ok", "greetings"];
    CapsuleObject.Symbol sym0 = {
        section: 0,
        type: CapsuleObject.Symbol.Type.Label,
        visibility: CapsuleObject.Symbol.Visibility.Local,
        name: 0,
        value: 10,
    };
    CapsuleObject.Symbol sym1 = {
        section: 2,
        type: CapsuleObject.Symbol.Type.Constant,
        visibility: CapsuleObject.Symbol.Visibility.Global,
        name: 1,
        value: uint.max,
    };
    CapsuleObject.Symbol sym2 = {
        section: 0,
        type: CapsuleObject.Symbol.Type.Procedure,
        visibility: CapsuleObject.Symbol.Visibility.Export,
        name: 3,
        length: 16,
        value: 6,
    };
    CapsuleObject.Symbol sym3 = {
        section: 1,
        type: CapsuleObject.Symbol.Type.Variable,
        visibility: CapsuleObject.Symbol.Visibility.Extern,
        name: 2,
        length: 4,
        value: 0,
    };
    CapsuleObject.Reference ref0 = {
        section: 0,
        type: CapsuleObject.Reference.Type.AbsoluteHalfWord,
        localType: CapsuleObject.Reference.LocalType.Forward,
        name: 1,
        offset: 0,
        addend: -8,
    };
    CapsuleObject.Reference ref1 = {
        section: 2,
        type: CapsuleObject.Reference.Type.PCRelativeAddressHighHalf,
        name: 2,
        offset: 10,
        addend: +2,
    };
    CapsuleObject.Section sec0 = {
        type: CapsuleObject.Section.Type.Text,
        name: 3,
        alignment: 4,
        length: 16,
        priority: +1,
        bytes: [
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
            0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
        ],
    };
    CapsuleObject.Section sec1 = {
        type: CapsuleObject.Section.Type.Data,
        alignment: 12,
        length: 16,
        bytes: [
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
            0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
        ],
    };
    CapsuleObject.Section sec2 = {
        type: CapsuleObject.Section.Type.ReadOnlyData,
        alignment: 16,
        length: 2,
        priority: -50,
        bytes: [0x00, 0x00],
    };
    original.symbols ~= [sym0, sym1, sym2, sym3];
    original.references ~= [ref0, ref1];
    original.sections ~= [sec0, sec1, sec2];
    // Encode it and decode it back
    ubyte[] encoded;
    size_t readIndex = 0;
    void writeByte(in ubyte value) {
        encoded ~= value;
    }
    int readByte() {
        return readIndex >= encoded.length ? -1 : encoded[readIndex++];
    }
    CapsuleObjectEncoder(&writeByte).write(original);
    const decode = CapsuleObjectDecoder(&readByte).read();
    // Check the result
    //stdio.writeln("Status: ", getEnumMemberName(decode.status));
    //stdio.writeln(capsuleObjectToString(original));
    //stdio.writeln(capsuleObjectToString(decode.object));
    assert(decode.status is CapsuleObjectDecoder.Status.Ok);
    assert(decode.object == original);
}
