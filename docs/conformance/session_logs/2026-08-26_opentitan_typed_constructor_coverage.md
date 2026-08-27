# 2026-08-26 — typed constructor-dependent coverage ranges

## Scope and provenance

- Worktree: `iverilog-uvm-commercial-after237-arm64-20260826`
- Branch: `agent/opentitan-commercial-after237-arm64-20260826`
- Base: `origin/main` at
  `eb68431e5937fb6a5fe6baa98ad6f3d399b924ab` (PR #237 merge)
- Host: native Apple Silicon; all compiler, VVP, Python, and corpus tooling is
  ARM64-native; no VM or Rosetta lane was used
- OpenTitan: clean `7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19`
- Caliptra frozen baseline: `bd31614182fb56e55578f48086a10ded650434fd`
- Standards consulted locally from the ignored
  `docs/standards/local/IEEE_Std_1800-{2017,2023}.pdf` references; neither PDF
  is committed

The governing shared rules are IEEE 1800-2017/2023 clauses 19.3, 19.5,
19.5.1, and 19.5.7. This checkpoint implements a bounded integral subset; it
does not claim complete clause 19 or either complete language edition.

The later bounded dynamic-cross follow-up is recorded in
[`2026-08-26_opentitan_dynamic_cross_topology.md`](2026-08-26_opentitan_dynamic_cross_topology.md).
It supersedes this log's forward-looking dynamic-cross status while preserving
the measurements below as the PR #238 historical checkpoint.

## Original unmodified failure

OpenTitan's TL agent declares a constructor-dependent arrayed bin range whose
endpoint contains:

```systemverilog
[0 : 2 << (valid_source_width - 1) - 1]
```

The earlier compiler could parse the declaration but could not preserve and
evaluate the endpoint for each covergroup object. The range was dropped with a
hard semantic diagnostic, blocking the unmodified `tl_agent_sim` compile.
Treating the constructor value as an ordinary constant would also have lost
its width, signedness, four-state state, and construction-time lifetime.

## Root cause

The coverage metadata represented fixed endpoints as raw 64-bit values. It had
no typed construction-time expression IR, no coverpoint type in the VVP
record, and no per-covergroup-object resolution/cache. Set expressions were
likewise unable to preserve their own element type or capture a parent
container when the covergroup was linked to its enclosing object.

The audit exposed two additional correctness/safety requirements:

1. Clause 19.5.7 equality is bit-pattern/type based, not merely a mathematical
   range check. An unsigned `3'b110` converted to a signed three-bit
   coverpoint is the accepted `3'sb110` value (`-2`); the inverse signed
   negative to unsigned conversion remains excluded. Mixed-sign range bounds
   therefore must be resolved independently.
2. A typed set suffix paired with the legacy three-string VVP grammar, or a
   typed VVP value field paired with suffixless legacy set IR, is a malformed
   ABI record. Both mismatches must be rejected at load time rather than
   guessing semantics or reaching a zero-width shift.

## Implementation boundary

- Carry coverpoint width/sign and source endpoint width/sign through the IVL
  target API, emitted `.covgrp_dyn_bin` record, VVP loader, class metadata,
  and runtime.
- Evaluate the bounded typed expression IR once per covergroup object and
  cache the resolved family.
- Resolve every endpoint independently under clause 19.5.7 conversion and
  equality rules, reject X/Z, intersect partially representable ranges with
  the effective coverpoint domain, and treat explicit descending ranges as
  empty.
- The checkpoint preserved duplicate occurrences for both unsized and fixed
  arrays. A subsequent direct-LRM audit found that rule nonconformant for
  integral open arrays: `bins b[]` creates one value-named logical bin per
  distinct resolved value, so duplicate and overlapping ranges coalesce.
  Fixed arrays preserve the ordered matching occurrences, place the remainder
  in the final nonempty bin, and apply ignore/illegal carving after
  distribution without redistribution. The open-bin identity, fixed
  remainder, and carving behavior are therefore recorded defects in this
  checkpoint, not guarantees established by its 8/8 focused result.
- Encode direct/current and parent-container set expressions with their own
  element width/sign. Freeze a parent set immediately when the parent link is
  installed so later container mutation cannot change construction-time bin
  membership.
- Accept old well-formed VVP records with their historical raw-bit behavior;
  reject malformed or mixed-version type metadata safely.
- Diagnose unsupported constructor-dependent `with`, dynamic crosses,
  context-sensitive fill trees, selected endpoints, calls/casts/concatenation,
  over-wide types, and other unrepresentable forms instead of silently
  dropping or inventing a value.

The supported endpoint grammar is deliberately bounded to integral leaves up
to 64 bits plus the tested unary, arithmetic, bitwise, and shift forms. It is
large enough for the exact OpenTitan TL expression and the permanent typed
reducers, but is not advertised as an arbitrary SystemVerilog expression
evaluator.

## Permanent tests

Paired `-g2017` and `-g2023` entries cover:

- exact OpenTitan endpoint construction and distinct per-instance ranges;
- typed shifts, arithmetic wrap, mixed widths/signs, unary minus, direct input
  capture, safe `'0`, and descending ranges;
- the checkpoint's duplicate-membership and fixed-bin examples (which did not
  establish the later-audited open-bin identity, exact remainder, or
  post-distribution carving rules);
