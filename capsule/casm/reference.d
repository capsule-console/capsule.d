module capsule.casm.reference;

import capsule.core.obj : CapsuleObjectReference, CapsuleObjectReferenceType;

import capsule.casm.messages : CapsuleAsmMessageStatus;

public nothrow @safe @nogc:

/// Used as a default template parameter value for the
/// findCapsuleObjectPcRelHighReference helper function
alias DefaultCapsuleObjectReferenceFilter = (hiRef) => true;

/// Return type for resolveCapsuleObjectReference
struct ResolveCapsuleObjectReferenceResult {
    nothrow @safe @nogc:
    
    alias Status = CapsuleAsmMessageStatus;
    alias Type = CapsuleObjectReferenceType;
    
    static const Invalid = typeof(this)(Status.InvalidObjectReference);
    static const InvalidType = typeof(this)(Status.InvalidObjectReferenceType);
    static const OutOfBounds = typeof(this)(Status.ReferenceOutOfBounds);
    static const ValueOverflow = typeof(this)(Status.ReferenceValueOverflow);
    
    Status status;
    uint writeValue;
    
    bool ok() const {
        return this.status is Status.Ok;
    }
}

/// Helper for resolveCapsuleObjectReference to handle PC-relative references
auto resolveReferencePcRel(
    in uint pcOffset, in int addend, in int value, in uint length = 0
) {
    alias Status = CapsuleAsmMessageStatus;
    struct Result {
        Status status = Status.Ok;
        int value = 0;
    }
    const pcRelValue = (
        (cast(long) value + addend + length) - cast(long) pcOffset
    );
    const ovf = pcRelValue < int.min || pcRelValue > int.max;
    return Result(
        ovf ? Status.ReferencePCRelOverflow : Status.Ok, cast(int) pcRelValue
    );
}

