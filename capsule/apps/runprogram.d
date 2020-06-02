module capsule.apps.runprogram;

import capsule.core.ascii : isDigit, toLower;
import capsule.core.engine : CapsuleEngine, CapsuleExtensionCallResult;
import capsule.core.enums : getEnumMemberAttribute;
import capsule.core.hex : parseHexString, getHexString, getByteHexString;
import capsule.core.memory : CapsuleMemoryStatus;
import capsule.core.obj : CapsuleObjectReferenceLocalType;
import capsule.core.parseint : parseInt, parseUnsignedInt;
import capsule.core.program : CapsuleProgram;
import capsule.core.stdio : stdio;
import capsule.core.strings : startsWith;
import capsule.core.types : CapsuleOpcode, CapsuleExceptionCode;
import capsule.core.types : CapsuleInstruction;
import capsule.core.typestrings : getCapsuleOpcodeWithName;
import capsule.core.typestrings : CapsuleRegisterNames;
import capsule.core.writeint : writeInt;

public:

void logInstruction(in CapsuleEngine engine) {
    logInstruction(engine.pc, engine.instr);
}

void logInstruction(in int address, in CapsuleInstruction instr) {
    const opName = getEnumMemberAttribute!string(instr.opcode);
    stdio.write("@", getHexString(address), ": ");
    if(opName) {
        stdio.write(opName);
    }
    else {
        stdio.write("op[", getByteHexString(cast(ubyte) instr.opcode), "]");
    }
    stdio.writeln(
        " rd: ", CapsuleRegisterNames[instr.rd & 0x7],
        " rs1: ", CapsuleRegisterNames[instr.rs1 & 0x7],
        " rs2: ", CapsuleRegisterNames[instr.rs2 & 0x7],
        " imm: ", getHexString(instr.imm),
    );
}

void logValue(in char[] name, in int value, in string end = "\n") {
    stdio.write(name, " = ", getHexString(value));
    stdio.write(" (int: ", writeInt(cast(int) value));
    if(value < 0) stdio.write(", uint: ", writeInt(cast(uint) value), ")", end);
    else stdio.write(")", end);
}

void logRegistersLong(in int[8] registers) {
    for(uint i = 0; i < 8; i++) {
        logValue(CapsuleRegisterNames[i], registers[i]);
    }
}

void logRegistersShort(in int[8] registers) {
    for(uint i = 0; i < 8; i++) {
        const sep = (i == 7 ? "\n" : ", ");
        stdio.write(CapsuleRegisterNames[i], " = ", writeInt(registers[i]), sep);
    }
}

void logProgramSymbol(
    in CapsuleProgram program, in char[] name, in CapsuleProgram.Symbol symbol
) {
    const segment = program.getContainingSegment(symbol.value);
    if(symbol.isAddress) stdio.write(getEnumMemberAttribute!string(segment.type), " ");
    stdio.write(getEnumMemberAttribute!string(symbol.type), " ");
    logValue(name, symbol.value, symbol.length == 0 ? "\n" : "");
    if(symbol.length) stdio.writeln(" (length: ", writeInt(symbol.length), ")");
}

void logMemoryLoadResult(T, alias stringify = writeInt)(
    in CapsuleEngine.Memory.Load!T load, in uint address
) {
    final switch(load.status) {
        case CapsuleEngine.Memory.Status.Ok:
            stdio.writeln("@", getHexString(address), ": ", stringify(load.value));
            break;
        case CapsuleEngine.Memory.Status.ReadOnly:
            assert(false);
        case CapsuleEngine.Memory.Status.Misaligned:
            assert(false);
        case CapsuleEngine.Memory.Status.OutOfBounds:
            stdio.writeln("@", getHexString(address), ": address out of bounds");
            break;
    }
}