- unsigned-bit-pattern to signed-coverpoint conversion, inverse signed-
  negative exclusion, typed set equivalents, and both mixed-sign endpoint
  orders;
- coverpoint-domain intersection, constructor/sample source selection,
  construction-time parent-set capture, and X/Z endpoints;
- loud unresolved/unsupported calls, casts, concatenations, fill literals,
  selected endpoints, dynamic `with`, dynamic cross, over-wide types, and
  constructor set forms; and
- valid typed metadata, well-formed legacy metadata, malformed type strings,
  out-of-range widths/indices, and both typed/legacy set-ABI mismatches.

Focused results after the final audit:

- legacy: **8/8**;
- JSON/VVP: **8/8**;
- raw VVP metadata bounds: **PASS**;
- procedural option/report invariants: **3/3**;
- negative diagnostics: **136/136**;
- build/install and `git diff --check`: **PASS**.

Clean serial broad results on the committed tree:

- `make check`: **PASS** (2.58 seconds);
- legacy ivtest: **4,094 total, 4,089 pass, 0 fail, 2 NI, 3 expected fail**
  (123.10 seconds);
- JSON/VVP: **979 run, 0 fail** (22.69 seconds);
- bundled VPI: **112/112** (28.25 seconds);
- canonical unmodified UVM with the real DPI umbrella: **354/354**, 0 failed,
  0 skipped (596.49 seconds).

The ivtest harnesses share `vsim` and log names. One deliberately discarded
run overlapped legacy and VPI and produced cross-test log contents and missing
images; the results above are clean serial reruns. Do not run those harnesses
concurrently in one worktree.

## OpenTitan application evidence

The full native-ARM64 61-target OpenTitan UVM compile matrix completed with no
timeouts. Against the same 61-row after-236 baseline, status changed from
`58 FAIL + 3 SETUP_FAIL` to:

- `1 DEBT`;
- `57 FAIL`;
- `3 SETUP_FAIL`;
- `0 PASS`.

The sole transition is `lowrisc:dv:tl_agent_sim:0.1`: compile return code 0,
zero hard errors, and 12 pre-existing generic UVM semantic-debt diagnostics.
This proves the exact constructor endpoint crosses the hard-compile boundary;
it is not a clean application or runtime pass.

Remaining first-hard-diagnostic classes are 16 dynamic-family cross metadata,
28 parser/syntax, 8 missing `prim_clock_gating` provider, 3 unresolved
`clocking_decl_assign`, and 2 isolated export/hierarchical-constant frontiers.
The three setup failures are unchanged generated-file graph problems. The
earlier 18 constructor-range count included one SVA-lane target; this UVM-only
matrix has 17 former first frontiers, one resolved and 16 advanced to cross
integration.

Evidence:

- external directory:
  `evidence/opentitan-commercial-after237-arm64-20260826/full-uvm/`
- JSON SHA-256:
  `b52ce5d846544c88f24dba3fbd41b97522247c44567861be85a65d0d2c5b560f`
- FuseSoC 2.4.5 under native ARM Python 3.13.15

This is a compile matrix only. It did not execute the 61 simulations.

## Caliptra preservation evidence

A fresh frozen census ran all 105 clean Caliptra manifests through four serial
lanes (420 native-ARM64 invocations): Icarus with assertions, Icarus without
assertions, Icarus `-S`, and pinned Slang. It completed in 53.81 seconds wall
with zero timeouts and exactly reproduced the after-236 baseline:

- Icarus +SVA: **53/105**;
- Icarus -SVA: **53/105**;
- Icarus synthesis: **53/105**;
- Slang: **54/105**;
- classes: 52 PASS, 1 DEBT, 51 SHARED_SOURCE_OR_CONFIG, 1 SOURCE_ORDER_DEBT,
  0 ICARUS_GAP, and 0 SLANG_ONLY_DIFFERENCE.

A job-by-job comparison found zero changes in classification, exit/timeout
state, error/warning counts, or compact diagnostics. `caliptra_top` and
`caliptra_top_ss_mode` remain pass results in every compile lane. This is a
compile/elaboration/synthesis census, not a full DV runtime.

