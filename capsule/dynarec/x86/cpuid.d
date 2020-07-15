module capsule.dynarec.x86.cpuid;

private:

import capsule.dynarec.x86.register : X86Register;

public:

/// High 8 bits: Register ID (ebx, ecx, edx, or eax)
/// Low 8 bits: Flag bit number
/// https://en.wikipedia.org/wiki/CPUID#EAX=7,_ECX=0:_Extended_Features
enum X86ExtendedFeatureFlag: ushort {
    None = 0xffff,
    /// Access to base of %fs and %gs
    fsgsbase = 0x0300,
    /// IA32_TSC_ADJUST
    IA32_TSC_ADJUST = 0x0301,
    /// Software Guard Extensions
    sgx = 0x0302,
    /// Bit Manipulation Instruction Set 1
    bmi1 = 0x0303,
    /// TSX Hardware Lock Elision
    hle = 0x0304,
    /// Advanced Vector Extensions 2
    avx2 = 0x0305,
    /// Supervisor Mode Execution Prevention
    smep = 0x0307,
    /// Bit Manipulation Instruction Set 2
    bmi2 = 0x0308,
    /// Enhanced REP MOVSB/STOSB
    erms = 0x0309,
    /// INVPCID instruction
    invpcid = 0x030a,
    /// TSX Restricted Transactional Memory
    rtm = 0x030b,
    /// Platform Quality of Service Monitoring
    pqm = 0x030c,
    /// FPU CS and FPU DS deprecated
    fpucsds = 0x030d,
    /// Intel MPX (Memory Protection Extensions)
    mpx = 0x030e,
    /// Platform Quality of Service Enforcement
    pqe = 0x030f,
    /// AVX-512 Foundation
    avx512_f = 0x0310,
    /// AVX-512 Doubleword and Quadword Instructions
    avx512_dq = 0x0311,
    /// RDSEED instruction
    rdseed = 0x0312,
    /// Intel ADX (Multi-Precision Add-Carry Instruction Extensions)
    asx = 0x0313,
    /// Supervisor Mode Access Prevention
    smap = 0x0314,
    /// AVX-512 Integer Fused Multiply-Add Instructions
    avx512_ifma = 0x0315,
    /// PCOMMIT instruction
    pcommit = 0x0316,
    /// CLFLUSHOPT instruction
    clflushopt = 0x0317,
    /// CLWB instruction
    clwb = 0x0318,
    /// Intel Processor Trace
    intel_pt = 0x0319,
    /// AVX-512 Prefetch Instructions
    avx512_pf = 0x031a,
    /// AVX-512 Exponential and Reciprocal Instructions
    avx512_er = 0x031b,
    /// AVX-512 Conflict Detection Instructions
    avx512_cd = 0x031c,
    /// Intel SHA extensions
    sha = 0x031d,
    /// AVX-512 Byte and Word Instructions
    avx512_bw = 0x031e,
    /// AVX-512 Vector Length Extensions
    avx512_vl = 0x031f,
    /// PREFETCHWT1 instruction
    prefetchwt1 = 0x0100,
    /// AVX-512 Vector Bit Manipulation Instructions
    avx512_vbmi = 0x0101,
    /// User-mode Instruction Prevention
    umip = 0x01012,
    /// Memory Protection Keys for User-mode pages
    pku = 0x0103,
    /// PKU enabled by OS
    ospke = 0x0104,
    /// waitpkg
    waitpkg = 0x0105,
    /// AVX-512 Vector Bit Manipulation Instructions 2 
    avx512_vbmi2 = 0x0106,
    /// Control flow enforcement (CET) shadow stack 
    cet_ss = 0x0107,
    /// Galois Field instructions
    gfni = 0x0108,
    /// Vector AES instruction set (VEX-256/EVEX)
    vaes = 0x0109,
    /// CLMUL instruction set (VEX-256/EVEX)
    vpclmulqdq = 0x010a,
    /// AVX-512 Vector Neural Network Instructions
    avx512_vnni = 0x010b,
    /// AVX-512 BITALG instructions
    avx512_bitalg = 0x010c,
    /// AVX-512 Vector Population Count Double and Quad-word
    avx512_vpopcntdq = 0x010e,
    /// 5-level paging
    l5paging = 0x0110,
    /// Read Processor ID and IA32_TSC_AUX
    rdpid = 0x0116,
    /// Cache line demote
    cldemote = 0x0119,
    /// MOVDIRI
    MOVDIRI = 0x011b,
    /// MOVDIR64B
    MOVDIR64B = 0x011c,
    /// Enqueue Stores
    ENQCMD = 0x011d,
    /// SGX Launch Configuration
    sgx_lc = 0x011e,
    /// Protection keys for supervisor-mode pages
    pks = 0x011f,
    /// AVX-512 4-register Neural Network Instructions 
    avx512_4vnniw = 0x0202,
    /// AVX-512 4-register Multiply Accumulation Single precision 
    avx512_4fmaps = 0x0203,
    /// Fast Short REP MOVSB 
    fsrm = 0x0204,
    /// AVX-512 VP2INTERSECT Doubleword and Quadword Instructions 
    avx512_vp2intersect = 0x0208,
    /// VERW instruction clears CPU buffers 
    md_clear = 0x020a,
    /// tsx_force_abort
    tsx_force_abort = 0x020d,
    /// Serialize instruction execution 
    SERIALIZE = 0x020e,
    /// Hybrid
    Hybrid = 0x020f,
    /// TSX suspend load address tracking 
    TSXLDTRK = 0x0210,
    /// Platform configuration (Memory Encryption Technologies Instructions) 
    pconfig = 0x0212,
    /// Control flow enforcement (CET) indirect branch tracking 
    cet_ibt = 0x0214,
    /// Tile computation on bfloat16 numbers 
    amx_bf16 = 0x0216,
    /// Tile architecture 
    amx_tile = 0x0218,
    /// Tile computation on 8-bit integers 
    amx_int8 = 0x0219,
    /// Speculation Control, part of Indirect Branch Control (IBC):
    /// Indirect Branch Restricted Speculation (IBRS) and
    /// Indirect Branch Prediction Barrier (IBPB)
    spec_ctrl = 0x021a,
    /// Single Thread Indirect Branch Predictor, part of IBC
    stibp = 0x021b,
    /// Speculative Side Channel Mitigations
    IA32_ARCH_CAPABILITIES = 0x021d,
    /// Support for a MSR listing model-specific core capabilities 
    IA32_CORE_CAPABILITIES = 0x021e,
    /// Speculative Store Bypass Disable, as mitigation for Speculative Store Bypass (IA32_SPEC_CTRL)
    ssbd = 0x021f,
    /// AVX-512 BFLOAT16 instructions 
    avx512_bf16 = 0x0005,
}

X86Register getX86ExtendedFeatureFlagRegister(
    in X86ExtendedFeatureFlag feature
) pure nothrow @safe @nogc {
    return cast(X86Register) (feature >> 8);
}

uint getX86ExtendedFeatureFlagMask(
    in X86ExtendedFeatureFlag feature
) pure nothrow @safe @nogc {
    return 1 << (feature & 0x1f);
}
