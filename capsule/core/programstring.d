/**

This module provides functionality for getting a string
representation of Capsule program data. This is intended
primarily for debugging purposes.

*/

module capsule.core.programstring;

private:

import capsule.meta.enums : getEnumMemberName;
import capsule.range.concat : concat;
import capsule.range.join : join;
import capsule.range.map : map;
import capsule.range.range : toArray;
import capsule.string.hex : getHexString, getByteHexString;
import capsule.string.writeint : writeInt;

import capsule.core.objstring : getCapsuleObjectSymbolTypeName;
import capsule.core.program : CapsuleProgram;

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