Evidence is outside the repository at
`evidence/caliptra-commercial-after237-arm64-20260826/`. Provenance includes
clean Caliptra `bd31614182fb56e55578f48086a10ded650434fd`, Adams Bridge
`e59eba955eac2a1adcb059f250641ede78e304be`, compiler driver SHA-256
`2aa8de342a086836f910e83ad1f2ad0d622aca5e6209611df92dee84dca7b433`,
engine SHA-256
`556a5ffb97b58f21abe0bdd1bcf0ff94d439e35db6802040f69bcc7a293fecdc`,
and result JSON SHA-256
`123e1194cd3cf5915cdcdda396f4f2f22bb1e98226fa54f247f809d67c7ab755`.

## Toolchain and invocation gotchas

- OpenTitan's supported graph must be generated through its register/core
  generation and FuseSoC flow; compiling an invented flat file list is not an
  application result.
- The working FuseSoC executable is in the native Python 3.13 environment at
  `evidence/arm64-tooling/opentitan-python313/bin/fusesoc`. Its shebang and
  real interpreter are ARM64; relying on the shell's default Python can report
  a false missing-FuseSoC/setup failure.
- The resource runner is
  `evidence/arm64-tooling/resource-runner`. It applies a 45-second CPU guard
  per compiler/runtime invocation and no RSS cap at this checkpoint. A
  CPU-guard result is not automatically a hang.
- OpenTitan's application matrix uses its generated `-g2012` source flow;
  paired permanent reducers use explicit `-g2017` and `-g2023` to establish
  the shared standards disposition.
- VCS, Questa, and Xcelium remain practical commercial interoperability
  cross-checks after the IEEE text. Slang is a parser/elaboration differential;
  Verilator is not the language, runtime, or Annex-H ABI oracle.

## Explicit follow-up

The follow-up increment now verifies bounded dynamic-family automatic crosses
and the evidenced named `binsof`/`intersect` conjunctions. Its paired legacy
and JSON/VVP focus gates pass 20/20, and the OpenTitan UVM matrix moves seven
targets from FAIL to DEBT while removing the former dynamic-cross-drop
diagnostic from all 20 affected targets. That result closes this log's
immediate frontier, not clause 19.

After final hardening, current local gates are full legacy **4,103 pass / 0 fail
/ 2 NI / 3 expected fail** (**4,108 total**), JSON/VVP **993/993**, negatives
**136/136**, VPI **103/103**, canonical real-DPI UVM **354/354**, and both
focused paths **20/20**. The final OpenTitan matrix is **8 DEBT / 50 FAIL /
3 SETUP_FAIL / 0 PASS** versus the **1 DEBT / 57 FAIL / 3 SETUP_FAIL /
0 PASS** historical result above. It completed in 47.62 seconds with zero
timeouts/resource-limit signals and zero exact or generic former cross-drop
diagnostics. This remains compile-only evidence, not a clean application or
runtime pass. The final matrix evidence is
`/Users/danielellerbrock/projects/iverilog_uvm/evidence/opentitan-dynamic-cross-final-after238-arm64-20260826T183204-0600/matrix`;
its result JSON SHA-256 is
`b97844e5b327b98a251e3c03f15e6939e827c0f849a88cfd538f1334b388fa55`
and the compiler-engine SHA-256 is
`599a85f0c35730e151227abfd6c698cf9bc8556c50f8f6b70ccf0aa728e1cff1`.

The final Caliptra static census completed 105 jobs and 420 compiler
invocations in 52.33 seconds: Icarus is **53/105** in each assertions,
no-assertions, and synthesis lane, versus Slang **54/105**. Classifications are
**52 PASS / 1 DEBT / 51 SHARED_SOURCE_OR_CONFIG / 1 SOURCE_ORDER_DEBT /
0 ICARUS_GAP**; the sole Slang advantage is known `csrng_raw_wrap` source-order
debt. Evidence is
`/Users/danielellerbrock/projects/iverilog_uvm/evidence/caliptra-dynamic-cross-final-after238-arm64-20260827T003032Z`
with result JSON SHA-256
`857e7b5a97ca35810ac21258e0367f63bd53766ee5d3ca2f65639e09e8add9fd`.
This is static compile/elaboration/synthesis differential evidence, not full DV
runtime.

Still open are constructor/per-instance expressions for 2023
`cross_retain_auto_bins`, illegal cross bins over transition terms, remaining
dynamic `with`/`matches`/set/`CrossQueueType` selection forms, source
ignore/illegal carving from dynamic-family denominators, type-coverage union,
report/VPI and normative naming detail, the explicit 65,536-bin topology cap,
real/tolerance coverage, constructor `ref`/output/inout direction semantics,
full context-sized literals, and broader expression evaluation.

Unrelated OpenTitan parser/provider/clocking frontiers remain larger than this
coverage cluster. Full Caliptra DV runtime still requires external verification
inputs and may not be claimed from the completed static census. Formal proof
execution and UPF/IEEE 1801 remain future programs after substantially broader
IEEE 1800 closure.