auto resolveCapsuleObjectReferenceValue(
    in CapsuleObjectReferenceType type,
    in uint pcOffset, in int addend, in uint value, in uint length
) @trusted {
    // Handy aliases
    alias Reference = CapsuleObjectReference;
    alias Result = ResolveCapsuleObjectReferenceResult;
    alias Status = CapsuleAsmMessageStatus;
    alias Type = CapsuleObjectReferenceType;
    // Initialize state
    uint writeValue = 0;
    // Determine exactly what is being written and to where,
    // given the reference type
    switch(type) {
        // Missing or invalid reference type
        case Type.None:
            return Result.InvalidType;
        // Reference to the absolute value of a symbol
        case Type.AbsoluteByte:
            const sumValue = cast(uint) (addend + value);
            writeValue = sumValue & 0x000000FF;
            break;
        case Type.AbsoluteHalfWord:
            const sumValue = cast(uint) (addend + value);
            writeValue = sumValue & 0x0000FFFF;
            break;
        case Type.AbsoluteWord:
            const sumValue = cast(uint) (addend + value);
            writeValue = sumValue;
            break;
        case Type.AbsoluteWordLowHalf:
            const sumValue = cast(uint) (addend + value);
            writeValue = sumValue & 0x0000FFFF;
            break;
        case Type.AbsoluteWordHighHalf:
            const sumValue = cast(uint) (addend + value);
            writeValue = (
                ((sumValue >>> 16) & 0x0000FFFF) +
                ((sumValue >> 15) & 1)
            );
            break;
        case Type.AbsoluteWordSoloHighHalf:
            const sumValue = cast(uint) (addend + value);
            writeValue = (sumValue >>> 16);
            break;
        // Reference to the length of a symbol definition
        case Type.LengthByte:
            const sumValue = cast(uint) (addend + length);
            writeValue = sumValue & 0x000000FF;
            break;
        case Type.LengthHalfWord:
            const sumValue = cast(uint) (addend + length);
            writeValue = sumValue & 0x0000FFFF;
            break;
        case Type.LengthWord:
            const sumValue = cast(uint) (addend + length);
            writeValue = sumValue;
            break;
        case Type.LengthWordLowHalf:
            const sumValue = cast(uint) (addend + length);
            writeValue = sumValue & 0x0000FFFF;
            break;
        case Type.LengthWordHighHalf:
            const sumValue = cast(uint) (addend + length);
            writeValue = (
                ((sumValue >>> 16) & 0x0000FFFF) +
                ((sumValue >> 15) & 1)
            );
            break;
        case Type.LengthWordSoloHighHalf:
            const sumValue = cast(uint) (addend + length);
            writeValue = (sumValue >>> 16);
            break;
        // Reference to the PC-relative offset of a symbol's address
        case Type.PCRelativeAddressHalf:
            const pcRel = resolveReferencePcRel(
                pcOffset, addend, cast(int) value
            );
            if(pcRel.status) return Result(pcRel.status);
            if(pcRel.value < short.min || pcRel.value > short.max) {
                return Result.ValueOverflow;
            }
            //resolvedValue = cast(uint) (addend + value);
            writeValue = (cast(uint) pcRel.value) & 0x0000FFFF;
            break;
        case Type.PCRelativeAddressWord:
            const pcRel = resolveReferencePcRel(
                pcOffset, addend, cast(int) value
            );
            if(pcRel.status) return Result(pcRel.status);
            //resolvedValue = cast(uint) (addend + value);
            writeValue = cast(uint) pcRel.value;
            break;
        case Type.PCRelativeAddressLowHalf: goto case;
        case Type.PCRelativeAddressNearLowHalf:
            const pcRel = resolveReferencePcRel(
                pcOffset, addend, cast(int) value
            );
            if(pcRel.status) return Result(pcRel.status);
            //resolvedValue = cast(uint) (addend + value);
            writeValue = (cast(uint) pcRel.value) & 0x0000FFFF;
            break;
        case Type.PCRelativeAddressHighHalf:
            const pcRel = resolveReferencePcRel(
                pcOffset, addend, cast(int) value
            );
            if(pcRel.status) return Result(pcRel.status);
            //resolvedValue = cast(uint) (addend + value);
            writeValue = cast(uint) (
                ((pcRel.value >>> 16)) +
                ((pcRel.value >> 15) & 1)
            );
            break;
        case Type.PCRelativeAddressSoloHighHalf:
            const pcRel = resolveReferencePcRel(
                pcOffset, addend, cast(int) value
            );
            if(pcRel.status) return Result(pcRel.status);
            //resolvedValue = cast(uint) (addend + value);
            writeValue = (pcRel.value >>> 16);
            break;
        // Reference to the PC-relative offset of a symbol's end,
        // i.e. to the sum of its address and its length
        case Type.EndPCRelativeAddressHalf:
            const pcRel = resolveReferencePcRel(
                pcOffset, addend, cast(int) value, length
            );
            if(pcRel.status) return Result(pcRel.status);
            if(pcRel.value < short.min || pcRel.value > short.max) {
                return Result.ValueOverflow;
            }
            //resolvedValue = cast(uint) (addend + value + length);
            writeValue = (cast(uint) pcRel.value) & 0x0000FFFF;
            break;
        case Type.EndPCRelativeAddressWord:
            const pcRel = resolveReferencePcRel(
                pcOffset, addend, cast(int) value, length
            );
            if(pcRel.status) return Result(pcRel.status);
            //resolvedValue = cast(uint) (addend + value + length);
            writeValue = cast(uint) pcRel.value;
            break;
        case Type.EndPCRelativeAddressLowHalf: goto case;
        case Type.EndPCRelativeAddressNearLowHalf:
            const pcRel = resolveReferencePcRel(
                pcOffset, addend, cast(int) value, length
            );
            if(pcRel.status) return Result(pcRel.status);
            //resolvedValue = cast(uint) (addend + value + length);
            writeValue = (cast(uint) pcRel.value) & 0x0000FFFF;
            break;
        case Type.EndPCRelativeAddressHighHalf:
            const pcRel = resolveReferencePcRel(
                pcOffset, addend, cast(int) value, length
            );
            if(pcRel.status) return Result(pcRel.status);
            //resolvedValue = cast(uint) (addend + value + length);
            writeValue = cast(uint) (
                ((pcRel.value >>> 16)) +
                ((pcRel.value >> 15) & 1)
            );
            break;
        case Type.EndPCRelativeAddressSoloHighHalf:
            const pcRel = resolveReferencePcRel(
                pcOffset, addend, cast(int) value, length
            );
            if(pcRel.status) return Result(pcRel.status);
            //resolvedValue = cast(uint) (addend + value + length);
            writeValue = (pcRel.value >>> 16);
            break;
        // Unknown reference type
        default:
            return Result.InvalidType;
    }
    // All done
    return Result(Status.Ok, writeValue);
}