auto parseNumberInput(
    in CapsuleProgram program, in CapsuleEngine engine, in char[] input
) {
    struct Result {
        bool ok;
        uint value;
        static enum Error = typeof(this)(false);
        static typeof(this) Ok(T)(in T value) {
            return typeof(this)(true, cast(uint) value);
        }
        bool opCast(T: bool)() const {
            return this.ok;
        }
    }
    if(input == "pc" || input == "PC") {
        return Result.Ok(engine.pc);
    }
    else if(input == "entry") {
        return Result.Ok(program.entryOffset);
    }
    else if(const regIndex = getRegisterInput(input)) {
        assert(regIndex < engine.reg.length);
        return Result.Ok(engine.reg[regIndex]);
    }
    else if(input.length && (isDigit(input[0]) || input[0] == '+' || input[0] == '-')) {
        const parse = parseInt!uint(input);
        return Result(parse.ok, parse.value);
    }
    else {
        return Result.Error;
    }
}

string getMemoryLoadStatusString(in CapsuleMemoryStatus status) {
    alias Status = CapsuleMemoryStatus;
    final switch(status) {
        case Status.Ok: return null;
        case Status.ReadOnly: return "tried to write to read-only memory";
        case Status.Misaligned: return "misaligned address";
        case Status.OutOfBounds: return "address out of bounds";
    }
}

uint getRegisterInput(in char[] input) {
    if(input == "a" || input == "A" || input == "r1") return 1;
    else if(input == "b" || input == "B" || input == "r2") return 2;
    else if(input == "c" || input == "C" || input == "r3") return 3;
    else if(input == "r" || input == "R" || input == "r4") return 4;
    else if(input == "s" || input == "S" || input == "r5") return 5;
    else if(input == "x" || input == "X" || input == "r6") return 6;
    else if(input == "x" || input == "X" || input == "r7") return 7;
    else return 0;
}

auto getRegisterInputStart(in char[] input) {
    struct Result {
        uint index;
        uint length;
    }
    if(input.startsWith("a") || input.startsWith("A")) return Result(1, 1);
    else if(input.startsWith("r1")) return Result(1, 2);
    else if(input.startsWith("b") || input.startsWith("B")) return Result(2, 1);
    else if(input.startsWith("r2")) return Result(1, 2);
    else if(input.startsWith("c") || input.startsWith("C")) return Result(3, 1);
    else if(input.startsWith("r3")) return Result(1, 2);
    else if(input.startsWith("r") || input.startsWith("R")) return Result(4, 1);
    else if(input.startsWith("r4")) return Result(1, 2);
    else if(input.startsWith("s") || input.startsWith("S")) return Result(5, 1);
    else if(input.startsWith("r5")) return Result(1, 2);
    else if(input.startsWith("x") || input.startsWith("X")) return Result(6, 1);
    else if(input.startsWith("r6")) return Result(1, 2);
    else if(input.startsWith("x") || input.startsWith("X")) return Result(7, 1);
    else if(input.startsWith("r7")) return Result(1, 2);
    else return Result(0, 0);
}

uint forEachSymbol(alias func)(in int pc, in CapsuleProgram program, in char[] name) {
    if(!name.length) {
        return 0;
    }
    else if(isDigit(name[0]) && (name[$ - 1] == 'f' || name[$ - 1] == 'b')) {
        const localType = cast(CapsuleObjectReferenceLocalType) name[$ - 1];
        const i = getLocalSymbolIndex(pc, program, name[0 .. $ - 1], localType);
        if(i >= 0) func(program.symbols[cast(size_t) i]);
        return 1;
    }
    uint nameIndex = uint.max;
    for(uint i = 0; i < program.names.length; i++) {
        if(program.names[i] == name) {
            nameIndex = i;
            break;
        }
    }
    uint foundSymbols = 0;
    foreach(symbol; program.symbols) {
        if(symbol.name == nameIndex) {
            func(symbol);
            foundSymbols++;
        }
    }
    return foundSymbols;
}

ptrdiff_t getLocalSymbolIndex(
    in int pc, in CapsuleProgram program, in char[] name,
    in CapsuleObjectReferenceLocalType localType
) {
    alias LocalType = CapsuleObjectReferenceLocalType;
    size_t nearestIndex = 0;
    uint nearestOffset = uint.max;
    for(size_t i = 0; i < program.symbols.length; i++) {
        const symbol = program.symbols[i];
        if(symbol.isAddress) {
            uint offset = 0;
            if(localType is LocalType.Forward) {
                if(symbol.value <= pc) continue;
                offset = symbol.value - pc;
            }
            else {
                assert(localType is LocalType.Backward);
                if(symbol.value > pc) continue;
                offset = pc - symbol.value;
            }
            if(offset < nearestOffset) {
                nearestOffset = offset;
                nearestIndex = i;
            }
        }
    }
    if(nearestOffset < uint.max) {
        return cast(ptrdiff_t) nearestIndex;
    }
    else {
        return -1;
    }
}

