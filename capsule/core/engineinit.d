module capsule.core.engineinit;

import capsule.core.engine : CapsuleEngine;
import capsule.core.program : CapsuleProgram;

public:

/// Helper to initialize a CapsuleEngine instance to be used for running
/// a given CapsuleProgram.
auto initializeCapsuleEngine(
    in CapsuleProgram program, CapsuleEngine.ExtensionCallHandler ecall
) {
    alias Engine = CapsuleEngine;
    Engine engine;
    engine.initialize(initializeCapsuleMemory(program), ecall);
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
    memory.romStart = program.readOnlyDataSegment.offset;
    memory.romEnd = program.textSegment.end;
    const dataOk = memory.write(
        program.dataSegment.offset, program.dataSegment.bytes
    );
    const readOnlyDataOk = memory.write(
        program.readOnlyDataSegment.offset, program.readOnlyDataSegment.bytes
    );
    const textOk = memory.write(
        program.textSegment.offset, program.textSegment.bytes
    );
    if(!dataOk || !readOnlyDataOk || !textOk) {
        memory.free();
    }
    return memory;
}
