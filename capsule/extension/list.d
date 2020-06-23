/**

This module provides data structures related to resolving
ID values given to an ecall instruction, producing a pointer
to a function implementing that extension call.

*/

module capsule.extension.list;

import capsule.core.extension : CapsuleExtension;
import capsule.core.engine : CapsuleEngine, CapsuleExtensionCallResult;
import capsule.io.stdio : stdio;
import capsule.core.types : CapsuleExceptionCode;

private alias Entry = CapsuleExtensionListEntry;

public:

/// Extension call implementation functions must have this
/// signature.
alias CapsuleExtensionFunction = CapsuleExtensionCallResult function(
    void* data, CapsuleEngine* engine, in uint arg
);

/// Associates a Capsule extension ID with a function pointer
/// and a data pointer.
struct CapsuleExtensionListEntry {
    alias Extension = CapsuleExtension;
    alias Function = CapsuleExtensionFunction;
    
    /// 32-bit numeric identifier indicating specifically which
    /// extension this entry's function is implementing.
    Extension id = cast(Extension) uint.max;
    /// Pointer to a function implementing this extension call.
    Function func = null;
    /// This pointer will always be passed as an argument to the
    /// extension call function.
    void* data = null;
    
    bool opCast(T: bool)() const {
        return this.func !is null;
    }
}

/// Data structure for storing and accessing extension call function
/// implementations by ID.
struct CapsuleExtensionList {
    alias Engine = CapsuleEngine;
    alias Entry = CapsuleExtensionListEntry;
    alias ExceptionCode = CapsuleExceptionCode;
    alias Extension = CapsuleExtension;
    alias Function = CapsuleExtensionFunction;
    alias CallResult = CapsuleExtensionCallResult;
    
    /// List of all extension call implementation entries contained
    /// in this list. The entries are ordered from lowest to highest
    /// extension ID value.
    Entry[] entries;
    
    /// Returns true when there are no extensions in the list
    bool empty() const {
        return this.entries.length == 0;
    }
    
    /// Returns the total number of extensions in the list.
    size_t length() const {
        return this.entries.length;
    }
    
    /// Get an extension call entry associated with a given extension ID.
    Entry getExtension(in uint id) {
        uint low = 0;
        uint high = cast(uint) this.entries.length;
        while(true) {
            const uint mid = low + ((high - low) / 2);
            if(mid < this.entries.length && this.entries[mid].id == id) {
                return this.entries[mid];
            }
            else if(low >= mid) {
                return Entry.init;
            }
            else if(this.entries[mid].id > id) {
                high = mid;
            }
            else {
                assert(this.entries[mid].id < id);
                low = mid + 1;
            }
        }
    }
    
    /// Add a single extension implementation entry to the list.
    void addExtension(in Extension id, Function func, void* data = null) {
        this.addExtension(Entry(id, func, data));
    }
    
    /// Add a single extension implementation entry to the list.
    void addExtension(Entry entry) {
        const id = entry.id;
        uint low = 0;
        uint high = cast(uint) this.entries.length;
        while(true) {
            const uint mid = low + ((high - low) / 2);
            if(mid < this.entries.length && this.entries[mid].id == id) {
                this.entries[mid] = entry;
            }
            else if(low >= mid) {
                assert(this.entries[mid].id < id);
                assert(mid >= this.entries.length || this.entries[mid].id > id);
                this.entries = (
                    this.entries[0 .. mid] ~ entry ~
                    this.entries[mid .. $]
                );
            }
            else if(this.entries[mid].id > id) {
                high = mid;
            }
            else {
                assert(this.entries[mid].id < id);
                low = mid + 1;
            }
        }
    }
    
    /// Add extension implementation entries from a list.
    /// The input list must be sorted from lowest to highest
    /// extension ID value.
    void addExtensionList(Entry[] addEntries) {
        import capsule.io.stdio;
        import capsule.string.writeint;
        Entry[] mergedEntries;
        mergedEntries.reserve(this.entries.length + addEntries.length);
        size_t i = 0;
        size_t j = 0;
        while(i < this.entries.length && j < addEntries.length) {
            assert(i == 0 || this.entries[i - 1].id < this.entries[i].id);
            assert(j == 0 || addEntries[j - 1].id < addEntries[j].id);
            if(this.entries[i].id < addEntries[j].id) {
                mergedEntries ~= this.entries[i++];
            }
            else if(this.entries[i].id > addEntries[j].id) {
                mergedEntries ~= addEntries[j++];
            }
            else {
                mergedEntries ~= addEntries[j++];
                i++;
            }
        }
        mergedEntries ~= addEntries[j .. $];
        this.entries = mergedEntries;
    }
    
    /// Find and invoke the extension function with the given
    /// Capsule engine instance and the given extension ID.
    CallResult callExtension(Engine* engine, in uint id, in uint arg) {
        assert(engine);
        auto extension = this.getExtension(id);
        if(!extension) {
            return CallResult.Missing;
        }
        else {
            return extension.func(extension.data, engine, arg);
        }
    }
}
