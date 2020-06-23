/**

This module provides utility functions for initializing a Capsule
engine instance (which is used to execute bytecode) given a Capsule
program. This is used as part of the process of loading a program
when running the Capsule virtual machine (capsule).

*/

module capsule.core.engineinit;

private:

import capsule.core.engine : CapsuleEngine;
import capsule.core.program : CapsuleProgram;

public:

/// Helper to initialize a CapsuleEngine instance to be used for running
/// a given CapsuleProgram.
auto initializeCapsuleEngine(
    in CapsuleProgram program,
    CapsuleEngine.ExtensionCallHandler ecall,
    void* ecallData = null,
) {
    alias Engine = CapsuleEngine;
    Engine engine;
    engine.initialize(initializeCapsuleMemory(program), ecall, ecallData);
    return engine;
}

/// Helper to initialize a CapsuleEngine.Memory instance given a
/// CapsuleProgram instance.
auto initializeCapsuleMemory(in CapsuleProgram program) {
    alias Engine = CapsuleEngine;
    Engine.Memory memory;
    if(!program.ok) {
        return memory;
    }
    memory.allocate(program.length);
    memory.romStart = program.textSegment.offset;
    memory.romEnd = program.readOnlyDataSegment.end;
    memory.execStart = program.textSegment.offset;
    memory.execEnd = program.textSegment.end;
    const textOk = memory.write(
        program.textSegment.offset, program.textSegment.bytes
    );
    const readOnlyDataOk = memory.write(
        program.readOnlyDataSegment.offset, program.readOnlyDataSegment.bytes
    );
    const dataOk = memory.write(
        program.dataSegment.offset, program.dataSegment.bytes
    );
    if(!textOk || !readOnlyDataOk || !dataOk) {
        memory.free();
    }
    return memory;
}
