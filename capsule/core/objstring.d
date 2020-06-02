module capsule.core.objstring;

import capsule.core.concat : concat;
import capsule.core.enums : getEnumMemberName, getEnumMemberAttribute;
import capsule.core.hex : getHexString, getByteHexString;
import capsule.core.join : join;
import capsule.core.map : map;
import capsule.core.obj : CapsuleObject;
import capsule.core.range : toArray;
import capsule.core.writeint : writeInt;

nothrow public:

string getCapsuleObjectSectionTypeName(in CapsuleObject.Section.Type type) {
    const name = getEnumMemberAttribute!string(type);
    return name.length ? name : "unknown";
}

string getCapsuleObjectSymbolTypeName(in CapsuleObject.Symbol.Type type) {
    const name = getEnumMemberAttribute!string(type);
    return name.length ? name : "unknown";
}

string getCapsuleObjectSymbolVisibilityName(
    in CapsuleObject.Symbol.Visibility visibility
) {
    const name = getEnumMemberAttribute!string(visibility);
    return name.length ? name : "unknown";
}

string getCapsuleObjectReferenceTypeName(in CapsuleObject.Reference.Type type) {
    const name = getEnumMemberAttribute!string(type);
    return name.length ? name : "unknown";
}

/// Get a human-readable string representation of a CapsuleObject.
/// Intended for debugging purposes.
string capsuleObjectToString(
    in CapsuleObject object, in bool verbose = false
) {
    string getName(in uint index) {
        return index < object.names.length ? object.names[index] : "[error]";
    }
    string getOptionalName(in uint index) {
        return index < object.names.length ? object.names[index] : null;
    }
    return cast(string) concat(
        "CAPSOBJT\n",
        "  architecture: ", getHexString(cast(uint) object.architecture), "\n",
        "  text encoding: ", getEnumMemberName(object.textEncoding), "\n",
        "  time encoding: ", getEnumMemberName(object.timeEncoding), "\n",
        "  timestamp: ", writeInt(object.timestamp), "\n",
        "  source uri: ", object.sourceUri, "\n",
        "  source hash: ", getHexString(object.sourceHash), "\n",
        "  has entry? ", (object.hasEntry ? "yes" : "no"), "\n",
        "  entry section: ", (object.hasEntry ? cast(string) writeInt(object.entrySection).toArray() : "none"), "\n",
        "  entry offset: ", getHexString(object.entryOffset), "\n",
        "  comment: ", object.comment, "\n",
        "names (" , writeInt(object.names.length), "):\n",
        "  ", join("\n  ", object.names), "\n",
        "symbols (" , writeInt(object.symbols.length), "):\n",
        "  ", join("\n  ", object.symbols.map!(symbol => concat(
            getName(symbol.name), "\n",
            "    type: ", getCapsuleObjectSymbolTypeName(symbol.type), "\n",
            "    visibility: ", getCapsuleObjectSymbolVisibilityName(symbol.visibility), "\n",
            "    section: ", writeInt(symbol.section), "\n",
            "    length: ", writeInt(symbol.length), "\n",
            "    value: ", getHexString(symbol.value),
        ))), "\n",
        "references (" , writeInt(object.references.length), "):\n",
        "  ", join("\n  ", object.references.map!(reference => concat(
            getName(reference.name), (reference.localType ? cast(string) [reference.localType] : ""),
            "[", getCapsuleObjectReferenceTypeName(reference.type), "]\n",
            "    section: ", writeInt(reference.section), "\n",
            "    offset: ", getHexString(reference.offset), "\n",
            "    addend: ", writeInt(reference.addend),
        ))), "\n",
        "sections (" , writeInt(object.sections.length), "):\n",
        "  ", join("\n  ", object.sections.map!(section => concat(
            getCapsuleObjectSectionTypeName(section.type), " ", getOptionalName(section.name), "\n",
            "    alignment: ", writeInt(section.alignment), "\n",
            "    priority: ", writeInt(section.priority), "\n",
            "    length: ", writeInt(section.length),
            (!verbose ? "" : "\n    data: " ~ cast(string) getHexString(section.bytes).toArray())
        ))),
    ).toArray();
}
