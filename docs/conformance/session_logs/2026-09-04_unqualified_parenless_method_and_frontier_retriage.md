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

## 4. The ref-formal warning: re-classified, then fixed

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

## 6. Recorded, not chased: unresolved `i` in a constraint foreach

18 occurrences across i2c_sim and the two `*_chip_sim` cores, reported as
`Unable to bind wire/reg/memory `i''. The reported line is a blank line at the
end of a task -- a macro-expansion artifact. The real construct is inside
`DV_CHECK_RANDOMIZE_WITH_FATAL`, e.g. `spi_host_seq.sv`:

```systemverilog
foreach (data[i]) {
  data[i] == local::data[i];
}
```

The gap is that the constraint `foreach` loop variable is not bound when
resolving an index inside a `local::`-qualified reference (IEEE 1800-2017
18.7.1, `local::` scope resolution inside `randomize() with`). Not chased:
the affected cores carry other blockers, so clearing it alone moves nothing.

## 7. Ref-formal: clause verified and blast radius measured

Recorded here because an earlier note cited "IEEE 1800-2023 ~line 16150", which
is a LINE number, not a clause. The actual citation is **IEEE 1800-2017 9.3.2
(Parallel blocks)**, identically worded in 1800-2023 except for an added
`ref static` exception:

> Within a fork-join_any or fork-join_none block, it shall be illegal to refer
> to formal arguments passed by reference other than in the initialization
> value expressions of variables declared in a block_item_declaration of the
> fork[, unless the argument is declared ref static].

Note the exception the earlier note omitted: a reference IS legal in the
initialization value expression of a fork-local variable.

Blast radius, measured before implementing: the warning has exactly **one**
site in the entire corpus -- `shadowed_csr` in `glitch_shadowed_reset` -- with
71 occurrences across 17 cores. In that task the formal is referenced only in a
plain `foreach` at lines 228-233; there are no literal fork/join tokens, and
the sole detached fork comes from `DV_SPINWAIT` (which expands to nested
`fork ... join_any` via `DV_SPINWAIT_EXIT`) whose arguments do not mention the
formal.

So narrowing the gate to "the formal is referenced inside a detached fork
subtree" clears all 71 lines, and the error branch is **dead code on this
corpus** -- no core can move backward.

### Implemented

Gate changed from `task_body->contains_detached_fork()` to
`task_body->detached_fork_refs_name(port->name())`, backed by two pform
virtuals:

- `Statement::refs_name(perm_string)` -- default **true**, overridden in ~20
  kinds; `PExpr::refs_name(perm_string)` -- default **true**, overridden in 12.
- `Statement::detached_fork_refs_name(perm_string)` -- default **false**,
  overridden in exactly the kinds that override `contains_detached_fork()`, so
  it locates detached forks as completely as that already-trusted walk.

The polarity is the entire safety argument: an unmodelled node kind answers
"referenced", so the diagnostic is retained. A missing override costs
precision, never soundness.

The message now cites 9.3.2 and says the construct is illegal, rather than
describing only the lost-write symptom.

Verified: `top_darjeeling_xbar_dbg_sim` drops from 3 debt lines to **1** (the
constraint alone). slang agrees in both directions -- it rejects the illegal
shape with `-Wref-arg-in-fork-join` and accepts the legal one with 0 warnings.

Two paired regressions: `sv_ref_queue_formal_unrelated_fork` (legal shape must
stay quiet, and writes through the reference must still reach the caller) and
`sv_ref_queue_formal_fork_illegal_warn` (the 9.3.2 violation). The second one's
gold is a live demonstration rather than a text pin -- it prints
`caller sees size 1 (the branch's write is lost)`. Writing it exposed a first
draft where the branch finished BEFORE the task returned, so the copy-out
captured the write and nothing was lost; the delays had to be inverted to make
the hazard real.

## 8. The constraint frontier is five mechanisms, not one

Aggregating by message makes "constraint `X' could not be translated" look
like a single family (42 occurrences, 15 cores). Decomposing by the actual
constraint TEXT shows five unrelated mechanisms, in rising order of cost:

| Shape | Occ | Nature |
|---|---|---|
| `(value) <= ($clog2(RxFifoDepth))` (uart_base_vseq.sv:109-110) | 4 | A constant system function -- see below. Cheapest of the set. |
| `(num_lanes) == (cfg.get_sio_size())`, `...idcode.get_n_bits()`, `(m_data_pkt.data.size()) == (num_of_bytes)` | 8 | A method call on a NON-RANDOM state object. Needs solve-time evaluation of an arbitrary state expression -- the general feature the `delem`/`qmelem` nodes only do for properties. |
| `foreach (data_q[...])` (spi_host_tpm_seq.sv:60) | 4 | A second foreach shape. |
| kmac `local::`-qualified compounds | 8 | Mixed; not yet decomposed. |
| `if (use_last_item_addr) { ... } else { ... }` (xbar_tl_host_seq.sv:46) | 20 | The hierarchical `foreach` target -- `elaborate.cc` bails deliberately on `has_hierarchical_target()`. Needs hierarchical path storage plus package-scope resolution in the constraint IR. Most expensive, and the last xbar blocker. |

The same lesson as section 1 applies: the message is not the mechanism.

### The `$clog2` case is a silent wrong answer, and it is general

Reduced, it is not about parameters or even about randomization:

```systemverilog
class it;  rand int unsigned v;  constraint c { v <= $clog2(64); }  endclass
class it2; rand int unsigned v;  constraint c { v <= $bits(int); }  endclass
```

Both constraints are DROPPED -- `warning: Constraint item ... is not
representable in the constraint solver and is ignored` -- and both variables
come back completely unconstrained (observed 2915189536 and 3905576338 against
bounds of 6 and 32). A LITERAL argument fails, so this is not a missing
constant-fold of a parameter reference: the constraint IR converter handles no
constant system function at all.

This is the same defect class as the `get_full_name` one fixed in this branch:
a "compile-progress" warning standing in front of a silently wrong answer
rather than an unsupported-but-safe fallback. The fix direction is to evaluate
an elaboration-time-constant sub-expression and emit it as an IR literal, which
covers `$clog2`, `$bits` and the rest at once.

## 9. Note on predicted movement

The 8 xbar cores appear in both lanes with identical debt, but the lanes do not
share a PASS criterion. Clearing compile debt makes the **uvm** rows PASS; the
**runtime** rows will then attempt execution for the first time and may land in
RUNTIME_FAIL or RUNTIME_TIMEOUT. No core count will be claimed before the
per-core census diff says so.
