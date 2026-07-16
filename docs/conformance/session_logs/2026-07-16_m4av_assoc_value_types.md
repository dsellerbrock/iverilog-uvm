# 2026-07-16 — M4-av: string/real-valued associative-array reads

Directive: continue the Milestone Truth Audit corrective pass —
implement **M4-av**, the remaining *silent* wrong-behaviour gap flagged
under M4 (SUBSET COMPLETE). This was the last silent miscompile on the
audit's reopened-items ledger (M3-rm, the other silent one, closed
earlier this session).

## Root cause

For a **module-static (bare-signal)** associative array whose element
type is `string` or `real`, the store used the keyed associative opcode
(`%aa/store/{str,r}/*`) but the *read* fell through to the **positional**
dynamic-array/queue load (`%load/dar/{str,r}`). A positional load indexes
by ordinal position, so an integer- or string-keyed lookup returned the
element at that ordinal — for a sparse assoc that is almost always the
default (empty string / `0.0`). Silent: no diagnostic, wrong value.

- Fixed in M14: the **vec4(int)-valued** int-key read.
- Still broken (this milestone): `string s[int]`, `string s[string]`,
  `real r[int]`, `real r[string]` bare-signal reads.
- Never broken: **class-member** assoc reads, which go through
  `%prop/obj` and already emit the keyed `%aa/load/*` form.

The keyed `sig`-form load opcodes (`%aa/load/{str,r}/{v,str}`) already
existed and were exercised by the `%prop/obj` path; only the bare-signal
codegen branch was missing.

## Fix (codegen only — no runtime change)

`tgt-vvp/eval_string.c` and `tgt-vvp/eval_real.c`: in the bare-signal
darray/queue branch, after the existing `obj`-key case, added a
`string`-key branch and a vec4-key branch, guarded by
`ivl_type_queue_assoc_compat(net_type)` (true for assoc, false for real
positional queues/darrays, so positional queues stay on `%load/dar`).
Each emits: draw the key (`draw_eval_string` / `draw_eval_vec4`),
`%load/obj v%p_0` to push the container object, the keyed
`%aa/load/{str,r}/{str,v}`, then `%pop/obj 1, 0` to drop the container
the load peeked.

## Verification

Permanent test `tests/m4av_assoc_value_types_test.sv` (self-checking):
int- and string-keyed `string`/`real` assoc reads, positional
`string`/`real` queues (must stay correct), update-then-read, `foreach`,
`exists`/`num`/`delete`, and missing-key defaults. Prints
`PASS: m4av assoc value types`.

Regression gates:

- **UVM: 169/169** (168 baseline + the new m4av test), **zero
  no-check**, zero fail.
- **ivtest: baseline-identical** — 99 real fails unchanged. A 100th,
  `pow_ca_signed`, appeared only under the concurrent UVM+ivtest sweep
  load (a documented ~compile-time flake); it **passes standalone**, and
  the fix is pure assoc-read codegen with no relation to the `pow`
  operator or constant functions.
- **Negative: 24/24** — all reject with diagnostics.

## Status

**M4-av DONE.** Both silent miscompiles from the truth audit (M3-rm,
M4-av) are now closed. M4 remains **SUBSET COMPLETE** overall (its other
recorded corners are loud, in-scope-but-deferred). Next priority
(completeness, not correctness): M9C/M9B temporal/sequence operators
`within` / `until` / `until_with` / `intersect`.

Commit: `tgt-vvp: string/real-valued integer- and string-keyed assoc
reads (M4-av)`.
