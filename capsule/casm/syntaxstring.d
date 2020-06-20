/**

This module provides functionality that can be used to produce a string
representation of a parsed Capsule assembly syntax node.

*/

module capsule.casm.syntaxstring;

private:

import capsule.meta.enums : getEnumMemberAttribute;
import capsule.range.range : toArray;
import capsule.string.escape : escapeCapsuleText;
import capsule.string.hex : getByteHexString, getHexString;
import capsule.string.writeint : writeInt;

import capsule.core.objstring : getCapsuleObjectReferenceTypeName;
import capsule.core.types : CapsuleOpcode, CapsuleRegisterParameter;
import capsule.core.typestrings : getCapsuleOpcodeName, getCapsuleRegisterName;

import capsule.casm.syntax : CapsuleAsmNode;

private alias Node = CapsuleAsmNode;

public nothrow @trusted:

/// Convert a capsule assembly syntax node into an assembly source
/// string representation.
string capsuleAsmNodeToString(in Node node) {
    if(node.type is Node.Type.None) {
        return null;
    }
    else if(node.isLabel) {
        return capsuleAsmLabelNodeToString(node);
    }
    else if(node.isInstruction || node.isPseudoInstruction) {
        return capsuleAsmInstructionNodeToString(node);
    }
    else if(node.isPadDirective) {
        return capsuleAsmPadDirectiveNodeToString(node);
    }
    else if(node.isByteDataDirective) {
        return capsuleAsmByteDataDirectiveNodeToString(node);
    }
    else if(node.isTextDirective) {
        return capsuleAsmTextDirectiveNodeToString(node);
    }
    else if(node.isConstDirective) {
        return capsuleAsmConstDirectiveNodeToString(node);
    }
    else if(node.isSymbolDirective) {
        return capsuleAsmSymbolDirectiveNodeToString(node);
    }
    else if(node.isIntDirective) {
        return capsuleAsmIntDirectiveNodeToString(node);
    }
    else if(node.isDirective) {
        return "." ~ node.getName();
    }
    else {
        assert(false, "Unhandled syntax node type: " ~ node.getName());
    }
}

string capsuleAsmNumberToString(in Node.Number number) {
    if(number.name.length <= 0) {
        return cast(string) getHexString(cast(uint) number.value).toArray();
    }
    string text = number.name;
    if(number.localType) {
        text ~= number.localType;
    }
    if(number.referenceType) {
        const refTypeName = getCapsuleObjectReferenceTypeName(
            number.referenceType
        );
        text ~= "[" ~ refTypeName ~ "]";
    }
    if(number.addend) {
        text ~= "[" ~ cast(string) writeInt(number.addend).toArray() ~ "]";
    }
    return text;
}

string capsuleAsmLabelNodeToString(in Node node) {
    assert(node.type is Node.Type.Label);
    return node.label.name ~ ":";
}

string capsuleAsmInstructionNodeToString(in Node node) @trusted {
    alias Immediate = Node.InstructionArgs.Immediate;
    alias RegisterParameter = CapsuleRegisterParameter;
    const opcode = cast(CapsuleOpcode) node.instruction.opcode;
    const rd = node.instruction.rd;
    const rs1 = node.instruction.rs1;
    const rs2 = node.instruction.rs2;
    const immediate = node.instruction.immediate;
    string argsText;
    string name;
    if(node.type is Node.Type.Instruction) {
        const opName = getEnumMemberAttribute!string(opcode);
        name = (opName.length ? opName : "[" ~ getByteHexString(opcode) ~ "]");
    }
    else if(node.type is Node.Type.PseudoInstruction) {
        const pseudoType = cast(Node.PseudoInstructionType) node.subtype;
        name = getEnumMemberAttribute!string(pseudoType);
    }
    else {
        assert(false, "Function called with wrong syntax node type.");
    }
    const args = node.instructionArgs;
    foreach(param; args.registerParamList) {
        switch(param) {
            case RegisterParameter.Destination:
                if(argsText.length) argsText ~= ", ";
                argsText ~= getCapsuleRegisterName(cast(ubyte) (rd & 0x7));
                break;
            case RegisterParameter.FirstSource:
                if(argsText.length) argsText ~= ", ";
                argsText ~= getCapsuleRegisterName(cast(ubyte) (rs1 & 0x7));
                break;
            case RegisterParameter.SecondSource:
                if(argsText.length) argsText ~= ", ";
                argsText ~= getCapsuleRegisterName(cast(ubyte) (rs2 & 0x7));
                break;
            default:
                break;
        }
    }
    if(args.immediate is Immediate.Always ||
        (immediate.name.length || immediate.referenceType || immediate.value != 0)
    ) {
        if(argsText.length) argsText ~= ", ";
        argsText ~= capsuleAsmNumberToString(immediate);
    }
    return argsText.length ? name ~ " " ~ argsText : name;
}

string capsuleAsmPadDirectiveNodeToString(in Node node) {
    assert(node.isPadDirective);
    return (
        "." ~ node.getName() ~ " " ~
        cast(string) getHexString(node.padDirective.size).toArray() ~ ", " ~
        getByteHexString(cast(ubyte) node.padDirective.fill)
    );
}

string capsuleAsmByteDataDirectiveNodeToString(in Node node) {
    assert(node.isByteDataDirective);
    string argsText;
    foreach(value; node.byteDataDirective.values) {
        if(argsText.length) argsText ~= ", ";
        argsText ~= capsuleAsmNumberToString(value);
    }
    return "." ~ node.getName() ~ " " ~ argsText;
}

string capsuleAsmTextDirectiveNodeToString(in Node node) {
    assert(node.isTextDirective);
    const text = cast(string) (
        escapeCapsuleText(node.textDirective.value).toArray()
    );
    return "." ~ node.getName() ~ " \"" ~ text ~ "\"";
}

string capsuleAsmConstDirectiveNodeToString(in Node node) {
    assert(node.isConstDirective);
    return (
        "." ~ node.getName() ~ " " ~ node.constDirective.name ~ ", " ~
        cast(string) getHexString(node.constDirective.value).toArray()
    );
}

string capsuleAsmSymbolDirectiveNodeToString(in Node node) {
    assert(node.isSymbolDirective);
    return "." ~ node.getName() ~ " " ~ node.symbolDirective.name;
}

string capsuleAsmIntDirectiveNodeToString(in Node node) {
    assert(node.isIntDirective);
    return (
        "." ~ node.getName() ~ " " ~
        cast(string) writeInt(node.intDirective.value).toArray()
    );
}