/// Helper to resolve a reference recorded in a Capsule object file.
/// The function requires:
/// - A byte data array in which the reference is located
/// - The reference type
/// - The byte offset of the reference in the byte data array,
/// - The relevant byte offset of the program counter, for "pcrel" references
/// - The reference's constant addend value
/// - The value of the symbol or label or etc. referenced by the label
///   For a label this should be the offset within the same bytes array
/// - The length in bytes of the symbol definition, or 0 if length unspecified
auto resolveCapsuleObjectReference(
    ref ubyte[] bytes, in CapsuleObjectReferenceType type,
    in uint offset, in uint pcOffset,
    in int addend, in uint value, in uint length
) @trusted {
    // Handy aliases
    alias Reference = CapsuleObjectReference;
    alias Result = ResolveCapsuleObjectReferenceResult;
    alias Status = CapsuleAsmMessageStatus;
    alias Type = CapsuleObjectReferenceType;
    // Get information about what to write and where
    const uint writeOffset = Reference.typeOffset(type);
    const uint writeLength = Reference.typeLength(type);
    assert(writeLength);
    const resolveValue = resolveCapsuleObjectReferenceValue(
        type, pcOffset, addend, value, length
    );
    if(!resolveValue.ok) {
        return resolveValue;
    }
    const writeValue = resolveValue.writeValue;
    // Odd maths is in order to not have comparisons thwarted by overflow
    // Essentially this makes sure offset + writeLength + writeOffset,
    // the high bound of affected bytes, doesn't exceed the bytes array length.
    if((writeLength + writeOffset > bytes.length) || (
        offset > bytes.length - writeLength - writeOffset
    )) {
        return Result.OutOfBounds;
    }
    // Now write the value to the bytes array
    const uint byteOffset = offset + writeOffset;
    if(writeLength == 1) {
        bytes[byteOffset] = cast(ubyte) writeValue;
    }
    else if(writeLength == 2) {
        *(cast(ushort*) &bytes[byteOffset]) = cast(ushort) writeValue;
    }
    else if(writeLength == 4) {
        *(cast(uint*) &bytes[byteOffset]) = cast(uint) writeValue;
    }
    else {
        assert(false, "Invalid reference resolution write length.");
    }
    // All done
    return resolveValue;
}

/// Helper function for finding the pcrel_hi reference which corresponds
/// to a pcrel_lo or pcrel_near_lo reference.
auto findCapsuleObjectPcRelHighReference(
    alias filter = DefaultCapsuleObjectReferenceFilter, Reference, Name
)(
    ref Reference[] references, in CapsuleObjectReferenceType lowRefType,
    in Name lowRefName, in uint hiRefOffset
) {
    alias Type = CapsuleObjectReferenceType;
    struct Result {
        bool ok = false;
        uint index = 0;
        uint offset = 0;
    }
    assert(references.length <= uint.max);
    assert(CapsuleObjectReference.isPcRelativeLowHalfType(lowRefType));
    const hiType = CapsuleObjectReference.getHighHalfType(lowRefType);
    const isNearLow = CapsuleObjectReference.isNearLowHalfType(lowRefType);
    assert(hiType);
    uint nearestRefIndex = cast(uint) references.length;
    uint nearestRefOffset = uint.max;
    for(uint refIndex = 0; refIndex < references.length; refIndex++) {
        auto hi = references[refIndex];
        if(hi.type is hiType && filter(hi) &&
            (!isNearLow || hi.name == lowRefName)
        ) {
            if(hi.offset == hiRefOffset) {
                return Result(true, refIndex, 0);
            }
            else if(isNearLow && hi.offset < hiRefOffset &&
                hiRefOffset - hi.offset <= nearestRefOffset
            ) {
                nearestRefIndex = refIndex;
                nearestRefOffset = hiRefOffset - hi.offset;
            }
        }
    }
    if(nearestRefIndex < references.length) {
        return Result(true, nearestRefIndex, nearestRefOffset);
    }
    else {
        return Result(false, 0, 0);
    }
}
