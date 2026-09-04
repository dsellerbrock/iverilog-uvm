# The rstmgr diagnostic chain, parameter typing, and a census-driver correction (2026-09-03)

## Scope and status

Four compiler changes and one census-driver correction, developed against the
OpenTitan DV frontier. No clause is claimed complete and no OpenTitan core is
claimed to newly PASS. Three of the four compiler changes advance a core's
*first diagnostic* rather than clearing it, which is recorded here as the
result rather than smoothed over.

Working tree `iverilog-uvm-foreach-scoped-after252-arm64-20260903` on branch
`agent/opentitan-foreach-scoped-after252-arm64-20260903`, based exactly on
`origin/main` `8236b9f8c` (PRs #251 and #252 merged and validated).

The five commits, in order:

| Commit | Kind | Mechanism |
|---|---|---|
| `851cbdbde` | compiler (`parse.y`) | package-scoped array as a `foreach` target |
| `26623c52c` | compiler (`net_design.cc`) | string-valued untyped parameter: internal error + SIGSEGV |
| `660ee9379` | **census driver** (`scripts/opentitan_matrix.py`) | root the DV testbench when a core declares a stale toplevel |
| `c29a073df` | compiler (`parse.y`) | interface instance named after its own interface type |
| `b526e51d4` | compiler (`net_design.cc`, `elab_expr.cc`) | parameter's lone unsized unpacked dimension, plus a latent compiler abort |

`660ee9379` changes **no compiled source**. It is a correction to how our census
asks Icarus the question, not a change to Icarus and not a change to OpenTitan.
Its effect on the matrix must not be read as compiler progress; see
*Census provenance* below, where the compiler engine hash proves the point.

## Normative audit

The local, untracked IEEE 1800-2017 and IEEE 1800-2023 LRMs were read directly.
Every rule applied here is shared by both editions; no `-g2023`-only semantic
path is introduced, and every regression is registered paired 2017/2023.

| Area | IEEE 1800-2017 | IEEE 1800-2023 | Rule applied |
|---|---|---|---|
| `foreach` loop | 12.7.3 | 12.7.3 | The loop variable list indexes the dimensions of an array-typed expression. The clause constrains the *array*, not how the array's name is qualified, so a package-scoped name is as valid a target as a local one. |
| Untyped parameter typing | 6.20.2 | 6.20.2 | A parameter declared with no data type takes its type from the value finally assigned to it, including a `string` value. |
| Unsized unpacked dimension | 6.20.2 with A.2.4 | 6.20.2 with A.2.4 | A parameter may leave a single unpacked dimension unsized and take its size from its initializer. |
| Size casting | 6.24.1 | 6.24.1 | A size cast applies to an integral expression. `string` is not integral, so `64'(s)` on a `string` parameter is illegal — the residual half of the `prim_lfsr` finding. |
| Interface instances and hierarchy | 25.3 with 23.3.2 | 25.3 with 23.3.2 | An interface instance introduces a hierarchical name. Nothing prohibits that instance name from coinciding with its own interface type name, and the resulting hierarchical reference is valid in read, indexed and l-value positions alike. |

slang 11.0.448 was used as an independent comparison under both `--std 1800-2017`
and `--std 1800-2023`. It is not treated as the oracle: in every case below the
LRM clause was read first and slang consulted second, and where slang and Icarus
*agree that source is invalid* (`prim_lfsr`) that agreement is reported as
corroboration of a clause reading, not as its basis.

## The rstmgr chain

The most instructive result of this increment is that a single OpenTitan core
walked through three distinct compiler defects, each hidden behind the one
before it. `rstmgr_sim` (darjeeling and earlgrey, uvm and runtime lanes — four
rows) moved:

```
tb.sv:43/61: syntax error
    -> c29a073df (interface instance named after its own type)
rstmgr_env_pkg.sv:37: error: An unsized dimension is not allowed here.
    -> b526e51d4 (parameter's lone unsized unpacked dimension)
rstmgr_base_vseq.sv:272/278: fixed unpacked-array value and queue/dynamic-array
    context may differ only in the slowest-varying unpacked dimension
    -> NOT addressed here; this is the next link
```

Two process consequences follow, and both were paid for the hard way:

1. **A frontier fix usually advances a diagnostic rather than clearing a core.**
   No core count may be claimed until the census diff says so. Every commit in
   this increment states explicitly which rows advanced and to what.
2. **The real core must be recompiled after any elaboration change.** The latent
   compiler *abort* fixed in `b526e51d4` was only reachable once
   `LIST_OF_LEAFS` genuinely existed as an array parameter. A reduced test case
   would not have produced it; recompiling `rstmgr_sim` did.

## Mechanisms

Full root-cause analysis, implementation notes and measured before/after are in
the commit messages and are not duplicated here. What follows is what belongs in
the conformance record rather than in a commit.

### Package-scoped `foreach` target (`851cbdbde`)

The defect was in the **lexer/grammar interface**, not the loop. `lexor.lex`
returns `PACKAGE_IDENTIFIER` for a package it has already seen, while
`foreach_array_identifier` carried only an `IDENTIFIER K_SCOPE_RES IDENTIFIER`
alternative — a production that can therefore only fire for a name the lexer
does *not* yet know to be a package. A real package-qualified target matched no
production at all and died as a bare `syntax error` naming no mechanism.

Grammar impact was measured rather than assumed: 6070 -> 6074 states, exactly
four new states for the two new productions, and the multiset of per-state
conflict signatures **identical**. Conflict totals alone (533 s/r, 1119 r/r
before and after) are a weak signal in this grammar, because a `%precedence`
can hold a total constant while the automaton underneath changes shape.

### String-valued untyped parameter (`26623c52c`)

Two stacked defects, the second worse than the first: the missing
`IVL_VT_STRING` case fell to `default`, and that `default` arm dereferenced
`param_type` while printing its own diagnostic — a pointer that is null
*precisely* when the parameter is untyped, which is the only way to reach that
arm. The compiler segfaulted inside its own error message.

The general lesson is recorded because it recurs: **an error path that
dereferences the thing whose absence defined the error is a latent crash.** The
`default` arm now prints `<none: the parameter is untyped>`, so any future
unhandled type reports instead of crashing.

The core that found this, `prim_lfsr_sim`, remains correctly blocked. Once
`LfsrType` properly has type `string`, `prim_lfsr.sv:283`'s `64'(LfsrType)` is
illegal under 6.24.1. `prim_lfsr_tb` overriding from a `localparam string` and
`prim_lfsr` casting that parameter are together invalid upstream source; slang
rejects the identical combination. **No OpenTitan source was modified**, and no
claim is made that `prim_lfsr_sim` compiles — what changed is that Icarus now
says so with a focused diagnostic instead of crashing.

### Interface instance named after its own type (`c29a073df`)

The failure looked arbitrary until the classification was traced: the un-indexed
read parsed, while the indexed and l-value forms were syntax errors. The lexer
hands such a name back as `TYPE_IDENTIFIER` (the interface name *is* a type),
and `expr_primary: TYPE_IDENTIFIER` — load-bearing for UVM parameter actuals
such as `uvm_object_registry #(uvm_pool #(KEY,T))` — is declared earlier than
`hierarchy_identifier: TYPE_IDENTIFIER`, so it won the reduce/reduce conflict.
`expr_primary` supports member access but its result cannot then be indexed and
is not a valid l-value.

The repair spells the two-token form as one production,
`hierarchy_identifier: TYPE_IDENTIFIER '.' IDENTIFIER`, giving the parser a
*shift* at the decision point. Reordering the two rules instead would have been
wrong, and the note is kept because the tempting fix is the wrong one.

`IVL_TRACE_TYPES=1` prints each type-identifier test and is the fastest way to
confirm which way a name is being classified. A shadowed struct typedef
(`t t; ... t.a[0]`) does *not* hit this, because the lexer's scope test finds
the variable and returns `IDENTIFIER`; an interface instance is not registered
that way.

This is the one change on the branch that is **not** conflict-neutral: +8 s/r
and +3 r/r. The per-state signature diff shows the change is localized — a
handful of states gain one conflict each, no state's shape is restructured —
but new conflicts in this grammar are exactly what silently changes how
unrelated constructs parse, so the full 530-job census was re-run and diffed
per core rather than relying on ivtest and UVM.

**Known limitation, deliberately left:** this fixes the reference, not the
classification. The name is still lexed as a type identifier, so any construct
needing it to be an `IDENTIFIER` before a `.` remains unaddressed. Registering
an interface instance so that it shadows the type name in the lexer's scope
test would be the general repair.

### Unsized unpacked dimension, and a latent abort (`b526e51d4`)

`NetScope::evaluate_parameter_array_` walked declared unpacked dimensions
through `evaluate_range()`, whose own comment states that unsized and queue
dimensions "should be handled before calling this function" — and nothing in
the parameter path ever did, even though the initializer sitting next to the
declaration already carries the count.

Multi-dimensional unsized declarations are **deliberately not inferred** and
stay a loud error, pinned by `sv_param_unsized_multidim_fail`. A flat element
count says nothing about how the dimensions should be split, so a guess would be
worse than the diagnostic.

The latent abort is the more serious of the two defects.
`ivl_assert(*par_val, par_string)` in `elab_expr.cc` assumed a string-typed
parameter always carries a `NetECString` value. An *array* parameter's own value
is a sentinel — its elements are separate parameters — so a string method called
on an element the elaborator could not fold to one constant arrived with that
sentinel and killed the compiler one line after a `sorry:` had already described
the real problem. It now reports and returns.

```
rstmgr_sim before: exit 134, abort, 11 errors
rstmgr_sim after:  exit 17,  no abort, 13 errors, advanced into rstmgr_base_vseq.sv
```

### Census driver: rooting the DV testbench (`660ee9379`)

Eight cores failed on a module they never instantiate:

```
prim_clock_gating_sync.sv:26: error: Unknown module type: prim_clock_gating
```

Not a language gap and not an Icarus defect. The driver compiled these cores
with **no `-s` root at all**, so every uninstantiated module in the source list
became a root — including `prim_clock_gating_sync`, which `lowrisc:prim:all`
ships in its fileset while depending on no provider of that module. Only
`clkmgr`, `rv_core_ibex` and `ast` declare that dependency, so for an xbar sim
the implementation is legitimately absent and the design never reaches it.

`validated_top_options()` drops a `-s` naming a module absent from the source
list — several upstream cores declare a stale toplevel — then substitutes the
core's own module. `lowrisc:dv:top_darjeeling_xbar_dbg_sim` declares
`toplevel: xbar_tb_top`, which exists nowhere in its fileset, and its own
fileset contributes only *include* files, so there was no own module to fall
back to. That reached the final branch, "letting the compiler select the root
modules", which for a UVM testbench is never what the real flow does — dvsim
roots the testbench explicitly.

The driver now roots `tb` when the declared toplevel is absent and the core
contributes no module of its own. A note is recorded on the record, as the other
substitutions already do, so the choice is **visible in the matrix rather than
silent**. Verified directly first: with `-s tb` the `xbar_dbg_sim` core compiles
to a 54 MB image with zero errors and zero `sorry:`.

## Census provenance

530 jobs per run, unmodified OpenTitan `7a3ad34b6`, FuseSoC 2.4.5 / Edalize
0.6.3 via the pinned ARM64 Python 3.13 venv. Four census runs cover the branch;
`851cbdbde` and `26623c52c` were developed together and land together, and are
censused as a combined tree.

| Census | Covers | Compiler engine SHA-256 | PASS | FAIL | DEBT | RUNTIME_FAIL | UPSTREAM_INVALID | DEP | SETUP_FAIL | TIMEOUT |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| baseline `8236b9f8c` | merged main | `bc9c9850c1…` | 192 | 104 | 20 | 15 | 35 | 157 | 6 | 1 |
| `opentitan-foreach-string-…` | `851cbdbde` + `26623c52c` | `3257d03d20…` | 192 | 104 | 20 | 15 | 35 | 157 | 6 | 1 |
| `opentitan-toproot-…` | `660ee9379` | `3257d03d20…` | 192 | **88** | **36** | 15 | 35 | 157 | 6 | 1 |
| `opentitan-ifcollision-…` | `c29a073df` | `163f75dbab…` | 192 | 88 | 36 | 15 | 35 | 157 | 6 | 1 |
| `opentitan-unsized-…` (HEAD) | `b526e51d4` | `1198b71911…` | 192 | 88 | 36 | 15 | 35 | 157 | 6 | 1 |

Evidence dirs are `evidence/opentitan-{foreach-string,toproot,ifcollision,unsized}-after252-arm64-20260903`;
the baseline is `evidence/opentitan-caliptra-after252-arm64-20260903/opentitan`.

**The compiler engine hash is the load-bearing column.** The `toproot` census
ran against a *byte-identical* compiler to the `foreach-string` census before it
(`3257d03d20…` in both rows). The entire FAIL 104 -> 88 movement is therefore
provably the census driver, with no compiler edit involved. The sixteen rows are
the eight `top_{darjeeling,earlgrey,englishbreakfast}_xbar_{dbg,main,mbx,peri}_sim`
cores in their uvm and runtime lanes, and they move **FAIL -> DEBT, not
FAIL -> PASS**: they get past compile, and what remains is UVM factory/registry
semantic debt, which is separate and larger work.

The three compiler censuses show **zero status changes in either direction**.
That is the intended result for `c29a073df` in particular, whose added grammar
conflicts could have silently changed unrelated parses; the census is the
evidence that they did not.

Caliptra: 52 PASS, ICARUS_GAP 0 — verified unchanged.

## Suite validation

Measured at branch HEAD `b526e51d4`:

| Suite | Result |
|---|---|
| legacy ivtest (`perl vvp_reg.pl`) | Total=4519, Passed=4514, Failed=0, NI=2, EF=3 |
| JSON/VVP ivtest (`python3 vvp_reg.py`) | Ran 1411, Failed 0 |
| negative (`tests/negative/run_negative.sh`) | 149 passed, 0 failed |
| UVM (`.github/uvm_test.sh`) | 355 passed, 0 failed, 0 skipped |

The row count grows 4507 -> 4519 across the branch; every added row is a
registration from this increment, and no pre-existing row moved.

### Harness notes worth carrying forward

- Run sweeps as `ulimit -t 45 && perl vvp_reg.pl`; `vvp_reg.pl` does not apply
  the per-process CPU guard itself.
- Do **not** rebuild the compiler while a sweep or census is running — both
  invoke `local-install/bin/iverilog` per job.
- `uvm_test.sh` rebuilds a **shared** `/tmp/uvm_dpi_iv.vpi`, so two concurrent
  invocations from different worktrees contaminate each other.
- The two ivtest harnesses disagree: the JSON/VVP one requires a
  `<name>-vvp-stdout.gold` that the legacy one does not, so a test can pass
  legacy and fail JSON on that alone. CE (negative) golds use only the
  `./`-prefixed path form.
- Do not register new tests while a sweep is running; the resulting numbers
  describe neither tree. One sweep on this branch had to be discarded and
  re-run for exactly this reason.

## Residual ledger

Everything below is **loud today** — a focused diagnostic, never silent
acceptance — and is left unimplemented on purpose.

| Residual | Status | Pinned by |
|---|---|---|
| `foreach` over a PACKED-array parameter (`localparam logic [3:0][1:0] M; foreach (M[i])`) | focused message naming the type; **not** package-related, so `alert_handler_reg_pkg::LpgMap` is not unblocked | test header of `sv_foreach_package_scoped_target.v` |
| package-scoped name as an assignment l-value (`pkg::d = new[3]`, `pkg::q[0] = 9`) | loud rejection | test header |
| method call on an INDEXED package-scoped name (`pkg::m[0].push_back(4)`; unindexed `pkg::q.push_back(4)` works) | loud rejection | test header |
| `64'(string_param)` size cast | correctly rejected under 6.24.1; slang concurs | `sv_param_string_cast_fail` |
| multi-dimensional unsized parameter declaration | loud error, deliberately not inferred | `sv_param_unsized_multidim_fail` |
| string method on an element of a string array parameter (`LEAFS[1].len()`) | rejected — the element select is read as a character select; comparing elements works | commit message of `b526e51d4` |
| interface instance name still classified as a type identifier | reference fixed, classification not | commit message of `c29a073df` |
| `rstmgr_base_vseq.sv:272/278` slowest-varying-dimension rule | next link in the rstmgr chain | census rows |
| `rstmgr_cnsty_chk` `tb.sv:477` — package-scoped class type in a block-automatic declaration whose variable shadows the type name | reached only after this increment | census rows |

No clause-matrix row is promoted to complete by this increment.
