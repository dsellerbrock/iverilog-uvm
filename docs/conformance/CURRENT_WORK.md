# CURRENT WORK — continuation state

## Active increment — 2026-08-26 — bounded dynamic-cross topology and final hardening

Worktree:
`iverilog-uvm-opentitan-dynamic-cross-after238-arm64-20260826`

Branch: `agent/opentitan-dynamic-cross-after238-arm64-20260826`, created
exactly from `origin/main` at
`1e4df2813c1200b8cadfe6a9a3e28cb3451dadab` (PR #238 merge). OpenTitan and
Caliptra sources remain unchanged.

The direct IEEE 1800-2017/2023 clause-19 audit is implemented for a bounded
cross subset. Integral open arrays coalesce duplicate and overlapping ranges
into one logical bin per distinct resolved value. Fixed arrays partition
ordered matching occurrences, put the remainder in the final nonempty bin,
and apply ignore/illegal carving after distribution without redistribution.
Per-covergroup-object cross plans freeze fixed, transition, and constructor-
dependent logical-bin dimensions after constructor capture. Sampling forms the
Cartesian product of every matched source identity. Overlapping named normal
bins count independently but at most once each per sample; routing precedence
is `illegal` over `ignore` over normal independent of declaration order; and an
illegal cross match leaves its source coverpoints and unrelated crosses intact.

The implemented selection IR covers automatic products,
`binsof`/named-`binsof`, `intersect`, and Boolean `&&`/`||`/`!`; the focused
support claim directly exercises conjunctions and cross `iff`. IEEE 1800-2017
keeps uncovered automatic bins. IEEE 1800-2023
`option.cross_retain_auto_bins` defaults to 1. A covergroup-level assignment is
the default for its crosses, and a cross-local assignment overrides it;
coverpoint and every `type_option` placement are errors. The implemented subset
supports constant values and rejects the declaration in 2017 mode. With a
constant zero, the runtime suppresses automatic bins when any explicit normal,
ignore, or illegal record exists—even if its selector is empty—while a cross
with no explicit record remains automatic. The focused retention reducer
directly pins the normal-bin and no-explicit-bin cases, inherited covergroup
defaults on fixed and dynamic crosses, cross-local disable and enable
overrides, and empty ignore/illegal declaration presence. The LRM evaluates
option expressions at covergroup construction, but that constructor/per-
instance expression path is not yet implemented. The option is definition-
only; dedicated procedural-write and repeated-assignment negatives remain to
be pinned.

Current native-ARM64 local compiler/runtime validation is clean:

- paired clause-19 focus: legacy **20/20**, JSON/VVP **20/20**;
- full legacy ivtest: **4,103 pass, 0 fail, 2 NI, 3 expected fail**
  (**4,108 total**);
- full JSON/VVP: **993/993**, after building and installing the
  optional native-ARM64 `tgt-fpga` target required by two `-tfpga` entries;
- negative diagnostics: **136/136**;
- bundled VPI: **103/103**; and
- canonical unmodified real-DPI UVM: **354/354**.

The final full native-ARM64 OpenTitan UVM compile matrix at clean
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19` completed 61 targets in 47.62
seconds with **8 DEBT / 50 FAIL / 3 SETUP_FAIL / 0 PASS**, zero timeouts, and
zero resource-limit signals, versus the previous **1 DEBT / 57 FAIL /
3 SETUP_FAIL / 0 PASS**. The DEBT targets are `adc_ctrl`, `dma`, `hmac`, `mbx`,
`pattgen`, `soc_dbg_ctrl`, `tl_agent`, and `uart`; seven moved FAIL→DEBT and
`tl_agent` retained its earlier DEBT classification. Both the exact former
constructor-dependent-cross-drop diagnostic and the generic cross-drop
diagnostic occur zero times. The remaining failures are independent parser,
provider, clocking, dynamic-`with`, and isolated elaboration frontiers. This is
a compile matrix: it did not run simulations and contains no clean application
or runtime pass.

Evidence is outside the repository under
`/Users/danielellerbrock/projects/iverilog_uvm/evidence/opentitan-dynamic-cross-final-after238-arm64-20260826T183204-0600/matrix`;
the result JSON SHA-256 is
`b97844e5b327b98a251e3c03f15e6939e827c0f849a88cfd538f1334b388fa55`
and the engine SHA-256 is
`599a85f0c35730e151227abfd6c698cf9bc8556c50f8f6b70ccf0aa728e1cff1`.
Design, test, timing, and native-tool invocation detail is in
[`session_logs/2026-08-26_opentitan_dynamic_cross_topology.md`](session_logs/2026-08-26_opentitan_dynamic_cross_topology.md).
The full canonical real-DPI UVM regression is now **354/354** on the current
tree. The final Caliptra static census completed 105 jobs and 420 compiler
invocations in 52.33 seconds: Icarus is **53/105** in each assertions,
no-assertions, and synthesis lane versus Slang **54/105**. Classifications are
**52 PASS / 1 DEBT / 51 SHARED_SOURCE_OR_CONFIG / 1 SOURCE_ORDER_DEBT /
0 ICARUS_GAP**; the sole Slang advantage is the known `csrng_raw_wrap`
source-order debt. Evidence is
`/Users/danielellerbrock/projects/iverilog_uvm/evidence/caliptra-dynamic-cross-final-after238-arm64-20260827T003032Z`
with result JSON SHA-256
`857e7b5a97ca35810ac21258e0367f63bd53766ee5d3ca2f65639e09e8add9fd`.
This is static compile/elaboration/synthesis differential evidence, not full
Caliptra DV runtime.

Clause 19 remains **PARTIAL**. Constructor/per-instance expressions for the
2023 retention option, illegal cross bins over transition terms, remaining
dynamic `with`/`matches`/set/`CrossQueueType` selection forms, source
ignore/illegal carving from dynamic-family denominators, type-coverage union,
report/VPI and normative naming detail, real/tolerance coverage, and products
beyond the explicit 65,536-bin topology cap remain open.

The project direction is unchanged: selected IEEE 1800-2017 and IEEE
1800-2023 semantics come first; unchanged UVM, OpenTitan, and Caliptra are
application gates; VCS, Questa, and Xcelium are the commercial RTL/DV
interoperability targets after the IEEE text; Slang is a parser/elaboration
differential; and Verilator is diagnostic only. The frontend, scheduler, SVA,
and IR are being made compatible with an eventual formal engine, but formal is
not a current capability claim. UPF/IEEE 1801 remains deferred until the IEEE
1800 language and verification surfaces are substantially closed.

## Resume state — 2026-08-26 — typed constructor coverage and commercial direction

Worktree:
`iverilog-uvm-commercial-after237-arm64-20260826`

Branch: `agent/opentitan-commercial-after237-arm64-20260826`, created exactly
from `origin/main` at `eb68431e5937fb6a5fe6baa98ad6f3d399b924ab` before this
increment. The source-of-truth repository and clean OpenTitan/Caliptra trees
remain unmodified outside the Icarus worktree.

This increment implements a typed, per-covergroup-object construction-time IR
for the bounded integral constructor-dependent bin-range subset required by
OpenTitan's TL agent. It carries the coverpoint, source value, and endpoint
width/sign metadata through the target ABI and VVP image, evaluates each
object's range once, applies clause-19.5.7 conversion and X/Z rejection,
intersects ranges with the coverpoint domain, treats descending ranges as
empty, and preserves the duplicate-membership behavior exercised by the
focused tests. Malformed typed and legacy VVP metadata is bounded and rejected
safely. Unsupported endpoint trees, constructor-dependent `with`, and dynamic
crosses diagnose and drop the affected construct rather than silently
substituting a value. A later direct-LRM audit found that this checkpoint did
not establish—and the then-current static-bin path did not correctly
implement—the distinct-value identity of open bins, fixed-array remainder
placement, or post-distribution ignore/illegal carving. Those defects are
recorded in the active increment above rather than hidden by the 8/8 result.

The paired `-g2017`/`-g2023` focused gates pass 8/8 in the legacy harness and
8/8 in JSON/VVP. They cover the exact OpenTitan expression
`[0 : 2 << (valid_source_width - 1) - 1]`, typed wrap/shift/count behavior,
mixed widths/signs, input capture, descending ranges, duplicate fixed-bin
membership, safe `'0`, unary minus, coverpoint-domain intersection,
construction-time parent-set capture, unknown endpoints, and loud unsupported
boundaries. Raw VVP metadata tests also pin malformed type descriptors and
old-image compatibility. These are subset gates, not full clause-19 closure.

Clean serial native-ARM64 broad validation on the committed tree reports:

- `make check`: pass;
- legacy ivtest: 4,094 total, 4,089 pass, 0 fail, 2 recorded NI, and 3
  expected fail;
- JSON/VVP: 979 run, 0 fail;
- bundled VPI: 112/112;
- negative diagnostics: 136/136;
- focused metadata/options checks: pass; and
- complete canonical real-DPI UVM: 354/354, 0 failed, 0 skipped (596.49
  seconds wall).

An earlier overlapping legacy/VPI invocation was discarded because both
harnesses share `ivtest/vsim` and log names; impossible cross-test log contents
proved workspace contamination. The clean results above are serial reruns.

A native-ARM64, clean-source OpenTitan UVM compile matrix exercised all 61 UVM
targets at OpenTitan `7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19` with FuseSoC
2.4.5 under ARM Python 3.13.15. It completed with no timeouts and changed the
same-scope baseline from 58 `FAIL` plus 3 `SETUP_FAIL` to 1 `DEBT`, 57 `FAIL`,
and 3 `SETUP_FAIL`; there are still zero clean passes, and this matrix did not
run simulations. The sole transition is `lowrisc:dv:tl_agent_sim:0.1`: the
unmodified `valid_sources` range now compiles with zero hard errors, leaving 12
pre-existing generic UVM semantic-debt diagnostics. Of the 57 failures, 16
first-stop at dynamic-family cross metadata, 28 at parser/syntax frontiers, 8
at the missing `prim_clock_gating` provider, 3 at unresolved
`clocking_decl_assign` paths, and 2 at isolated export/hierarchical-constant
frontiers. The three setup failures are unchanged generated-file graph issues.
The earlier 18-core coverage-range count included the SVA-lane
`adc_ctrl_sva`; this UVM-only matrix contains 17 such former first frontiers,
one resolved and 16 advanced to cross integration.

Evidence is outside the repository at
`evidence/opentitan-commercial-after237-arm64-20260826/full-uvm/`; the JSON
SHA-256 is
`b52ce5d846544c88f24dba3fbd41b97522247c44567861be85a65d0d2c5b560f`.
The immediate shared OpenTitan coverage frontier is construction-time dynamic
family integration into crosses, followed by dynamic `with` and object/method-
valued ranges. Constructor `ref`/output/inout directions, broader/context-sized
endpoint expressions, dynamic ignore/illegal denominator carving, dynamic
type coverage, report/VPI detail, and 2023 real/tolerance coverage remain
explicit gaps. Unrelated parser/provider/clocking work remains larger than the
coverage cluster.

A fresh native-ARM64 frozen Caliptra census ran all 105 manifests across
Icarus +SVA, Icarus -SVA, Icarus synthesis, and Slang: 420 serial invocations,
zero timeouts, 53/105 in every Icarus lane and 54/105 in Slang. The classes are
52 PASS, 1 DEBT, 51 SHARED_SOURCE_OR_CONFIG, 1 SOURCE_ORDER_DEBT, and zero
ICARUS_GAP or SLANG_ONLY_DIFFERENCE. A job-by-job comparison against after-236
found zero changes in classification, exit/timeout state, diagnostic counts,
or compact diagnostics. Evidence is in
`evidence/caliptra-commercial-after237-arm64-20260826/`; its JSON SHA-256 is
`123e1194cd3cf5915cdcdda396f4f2f22bb1e98226fa54f247f809d67c7ab755`.
External UVMF, ARM AXI checker, and Avery inputs still prevent a full Caliptra
DV runtime claim.

The intended audited direction for this increment is: IEEE 1800-2017 and
1800-2023 are first-class selected editions; unchanged UVM/OpenTitan/Caliptra
are application gates; VCS, Questa, and Xcelium are the commercial
interoperability targets after the IEEE text; Slang is a parser/elaboration
differential; Verilator is diagnostic evidence only; a formal proof engine is
future work; and UPF/IEEE 1801 is deferred until the IEEE 1800 frontend and
runtime are substantially closed. The README, manifesto, roadmap, edition
matrices, and local-standard instructions are audited against that direction
at each checkpoint rather than self-certifying permanent consistency.

## Resume state — 2026-08-26 — declaration lifetimes, call unwind, and DPI ABI

Worktree:
`iverilog-uvm-opentitan-caliptra-after235-arm64-20260826`

Branch: `agent/opentitan-caliptra-after235-arm64-20260826`, based exactly on
`origin/main` at `a375c7b69d2f033535a112a791e7ae5384e960f5` (0 ahead / 0
behind before the pending commits).

This continuation retains the four compiler/runtime clusters exposed by
unchanged OpenTitan and Caliptra sources and closes the recorded DPI disable
protocol gap. Explicit declaration lifetimes now control
storage, initialization, VPI `vpiAutomatic`, fixed-array access, event
identity, virtual-interface dispatch, array-port context, and detached-frame
retention independently of the containing subroutine lifetime. A self-kill
from nested synchronous calls no longer rejoins already-reaped frames, and
abandoned caller-owned automatic contexts are released in exact LIFO order.
Method-local queue `.size`/`.size()` expressions now reach the constraint
solver. The recorded DPI subset now uses Annex-H scalar/result ABIs for narrow
integers, scalar bit/logic, shortreal, chandle, string, packed-vector formals,
and supported export directions, including host plain-`char` polarity and
prefixless old-image compatibility. Exported task C stubs now have the Annex
H.8.2 `int` status ABI, newly compiled imported tasks use a checked integer
acknowledgment ABI, and the runtime implements `svIsDisabledState()` plus
`svAckDisabledState()` with per-invocation state across parked C stacks.

Exact native-ARM64 validation on this branch is clean:

- serial build/install and `make -j1 check` pass;
- legacy ivtest: 4,088 total, 4,083 pass, 2 recorded NI, 3 expected fail,
  0 unexpected fail;
- JSON/VVP: 973 entries, zero harness failures;
- bundled VPI: 103/103;
- negative diagnostics: 136/136;
- scheduler UVM focus: 23/23;
- real-DPI UVM focus: 37/37;
- the process-kill reducer passes the modern and legacy call engines with
  exactly five abandoned call-site contexts released in each mode; and
- parser reports remain 535 shift/reduce plus 1,115 reduce/reduce conflicts
  across 201 states; the VVP parser reports 13 shift/reduce plus 5
  reduce/reduce conflicts across 8 states.

Separately, a fresh full real-DPI run on this branch is clean: the complete
canonical UVM harness passes 354/354 with 0 failed and 0 skipped (real
578.66s), with the real DPI umbrella loaded.

Pinned Slang 11 in IEEE 1800-2017 mode accepts 10 of the 11 new
lifetime/process sources, including the exact process-kill reducer. Its sole
rejection is fixed-array-element `force`/`release`; IEEE 1800-2017 and 2023
§§6.4 and 10.6.2 permit a reference to the selected singular integral
variable, so this is recorded as a differential-oracle disagreement rather
than copied into Icarus. No VCS, Questa, or Xcelium execution was performed;
their IEEE Annex-H task signature and disable behavior remain the practical
interoperability target, not claimed validation evidence. Verilator was not
used as a semantic or ABI oracle.

The focused unchanged Caliptra `axi_pkg.sv` + `axi_if.sv` witness at
`bd31614182fb56e55578f48086a10ded650434fd` compiles with zero diagnostics and
its VVP image loads and exits normally. This proves only package/interface
elaboration and image loading: it does not execute an AXI transaction or a
full Caliptra top. The runtime-only OpenTitan HMAC replay at
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19` reaches the 45-second CPU guard at
210,327,516 ps without the scheduler assertion, another assertion, UVM error
or fatal, loader failure, or crash. It remains short of the former
1,339,336,540 ps failure point and is supporting frontier evidence only; the
mainline-red exact reducers supply the red/green proof. The cleanup census
prints one residual vec4 stack entry while the externally interrupted HMAC
thread is torn down, which is guard-termination noise rather than a natural
simulation exit result.

IEEE 1800-2017/2023 §35.9 and Annex H.8.2 are now implemented for the recorded
DPI task/function subset. An exported task returns 0 after normal completion
or a disable targeting only that export, and returns 1 when an ancestor
disables the enclosing mixed-language chain. In the ancestor case the parked C
stack resumes exactly once for `svIsDisabledState()` and resource cleanup; an
imported task acknowledges with return value 1, while an imported function
calls `svAckDisabledState()`. The disabled SV export/import tails remain dead.
The runtime issues a fatal error for an incorrect task acknowledgment, a
disabled function that omits its acknowledgment, or the §35.9(d)-forbidden
attempt to call another export after entering the disabled state. Newly
compiled task calls use `%dpi/call/task/ack`; the old `%dpi/call/task` void ABI
remains loadable for normal legacy images and diagnoses a disabled invocation
because that ABI has no acknowledgment channel.

Permanent coverage is split deliberately: `m10l_dpi_disable_protocol_test`
checks normal, direct-disable, ancestor-disable cleanup, synchronous-function
acknowledgment, concurrent-call isolation, ancestor cleanup with an outstanding
branch that survived `join_any`, and a second synchronous export that disables
the caller immediately after C resumes from a parked export. The latter pins
the scheduler-owned caller and completed child through re-entry so each still
has one owning reap. Two concurrent automatic callers also verify that direct
VPI work from resumed C runs with the imported task's caller context rather
than the completed export child's context; the four cases in
`run_dpi_disable_protocol_negatives.sh` require the protocol fatals; and
`run_dpi_legacy_task_void_compat.sh` pins both normal old-image execution and
the loud diagnostic when a disabled void-ABI image has no acknowledgment
channel. This closes the
disable-handshake item, not the entire DPI matrix. Imported shortreal arrays
and legal fixed-size unpacked export formals remain loud gaps, and the
exhaustive import/export signature cross-product remains M14B-9 work. Full
OpenTitan and Caliptra application runs and matrices also remain follow-up
work; neither project source tree was modified.

Durable process-unwind detail is in
`session_logs/2026-08-26_opentitan_process_kill_trampoline.md`. Exact SoC and
full-UVM replay artifacts live outside the repository under `evidence/`.

## Resume state — 2026-08-25 — OpenTitan class events and HMAC mask path

Worktree:
`iverilog-uvm-class-event-after233-arm64-20260825`

Branch: `agent/opentitan-class-event-after233-arm64-20260825`, based exactly
on `origin/main` at `92c68dd3c0b8bb0478ec9b6de77f8645ad16c180`.

This increment fixes three compiler/runtime defects exposed by the unchanged
OpenTitan HMAC image: selected class-property event controls now retain and
filter their armed owner; strength-resolved `vec8` nets retain exact Preponed
history; and a run-time index into a singleton outer packed dimension no
longer subtracts the inner slice width. Permanent coverage includes direct
and associative-owner property events, class-only compound events/waits,
mixed ordinary/VIF-plus-property waits, disable-fork cancellation, resolved
strength sampling, and singleton/ascending/descending packed selects.

Broad native-arm64 validation is clean: legacy 4,072 pass / 2 inherited NI /
3 expected fail / 0 unexpected fail (4,077 total); JSON/VVP 962/962; VPI
100/100; negative diagnostics 123/123; and `make -j1 check` passes. The
real-DPI UVM suite must
be invoked with this worktree's `local-install/bin` first in `PATH`; otherwise
the runner selects Homebrew's stock compiler and reports setup failures.

The commercial fixed-array DPI ABI refinement is also green. The target is
IEEE 1800-2017 Annex H compatibility with VCS, Questa, and Xcelium rather than
a Verilator-specific convention. Open arrays continue to receive an
`svOpenArrayHandle`; sized fixed formals now receive the direct C pointer their
declaration requires. Scalar `bit`/`logic`, explicit packed `[0:0]`, atom,
packed-vector, multidimensional, opposite-direction caller/formal, and
256-/384-bit element cases all round-trip, including X/Z and output/inout
copyback. The fixed-array focus is 12/12 and the full supported REAL-DPI group
is 32/32, both with zero skips. Pure DPI libraries must be
loaded with `vvp -d`; `-m` is deliberately reserved for VPI modules that
provide `vlog_startup_routines`.

The exact OpenTitan SHA-384 import now uses the same commercial ABI: its open
message argument is a handle, while `output int unsigned hash[12]` is a direct
pointer. A fresh compile and bounded replay of the unchanged graph reached
218,117,052 ps and began sequence 5/33 before the 45-second CPU guard. Two
digest predictions and two digest reads completed with zero UVM errors,
fatals, assertions, or crashes. That is a focused ABI proof, not a claim that
the randomized HMAC smoke completed.

The current unchanged HMAC image performs real SHA/FIFO work after the packed
mask correction, and cancellable mixed-wait lowering handles its alert/TL
monitor patterns. The exact rebuilt image reached 3,412,009,286 ps, about 87
times beyond the previous 39,220,884 ps blocker, without UVM errors, fatals,
assertion failures, crashes, or a zero-time stall before the 45-second CPU
guard. This is progress evidence, not a full OpenTitan runtime pass. The
class-only compound `@` subset still has one explicit same-time boundary: a
complete expression that changes and restores before its scheduled waiter
runs can be missed. The frozen Caliptra differential remains
Icarus 53/105 versus Slang 54/105 with zero `ICARUS_GAP`; its full compile,
elaboration, and code-generation path is clean, while a clean application
runtime remains outstanding. The most recent full sv-tests differential is
1,021/1,027 for Icarus (99.4%); its six recorded residuals are separate from
this OpenTitan increment.

Durable technical detail and invocation notes are in
`session_logs/2026-08-25_opentitan_class_events_resolved_preponed_packed_index.md`.

## Resume state — 2026-08-24 — clocking static skew and exact modports

Worktree:
`iverilog-uvm-opentitan-clocking-static-skew-fresh-arm64-20260824`

Baseline: `origin/main` at
`3d9afc7c6094fd382d4f118cfae5cb68b1505329`. The clocking implementation and
initial regressions are `db6b1f7e3` and `2ae389d7a`; the audit follow-up and
its six expanded reducers are committed as `e564c2600`.

The implemented IEEE 1800-2017 boundary is 14.3–14.5 declaration/skew/alias
semantics, 14.13 sampled-input ordering, 14.16 packed output buffering and
scheduling, and 25.5 exact modport visibility. Constant packed member/bit/part
output selects are supported for same-scope, static-instance, alias, and VIF
spellings. Run-time selectors, root or nested indexed class receivers, whole
unpacked output clockvars, and selected declaration-assignment targets without
representable hidden storage are loud boundaries; none may fall through to an
ordinary NBA.

The read-only audit found and drove follow-ups for:

- a root indexed receiver evaluated five times instead of rejected at the
  existing once-capture boundary;
- output-skew elaboration repeated once per static source drive;
- exact modport qualifiers lost through typedef, class type-parameter, and
  unpacked-struct carriers;
- VPI-backed output arguments directly mutating sampled inputs, clocking
  outputs, and modport inputs; and
- a partial nested l-value tree leaked on modport rejection.

The VPI boundary is now precise: integral/string VIF property reads remain
supported, while any `vpi_put_value` to a VIF property is a loud run-time
error, sets a failing status, and leaves the target unchanged. Ordinary
assignments and clocking drives keep their checked language paths.

Post-audit verification is complete: both expanded clocking focuses are
36/36; the SystemVerilog manifest is 1850/1850; JSON/VVP is 918/918; the
default legacy manifest is 4029 pass / 2 NI / 3 EF / 0 fail; VPI is 97/97;
negative diagnostics are 111/111; the clocking Slang differential is 59/59;
`make check` passes; and real-DPI UVM is 338/338.

A fresh OpenTitan replay is 7/7 for setup and compile with zero hard compile
errors. Six long simulations advance through time until the 45-second CPU
guard; ADC retains its known zero-time UVM testbench fatal. No compiler abort
or scheduler assertion occurs. The frozen Caliptra differential remains
Icarus 53/105 in each of assertions, no-assertions, and synthesis versus Slang
54/105, with zero `ICARUS_GAP`; the sole raw Slang lead remains source order.
These are compatibility-frontier results, not clean full-application runtime
pass claims.

Durable detail is in
`session_logs/2026-08-24_opentitan_clocking_static_skew_modports.md`. The local
ignored standards reference is `docs/standards/local/IEEE_1800-2023.pdf`,
SHA-256
`2280eb7f39532ca990b9bbd2e4226ae5c89910b51f42b2eb0e972df4403c9597`;
the PDF is not part of the change.

This is the short resume state. `ROADMAP.md` is the living tracker,
`iverilog_ieee1800_uvm_manifesto.md` carries policy, and dated technical
narratives live in `session_logs/`.

## Resume state — 2026-07-28

Branch: `claude/ieee1800-closure-campaign-lqalye`, started fresh from
main and rebased onto `7136907`, which carries the merged PRs #125, #126
and #127. The previous PR on this branch (#121) is merged, so this is a
new pull request rather than a continuation of that one.

### Campaign 2 — whole aggregate value semantics

One missing primitive turned out to explain four separate symptoms. A
fixed unpacked array used where a container is wanted has marshaled its
words since M10-1 (`%load/arr/dar`); the **return trip did not exist**,
and each place it was needed failed differently:

| shape | what it did |
|---|---|
| `fa = da;` and `s.arr = da;` | assigned the **constant 0**, silently |
| `t(fa)` for `inout int q[]` | **aborted ivl** on legal input, even when the body only read the formal |
| `f(fa)` for `ref int q[]` | warned once, then silently left the caller's array alone |

The assignment case is the one worth remembering. `fa = da` is not
`type_compatible`, so it reached the compile-progress fallback in
`elab_and_eval` that substitutes a constant for an incompatible r-value
when the target looks vectorable — and an unpacked array's `cast_type`
is its ELEMENT type, so `int fa[3]` looked exactly that vectorable.

New `%store/arr/dar` is the inverse of `%load/arr/dar`, and all four
paths go through it. The 7.6 element-count rule is checked inside the
instruction, because a dynamic source has no size until it runs; a
mismatch reports and leaves the destination unchanged rather than
half-filling it.

The inbound direction is fixed for **real** elements too: the special
case meant to accept a fixed-array actual for an open-array formal asked
the EXPRESSION for its `netuarray_t`, but a signal expression's
`net_type()` is its element type, so the test never succeeded — integral
arrays slipped past on the vectorable fallback while real arrays took a
cast error.

Roadmap: M10-7 (done), M10-8 (the multidimensional boundary, open and
loud). Tests: `sv_whole_aggregate_value_copy`,
`sv_whole_aggregate_size_mismatch`.

**Verified, not assumed, on the way through:**

- DPI open arrays are complete — re-probed with a fresh C model, not an
  existing test: `svDimensions`/`svSize`/`svLow`/`svHigh`/`svLeft`/
  `svRight`/`svIncrement` all report the **declared** range for
  ascending, descending and non-zero-based actuals, elements read
  through `svGetArrElemPtr1`, and an `inout` formal writes back.
  GitHub issue #45 closed on that evidence.
- Multidimensional open arrays now work at **any legal dimensionality**,
  verified 1-D through 5-D for read, `foreach`, element write and
  whole-array copy-back. That took pushing past **five** separate
  two-dimension caps — see ROADMAP M10-8. The one worth remembering:
  `NetESelect::dup_expr()` dropped the select's `net_type`, so a
  duplicated container select reported no type and `foreach` over a
  three-deep container elaborated two levels and then produced **no loop
  at all** for the third — zero iterations, no diagnostic.

### A finding I had to withdraw

I recorded nested containers — `int d[][]`, `int m[string][]` — as an
unparseable subsystem and filed R19 against it. That was wrong, and the
error was mine: my probe used `foreach (m[k]) foreach (m[k][i])`, which
is not legal SystemVerilog. `foreach` takes one bracket with a
comma-separated variable list. The syntax error was on my `foreach`
line, not on the declaration.

Re-probed with `foreach (m[k,i])`: nested dynamic arrays, queues of
queues and associative arrays of dynamic arrays all declare, allocate
per level, iterate, index, and pass to open-array formals. Nothing there
needed building. R19 is withdrawn; R24 records the withdrawal so the
claim is not rediscovered.

That re-probe did turn up one real gap, now fixed: a **queue of queues**
was refused as an open-array actual. The outer level had a queue/darray
passthrough, but inner levels were compared strictly, and a queue is not
`type_compatible` with a dynamic array even though they share
`vvp_darray` at run time.

### Next frontier

Campaign 2's acceptance criteria are all met — see the pull request for
the evidence. The remaining severity-ordered items are R17 (`$typename`
on a parameterized class returns a wrong string — the only *wrong value*
left), then R18, R20, R21, R22, and the deliberately-unvalidated R23.

### Truth pass — 2026-07-28

The five `Phase 7x` GitHub issues were probed item by item rather than
read. #43, #44, #45 and #47 are closed: #45 genuinely complete, the
other three obsolete as tracking units (their acceptance criterion,
"96+/98 regression", names a suite that no longer exists). #46
(performance) is deliberately left open and unre-labelled — its claims
are wall-clock measurements I did not reproduce, and closing it on the
strength of the others would be the sort of unvalidated label this pass
exists to remove.

Sixteen of the twenty-eight probed items were already done. The
survivors carry forward as R17–R23. One correction to my own first
reading: `a.reverse()` returning nothing is **not** a defect — 7.12.2
ordering methods return void, so the r-value spelling I probed with is
not legal SystemVerilog. The in-place form works.

### Gates

`make check`, the vendored ivtest name-diff, bundled VPI, the negative
suite, the SVA dual-run, the DPI subsystem and full UVM — see the pull
request for the run.

One regression was caught by the name-diff and fixed rather than
absorbed: the first cut refused a multidimensional copy-back outright,
which broke `sv_struct_array_member_open_arg` — a member destination had
been working all along through `%store/prop/arr/dar`. The new path now
takes over **only** a plain word-array signal destination, which is the
one shape that had no instruction.
