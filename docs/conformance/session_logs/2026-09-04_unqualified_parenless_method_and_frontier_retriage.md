# 2026-09-04 — Unqualified paren-less method calls, and a re-triage of the uvm/runtime frontier

Branch: `agent/string-array-param-after253-arm64-20260904` (PR #254)

## 1. Frontier re-derived from census data, not from the previous log's narrative

Starting point: the seed-propagation census
(`evidence/opentitan-seedprop-after253-arm64-20260904`), PASS 195, DEBT 33.

Aggregating the **uvm** and **runtime** lanes by first diagnostic gave 49 of 82
FAIL rows as bare `syntax error` — apparently the dominant family. Resolving
each to its source construct dissolved it into three unrelated categories, and
**the two largest were not compiler gaps**:

| Category | Cores | Verdict |
|---|---|---|
| `static task host();` at module/program scope | 4 | **Upstream-invalid** — IEEE 1800-2017 A.2.6 puts `lifetime` *after* the keyword (`task static host()`); a leading `static` is legal only as a class `method_qualifier` (A.1.9). slang rejects it too. |
| `import pkg::item;` in a class body | 2 | **Upstream-invalid** — already recorded. |
| Undefined macros (`RNG_BUS_WIDTH`, `SRAM_TYPE`, `INSTR_EXEC`, …) | 6 | **Census harness gap** — per-core dvsim `build_opts` defines are not extracted. A `warning: macro X undefined (and assumed null)` precedes the syntax error in `matrix-compile.log`. |

The durable lesson is recorded as a memory: check the IEEE BNF and slang on a
four-line reducer *before* writing grammar code. Core count measures how often
OpenTitan writes a construct, not whether it is legal.

## 2. The real frontier is the DEBT set, and it is the xbar family

`DEBT` is decided by `setup_findings or semantic_debt` being non-empty
(`opentitan_matrix.py`), so enumerating `semantic_debt` per row is complete for
the uvm lane. Doing that showed:

- **All 27** uvm/runtime DEBT rows carry the ref-formal queue mechanism.
- No row is one mechanism from PASS; the minimum is three.
- **16 rows (8 cores × 2 lanes) are the xbar family**, each with exactly three
  mechanisms: unresolved `get_full_name`, an untranslated constraint, and the
  ref-formal warning.

That makes the xbar three-set the correct unit of work.

## 3. Fixed: unqualified paren-less zero-argument method call (IEEE 13.4.2)

`xbar_base_vseq.sv:68-70` writes `` `uvm_info(get_full_name, …) `` — a bare
identifier naming a zero-argument method inherited from `uvm_object`.

This was **silent and wrong, not merely unsupported**: the reference failed
signal binding, elaborated to nothing, and the read yielded an empty string.
The only diagnostic was a compile-progress warning.

Fix: `paren_less_class_method_call_()` in `elab_expr.cc`, called from **both**
binding-failure paths. It runs only after ordinary signal binding has failed,
so it cannot shadow a real signal.

Two details that mattered:

- **The argument count must discount the implicit `this`.** A non-static class
  method carries the synthetic `THIS_TOKEN` (`"@"`) port ahead of its declared
  arguments, so a zero-argument method has `port_count() == 1`; a *static* one
  has no `this` and gives `0`. Discounted the way `elab_sig.cc:1292` does.
  Testing `port_count() != 0` makes the guard never fire; `<= 1` would wrongly
  resolve one-argument methods.
- `func_def()` may be null before a signature is published — skip, don't guess.

### Why this took five rebuild cycles in an earlier session

The prior attempt placed a probe immediately before the
`Unable to bind wire/reg/memory` warning; the probe never executed while the
warning did, and the cause was never found.

**There are two emitters of that message in `elab_expr.cc`, and the one that
fires is the earlier, deeper-nested one.** `grep` for the full phrase finds
only one site because at the other the string is split across a line break:

```cpp
cerr << ... ": warning: Unable to bind "
     << "wire/reg/memory `" << path_ ...
```

Separately: `driver/iverilog` invokes the **installed** `local-install/lib/ivl/ivl`,
so `make` alone does not put a change in front of the driver — `make install`
is required. That, not env-var propagation, is why probes appeared not to fire.

### Verification

- New paired regression `sv_class_parenless_unqualified_method` (2017/2023),
  covering the inherited case, a **static** method (no implicit `this`, the
  other side of the port-count branch), explicit parentheses, a one-argument
  method that must *not* resolve paren-less, and a same-named local variable
  that must still win. slang 11.0.448: 0 errors, 0 warnings.
- Real core recompiled (working rule 7): `top_darjeeling_xbar_dbg_sim` drops
  from 6 debt lines to 3 — all three `get_full_name` lines gone.
- All 8 xbar cores carry `get_full_name` as their **only** unresolved name, so
  the mechanism is fully cleared for the whole family.

## 4. Re-classified, not implemented: the ref-formal warning

Checked before writing code, and the answer changed the plan:

- The callee `glitch_shadowed_reset` **never writes** the queue formal — it
  only reads it.
- The call site is a plain `fork…join`, so IEEE §16150 (ref arguments in
  `join_any`/`join_none`) does not apply.
- The warning nonetheless fires because its gate is
  `task_body->contains_detached_fork()`, and the callee body *does* contain one
  through a macro expansion (`DV_SPINWAIT`).

Value-copy has **two** hazards, and the warning names only the first. The
second is the mirror image: `t-dll.cc:3575` binds a container `ref` formal as
`IVL_SIP_INOUT`, so even a read-only callee copies *out* at return — if the
caller mutates the actual concurrently (here a sibling `fork` branch runs
`run_csr_vseq`), the stale copy-out silently clobbers it. **A read-only callee
is therefore necessary but not sufficient** for the deviation to be
unobservable, so simply suppressing the warning would be unsound.

`peek_lref()` looked like a cheap read-only test but is unusable: the
diagnostic is emitted during *signal* elaboration (`elab_sig.cc:3081`), before
any statement is elaborated, and it would under-count queue mutations such as
`push_back`. Deferred deliberately rather than rushed.

## 5. Remaining xbar mechanisms

- **Constraint, nested indexed foreach target.** `elaborate.cc` bails
  explicitly on `cfe->has_hierarchical_target()`. The comment is right to: the
  array (`xbar_devices`) is package-scope, not a rand property, and falling
  through to the single-level lookup would silently iterate the *wrong* array.
  Needs hierarchical path storage plus package-scope resolution in the
  constraint IR.
- **Ref formal**, as above.

Neither clears a row alone — every xbar core needs all three.

## 6. Note on predicted movement

The 8 xbar cores appear in both lanes with identical debt, but the lanes do not
share a PASS criterion. Clearing compile debt makes the **uvm** rows PASS; the
**runtime** rows will then attempt execution for the first time and may land in
RUNTIME_FAIL or RUNTIME_TIMEOUT. No core count will be claimed before the
per-core census diff says so.