void runProgram(ref CapsuleEngine engine) {
    assert(engine.ok);
    while(engine.status is CapsuleEngine.Status.Running) {
        engine.step();
    }
}

void runProgramUntil(alias until)(ref CapsuleEngine engine) {
    assert(engine.ok);
    int[8] reg;
    while(!until(engine) && engine.status is CapsuleEngine.Status.Running) {
        reg = engine.reg;
        engine.step();
    }
    logRegistersShort(reg);
    logInstruction(engine);
}

void debugProgram(in CapsuleProgram program, ref CapsuleEngine engine) {
    alias Status = CapsuleEngine.Status;
    assert(program.ok);
    assert(engine.ok);
    char[1024] buffer;
    stdio.writeln("Running Capsule program in debug mode.");
    stdio.writeln("Type \"help\" for more information.");
    while(engine.status is Status.Running) {
        stdio.write("db > ");
        const length = stdio.readln(buffer);
        if(!length) {
            stdio.writeln("Error reading from stdin.");
            break;
        }
        else if(buffer[length - 1] != '\n') {
            stdio.writeln("Input was too long.");
            continue;
        }
        const input = buffer[0 .. length - 1];
        if(!input.length) {
            engine.next();
            logRegistersShort(engine.reg);
            logInstruction(engine);
            engine.exec();
        }
        else if(input[0] == '.') {
            const n = input.length;
            int[8] reg;
            for(uint i = 0; i < n && engine.status is Status.Running; i++) {
                reg = engine.reg;
                engine.step();
            }
            logRegistersShort(reg);
            logInstruction(engine);
        }
        // Display help text
        // TODO: Write some help text...
        else if(input == "help") {
            stdio.writeln("Sorry, no help text yet...");
        }
        // Quit
        else if(input == "q") {
            engine.status = Status.Terminated;
            break;
        }
        // Display the value of all registers, each on its own line
        else if(input == "reg") {
            logRegistersLong(engine.reg);
        }
        // Set the value of a register, e.g. "rset X 1234"
        else if(input.startsWith("rset ")) {
            const reg = getRegisterInputStart(input[5 .. $]);
            const assignment = parseNumberInput(program, engine, input[6 + reg.length .. $]);
            if(reg.index && assignment.ok) engine.reg[reg.index] = assignment.value;
            else stdio.writeln("Invalid register value assignment.");
        }
        // Resume execution
        // TODO: Until an exception or something, presumably..?
        else if(input == "resume") {
            runProgram(engine);
        }
        // Resume execution until reaching a given address with the PC
        else if(input.startsWith("until pc ")) {
            const target = input[9 .. $];
            const value = parseNumberInput(program, engine, target);
            if(value.ok) runProgramUntil!(e => e.pc == value.value)(engine);
            else stdio.writeln("Failed to parse target program counter value.");
        }
        // Resume execution until reaching a given symbol
        else if(input.startsWith("until sym ")) {
            const name = input[10 .. $];
            CapsuleProgram.Symbol matchSymbol;
            forEachSymbol!((symbol) {
                if(symbol.isAddress) matchSymbol = symbol;
            })(engine.pc, program, name);
            if(matchSymbol) {
                stdio.write("Running until: ");
                logProgramSymbol(program, name, matchSymbol);
                runProgramUntil!(e => e.pc == matchSymbol.value)(engine);
            }
            else {
                stdio.writeln("Failed to parse target program counter value.");
            }
        }
        // Resume execution until after the next instance of a given opcode
        else if(input.startsWith("until op ")) {
            const target = input[9 .. $];
            const op = cast(uint) getCapsuleOpcodeWithName(target);
            const number = parseNumberInput(program, engine, target);
            uint targetOpcode;
            if(op !is CapsuleOpcode.None) targetOpcode = cast(uint) op;
            else if(number.ok) targetOpcode = number.value;
            else {
                stdio.writeln("Failed to parse instruction opcode.");
                continue;
            }
            runProgramUntil!(e => e.instr.opcode == targetOpcode)(engine);
        }
        // Display information about program memory length
        else if(input == "memlen") {
            stdio.writeln("Memory length: ", writeInt(engine.mem.length));
            stdio.writeln("Read-only start: ",
                getHexString(engine.mem.romStart), " (", writeInt(engine.mem.romStart), ")"
            );
            stdio.writeln("Read-only end: ",
                getHexString(engine.mem.romEnd), " (", writeInt(engine.mem.romEnd), ")"
            );
        }
        // Show information about any symbols matching a given name
        else if(input.startsWith("sym ")) {
            const name = input[4 .. $];
            const foundSymbols = forEachSymbol!((symbol) {
                logProgramSymbol(program, name, symbol);
            })(engine.pc, program, name);
            stdio.writeln("Found ", writeInt(foundSymbols), " matching symbols.");
        }
        // Load instruction
        else if(input.startsWith("lin ")) {
            const target = input[4 .. $];
            const parsed = parseNumberInput(program, engine, target);
            if(!parsed.ok) {
                stdio.writeln("Failed to parse memory location.");
                continue;
            }
            const load = engine.mem.lw(parsed.value);
            if(load.ok) {
                logInstruction(parsed.value, CapsuleInstruction.decode(cast(uint) load.value));
            }
            else {
                stdio.write("@", getHexString(parsed.value), ": ");
                stdio.writeln(getMemoryLoadStatusString(load.status));
            }
        }
        // Load sign-extended byte
        else if(input.startsWith("lb ")) {
            const target = input[3 .. $];
            const parsed = parseNumberInput(program, engine, target);
            if(!parsed.ok) {
                stdio.writeln("Failed to parse memory location.");
                continue;
            }
            const load = engine.mem.lb(parsed.value);
            stdio.write("@", getHexString(parsed.value), " ");
            if(load.ok) logValue("byte", load.value);
        }
        // Load zero-extended byte
        else if(input.startsWith("lbu ")) {
            const target = input[4 .. $];
            const parsed = parseNumberInput(program, engine, target);
            if(!parsed.ok) {
                stdio.writeln("Failed to parse memory location.");
                continue;
            }
            const load = engine.mem.lbu(parsed.value);
            stdio.write("@", getHexString(parsed.value), " ");
            if(load.ok) logValue("byte", load.value);
        }
        // Load sign-extended half word
        else if(input.startsWith("lh ")) {
            const target = input[3 .. $];
            const parsed = parseNumberInput(program, engine, target);
            if(!parsed.ok) {
                stdio.writeln("Failed to parse memory location.");
                continue;
            }
            const load = engine.mem.lh(parsed.value);
            stdio.write("@", getHexString(parsed.value), " ");
            if(load.ok) logValue("half", load.value);
        }
        // Load zero-extended half word
        else if(input.startsWith("lhu ")) {
            const target = input[4 .. $];
            const parsed = parseNumberInput(program, engine, target);
            if(!parsed.ok) {
                stdio.writeln("Failed to parse memory location.");
                continue;
            }
            const load = engine.mem.lhu(parsed.value);
            stdio.write("@", getHexString(parsed.value), " ");
            if(load.ok) logValue("half", load.value);
        }
        // Load word
        else if(input.startsWith("lw ")) {
            const target = input[3 .. $];
            const parsed = parseNumberInput(program, engine, target);
            if(!parsed.ok) {
                stdio.writeln("Failed to parse memory location.");
                continue;
            }
            const load = engine.mem.lw(parsed.value);
            stdio.write("@", getHexString(parsed.value), " ");
            if(load.ok) logValue("word", load.value);
        }
        // Display a value
        else if(const parsedNumber = parseNumberInput(program, engine, input)) {
            logValue(input, parsedNumber.value);
        }
        else {
            stdio.writeln("Unrecognized input.");
            continue;
        }
    }
}