# Exact enum method values

The OpenTitan xbar diagnostic aborted during UVM_HIGH configuration printing:
a one-bit module enum `.name()` compared VPI integer/scalar formats and asserted
in `vpi/v2009_enum.c`. The reduced bit and logic cases fail in both 2017 and
2023 modes. Class-property controls pass, so the failure depends on the receiver
representation rather than the SystemVerilog enum value.

## IEEE contract and implementation

IEEE 1800-2017 and IEEE 1800-2023 6.19.5.3, 6.19.5.4, and 6.19.5.6 specify
next, previous, and name results. Membership compares the exact enum value,
including named X/Z values. Invalid receivers return the base type's initial
value for next/prev (Table 6-7) and the empty string for name. A zero count or
whole-cycle count does not waive the invalid-member rule.

Both editions 38.15 permit different closest representations for vpiObjTypeVal
and define full-width aval/bval vectors and their borrowed-buffer lifetime.
The five enum reads now request vpiVectorVal: both receivers, both membership
searches, and the selected next/prev return. This also prevents the previous
32-bit truncation of two-state enumerators above bit31. The shared comparator
uses both vector planes, and the existing receiver copies remain intact before
the next value read. The early zero-count return is removed so every receiver
passes membership lookup. No scalar-normalization layer is added.

The local vector providers zero unused word bits. Source review also confirmed
that compiler-generated enum receivers use binary constants/parameters, vector
stack values, signals, or supported property handles; they do not use the
unrelated decimal metadata constant handle. No change to that handle is needed.

## Regression evidence

Two paired families add four entries to each main harness and focused manifest:
`sv_enum_method_values` and `sv_enum_method_unmatched`. They cover bit/logic
scalars, signed values, named X/Z, widths1/2/31/32/33/64, four-state width65,
packed/class receivers, distinct upper bits in wide returns, invalid defaults,
single-member and three-member wrap, zero/full-cycle counts, and large unsigned
counts. Existing signed and enum-receiver controls remain unchanged.

Both focused harnesses fail all four new entries against the preceding installed
runtime. After the fix, new legacy4/4, existing legacy6/6, and JSON4/4 pass.
Both edition modes pass the independent Slang syntax/elaboration comparison;
the IEEE text supplies the expected behavior. Native plan and code reviews
checked arithmetic, iterator ownership, temporary vector storage, and all callers.

Native ARM64 affected-object build, serial make with Homebrew Bison3.8.2, and
make install passed under the 300s per-process CPU guard. The build began only
after both preceding solver censuses and their diff had completed. Full gate1:
legacy4631/4636 (0 failed,2 NI,3 EF), clean name diff; JSON1525/0; VPI103/103;
negative149/0; runtime invariants including state foreach15/15; real-DPI UVM
355 passed/0 failed/0 skipped. Changed-source and installed-binary fingerprints,
including the actual v2009.vpi module, match after validation.

Evidence is retained under
`evidence/xbar-zero-traffic-after255-arm64-20260904/`: enum-method-red-results.json,
enum-method-wide-return-red-results.json, enum-methods-focus-red-results.json,
enum-methods-focus-green1-results.json, enum-methods-final-gate1-result.json,
enum-methods-build1-fingerprints.json, enum-method-review-plan1.md, and
enum-methods-code-review1.md. New basenames occur exactly once in each intended
manifest, recorded in enum-methods-registration-audit.json.

## Application frontier and remaining limits

A ten-second UVM_HIGH diagnostic with the unchanged freshly compiled xbar
bytecode now prints the configuration and reaches traffic without the enum
assertion. It uses the census working directory and IVL_SVA_NFA=1, with only
unbuffered output, higher verbosity, and solver tracing added. At1681844ps,
the scoreboard compares an older queued request at address0x2309 against a
request at0xdc and reports a mismatch; a0xdc comparison then passes at the same
simulation time. The diagnostic was deliberately wall-limited and is not a
completed application test. See enum-methods-xbar-high1/result.json and runtime.log.

The preceding components-build3 census remains separate evidence: OpenTitan
203 PASS with eight xbar runtime timeouts; Caliptra static52 PASS/ICARUS_GAP0.
Application censuses have not yet been repeated for this enum runtime.

A separately probed two-state enum wider than64 bits still asserts in the
existing target emitter before runtime. That adjacent compiler limitation is
not repaired or hidden here; the width65 passing regression uses a four-state
base. This increment does not claim complete enum or full-DV conformance.
