# CURRENT WORK — continuation state

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
