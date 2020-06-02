module capsule.core.programstring;

import capsule.core.concat : concat;
import capsule.core.enums : getEnumMemberName;
import capsule.core.hex : getHexString, getByteHexString;
import capsule.core.join : join;
import capsule.core.map : map;
import capsule.core.objstring : getCapsuleObjectSymbolTypeName;
import capsule.core.program : CapsuleProgram;
import capsule.core.range : toArray;
import capsule.core.writeint : writeInt;

public:

/// Get a human-readable string representation of a CapsuleProgram.
/// Intended for debugging purposes.
string capsuleProgramToString(
    in CapsuleProgram program, in bool verbose = false
) {
    string getName(in uint index) {
        return index < program.names.length ? program.names[index] : "[error]";
    }
    return cast(string) concat(
        "CAPSPROG\n",
        "  architecture: ", getHexString(cast(uint) program.architecture), "\n",
        "  text encoding: ", getEnumMemberName(program.textEncoding), "\n",
        "  time encoding: ", getEnumMemberName(program.timeEncoding), "\n",
        "  timestamp: ", writeInt(program.timestamp), "\n",
        "  title: ", program.title, "\n",
        "  credit: ", program.credit, "\n",
        "  comment: ", program.comment, "\n",
        "  entry offset: ", getHexString(program.entryOffset), "\n",
        "bss:\n",
        "  length: ", writeInt(program.bssSegment.length), "\n",
        "  offset: ", getHexString(program.bssSegment.offset), "\n",
        "  checksum: ", getHexString(program.bssSegment.checksum), "\n",
        "data:\n",
        "  length: ", writeInt(program.dataSegment.length), "\n",
        "  offset: ", getHexString(program.dataSegment.offset), "\n",
        "  checksum: ", getHexString(program.dataSegment.checksum), "\n",
        (verbose ?
            "  bytes: " ~ cast(string) getHexString(program.dataSegment.bytes).toArray() ~ "\n" : ""
        ),
        "rodata:\n",
        "  length: ", writeInt(program.readOnlyDataSegment.length), "\n",
        "  offset: ", getHexString(program.readOnlyDataSegment.offset), "\n",
        "  checksum: ", getHexString(program.readOnlyDataSegment.checksum), "\n",
        (verbose ?
            "  bytes: " ~ cast(string) getHexString(program.readOnlyDataSegment.bytes).toArray() ~ "\n" : ""
        ),
        "text:\n",
        "  length: ", writeInt(program.textSegment.length), "\n",
        "  offset: ", getHexString(program.textSegment.offset), "\n",
        "  checksum: ", getHexString(program.textSegment.checksum), "\n",
        (verbose ?
            "  bytes: " ~ cast(string) getHexString(program.textSegment.bytes).toArray() ~ "\n" : ""
        ),
        "stack:\n",
        "  length: ", writeInt(program.stackSegment.length), "\n",
        "  offset: ", getHexString(program.stackSegment.offset), "\n",
        "  checksum: ", getHexString(program.stackSegment.checksum), "\n",
        "heap:\n",
        "  length: ", writeInt(program.heapSegment.length), "\n",
        "  offset: ", getHexString(program.heapSegment.offset), "\n",
        "  checksum: ", getHexString(program.heapSegment.checksum), "\n",
        "names (" , writeInt(program.names.length), "):\n",
        "  ", join("\n  ", program.names), "\n",
        "symbols (" , writeInt(program.symbols.length), "):\n",
        "  ", join("\n  ", program.symbols.map!(symbol => concat(
            getName(symbol.name), "\n",
            "    type: ", getCapsuleObjectSymbolTypeName(symbol.type), "\n",
            "    length: ", writeInt(symbol.length), "\n",
            "    value: ", getHexString(symbol.value),
        ))),
    ).toArray();
}
