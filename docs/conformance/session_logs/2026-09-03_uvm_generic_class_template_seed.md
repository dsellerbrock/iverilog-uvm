# The parameterized-class template seed, and what it was hiding (2026-09-03)

## Scope and status

Two compiler changes on the UVM frontier, both rooted in one clause, plus two
scoping corrections that cancel planned work. No clause is claimed complete and
**no OpenTitan core changes status**.

Working tree `iverilog-uvm-foreach-scoped-after252-arm64-20260903`, branch
`agent/opentitan-foreach-scoped-after252-arm64-20260903`, on top of the five
commits already covered by
[`2026-09-03_opentitan_rstmgr_chain_and_parameter_typing.md`](2026-09-03_opentitan_rstmgr_chain_and_parameter_typing.md).

| Commit | Clause | Mechanism |
|---|---|---|
| `2675c1dc9` | 8.25 | a static call through an unbound type parameter in a generic body is not a use site |
| `6dd3c9f1f` | 8.21 with 8.25 | `new` on a virtual class outside a parameterized class is an error again |

## The normative point

IEEE 1800-2017 and 1800-2023 carry **identical** language in 8.25:

> "A generic class is not a type; only a concrete specialization represents a type."

and

> "The default specialization of a parameterized class is the specialization of
> the parameterized class with an empty parameter override list. For a
> parameterized class C, the default specialization is C#()."

Two consequences drive both commits. The body of an unspecialized parameterized
class is a **template seed** -- elaborated with the declared default type
parameters, never executed, not a type. But `C#()` written explicitly **is** a
specialization like any other, and must be checked in full.

The principle was already in the tree twice, in
`specialize_bare_class_at_concrete_use()` (`elab_scope.cc`: *"a template seed,
not a concrete use site"*) and in `resolve_scoped_class_type_name_task_()` on
the statement path. Only the scoped-static-call expression form lacked it.

## What the frontier actually was

The after252 triage scoped this as *"UVM factory / multi-level parameterized-class
specialization ... feature-sized work"*, needing
`uvm_registry_common #(this_type, uvm_registry_component_creator, T, Tname)`
where a type parameter binds to `this_type` of an enclosing specialization.

**That feature was not missing.** A reducer ladder isolated it:

| Level | Shape | Before |
|---|---|---|
| 1 | `C::make()` through a plain type parameter | PASS |
| 2 | type parameter bound to `this_type`, one level | PASS |
| 3 | full mutually recursive cycle, `type Treg = int` | **rejected** |
| 4 | **identical** cycle, `type Treg = defreg` (a class with the method) | PASS 4/4 |

Levels 3 and 4 differ only in a default type parameter. The mutually recursive
cycle -- `registry#(T,N)` naming `common#(this_type,T,N)`, which calls back into
that same enclosing specialization -- always worked, roundtrip included. What
failed was elaborating the **generic body** as a use site: under
`uvm_registry_common`'s own `int` defaults,
`Tcreator::create_by_type(Tregistry::get(), ...)` reads as
`int::create_by_type(int::get(), ...)`.

Two gates were required before acting, and both were run:

1. **slang 11.0.448 accepts level 3** under `--std 1800-2017` and `1800-2023`,
   0 errors 0 warnings. Corroboration only -- the clause was read first.
2. **The real debt lines carry the signature.** `xbar_dbg`'s stub sites are
   `uvm_registry.svh:596/599/632`, all inside
   `class uvm_registry_common #(type Tregistry=int, type Tcreator=int, ...)`
   declared at line 563.

## The near-miss that shaped the guard

The first draft suppressed the report whenever the type parameter bound to no
class. It silently accepted:

```systemverilog
class common #(type Treg = int);
  static function int poke(); return Treg::tag(); endfunction
endclass
initial $display("%0d", common#()::poke());
```

`int` is not a `netclass_t`, so the "binds to no class" test passed -- but 8.25
makes `common#()` a real specialization and `int::tag()` a real error, which
slang rejects. That draft would have converted an unsupported construct into
**silent success**, the one outcome this campaign forbids.

The shipped guard therefore requires **three** conditions, and the first is the
one that draft lacked:

1. the call is lexically inside the body of an **unspecialized** parameterized class;
2. the leading name resolves to a `type_parameter_t`;
3. that parameter binds to no class type in scope.

Pinned permanently by `sv_class_type_param_default_spec_fail`, whose gold went
from two errors to one: the generic-body report is gone, the specialization's
is kept. **That difference is the fix, recorded as a gold.**

## The 8.21 hole underneath, and a regression worth keeping

Applying the same clause to `new` on a virtual class exposed a second defect.
The gate there was "anywhere inside any class scope", so this compiled and ran
with a null handle:

```systemverilog
virtual class base; endclass
class holder;
  base b;
  function void mk(); b = new(); endfunction   // accepted, b = null
endclass
```

No type parameter appears, so nothing could have been mistyped. slang rejects
it under both editions. Icarus simply was not applying 8.21.

**The first attempt to fix it broke all 355 UVM tests**, and the reducers could
not have caught it. Splitting on generic-body-vs-specialization and
hard-erroring in every specialization passed every focused reducer, then failed
at

```
uvm_random_stimulus.svh:114: error: Can not create object of virtual class `uvm_transaction'.
```

The type-parameter **collapse** the old comment warned about -- a concrete `T`
resolved to its virtual base -- is not confined to generic bodies. It fires
inside real specializations too. Only the UVM corpus showed that.

The shipped gate is three cases:

| Context | Behavior | Why |
|---|---|---|
| no parameterized class in scope | **hard error** | nothing could have collapsed; 8.21 in full |
| unspecialized parameterized body | silent null | 8.25 template seed; never executed |
| real specialization | **loud warning** + null | our own collapse defect, must stay visible |

The third case is deliberately still loud and still a degrade. A specialization
reaching it means **we** mistyped a concrete `T`, not that the program is wrong.
Silencing it would hide the defect that needs fixing next. The message now says
"collapsed" rather than "may have collapsed", because in that branch it did.

## Measured

Census: 530 jobs, unmodified OpenTitan `7a3ad34b6`, FuseSoC 2.4.5 / Edalize 0.6.3.

`2675c1dc9`, evidence `opentitan-templateseed-after252-arm64-20260903`:

- **Zero status changes.** PASS 192, FAIL 88, DEBT 36, UPSTREAM_INVALID 35,
  RUNTIME_FAIL 15, DEPENDENCY_ONLY 157, SETUP_FAIL 6, RUNTIME_TIMEOUT 1 --
  identical to the preceding census.
- Compiler engine `1198b71911…` -> `5d386870c0…`, so this is a genuinely
  different compiler and not a replayed run.
- The effect is in the debt, which no status count shows:

| Measure | before | after |
|---|---:|---:|
| `did not resolve` lines, corpus-wide | 553 | **316** |
| `xbar_dbg` (uvm) total debt lines | 27 | 24 |
| `xbar_dbg` `did not resolve` lines | 7 | 4 |

237 lines removed, all reported from bodies the design never instantiates. The
triage's estimate of 93 counted a single status bucket; the measured figure is
larger.

`6dd3c9f1f`, evidence `opentitan-virtualnew-after252-arm64-20260903`:

- **Zero status changes** again -- every count identical (PASS 192, FAIL 88,
  DEBT 36, UPSTREAM_INVALID 35, RUNTIME_FAIL 15, DEPENDENCY_ONLY 157,
  SETUP_FAIL 6, RUNTIME_TIMEOUT 1). Compiler engine `5d386870c0…` ->
  `aac0c4d5b7…`.
- The prediction under test was that this commit removes only the
  **generic-body** degrades. Measured corpus-wide:

| Measure | before both | after `2675c1dc9` | after `6dd3c9f1f` |
|---|---:|---:|---:|
| `did not resolve` lines | 553 | **316** | 316 |
| `degraded to null` lines | 474 | 474 | **79** |
| `xbar_dbg` (uvm) debt lines | 27 | 24 | **19** |

632 false-positive debt lines removed across the two commits. The generic-body
share of the degrades was larger than predicted -- 83%, not the ~6 lines per
core the triage implied.

**All 79 remaining degrades come from a single site**, `uvm_random_stimulus.svh:114`,
one per compile job. The `uvm_registry` and `uvm_pool` degrades are gone; they
were template seeds. That single site is the type-parameter collapse defect
itself, deliberately left loud. This is the corpus-wide check of the "reported
precisely" claim, not a generalization from one test.

Suites at `6dd3c9f1f`: legacy ivtest Total=4526 Passed=4521 Failed=0 NI=2 EF=3;
JSON/VVP Ran 1415 Failed 0; negative 149 passed 0 failed; UVM 355 passed 0
failed 0 skipped.

**Caliptra re-run, not asserted.** `6dd3c9f1f` makes 8.21 stricter inside class
methods, which is exactly the shape that could break a passing core, so the
standing "52 PASS, ICARUS_GAP 0" baseline was re-measured rather than inherited:

    PASS 52, ICARUS_GAP 0, SLANG_ONLY_DIFFERENCE 0, TIMEOUT 0,
    DEBT 1, SOURCE_ORDER_DEBT 1, 105 jobs, caliptra-rtl bd316141 unmodified

Evidence `caliptra-virtualnew-after252-arm64-20260903`. The driver hardcodes a
retired worktree path, so a copy was repathed rather than the original edited.

## Two scoping corrections that cancel planned work

### The rstmgr 7.6 frontier is UPSTREAM_INVALID, not an Icarus defect

The handoff said to "fix so Icarus accepts"
`rstmgr_base_vseq.sv:278`. **Icarus is right.**

```systemverilog
virtual task rstmgr_csr_wr_unpack(input uvm_object ptr[], ...);   // dynamic array of the BASE
rstmgr_csr_wr_unpack(.ptr(ral.sw_rst_ctrl_n), ...);               // fixed array of a DERIVED
```

7.6 permits fixed <-> dynamic assignment only when element types are
**equivalent**; base and derived class handles are assignment-compatible but not
equivalent.

| Case | Icarus | slang 2017 | slang 2023 |
|---|---|---|---|
| equivalent elements | compiles **and runs** (`take_base n=3 tag0=10`) | 0 errors | 0 errors |
| derived -> base | error, cites 7.6 | error, same line | error, same line |

Relaxing 7.6 to make these compile would be the forbidden "modify Icarus to
accommodate OpenTitan" move, and would silently accept a type error both the
LRM and slang reject.

### Item C (UpstreamDefect fingerprints) is not actionable yet

Measured against each FAIL record's `hard_errors` list: **zero** cores have all
hard errors matching a single upstream-invalid family.

| Family | all errors match | partial |
|---|---:|---:|
| 7.6 fixed -> dynamic | 0 | 4 (11 of 17 each) |
| bare `syntax error` | 2 (ibex_icache, 1 error each) | 47 |

The matcher requires every hard diagnostic to match so that any new failure mode
still surfaces as FAIL -- deliberate and correct. These cores sit in FAIL because
they carry **other** unresolved diagnostics. Fingerprinting them now would hide
real Icarus defects. Secondary blocker: the three syntax-error families emit a
bare `syntax error` plus cascading noise, so a fingerprint would match a generic
string; giving them focused diagnostics is a prerequisite and is itself compiler
work.

## rstmgr decomposed

Its 17 hard errors are **four** mechanisms, derived from the census record
rather than from the log's narrative:

| Count | Mechanism | Verdict |
|---:|---|---|
| 11 | IEEE 7.6 fixed -> dynamic of a base class | UPSTREAM_INVALID |
| 2 | `Variable index into array parameter 'LIST_OF_LEAFS' requires integral elements` | Icarus frontier |
| 2 | `'size' method needs a constant string at elaboration` | Icarus frontier |
| 2 | `Unable to bind variable dut.*_sva_if in tb` | untriaged |

Even with both Icarus halves fixed, the 11 remaining 7.6 errors would make the
row **UPSTREAM_INVALID, not PASS**. No PASS may be claimed for rstmgr.

## Next frontier, traced not guessed

Runtime access to a string array parameter, reduced and slang-confirmed
(slang: 0 errors, 0 warnings, both editions):

```systemverilog
package p; parameter string LEAFS[] = {"u_daon_lc","u_daon_por","u_daon_por_io"}; endpackage
LEAFS.size()                    // sorry: `size' needs a constant string at elaboration
automatic string s = LEAFS[i];  // sorry: Variable index into array parameter
```

Icarus reads the string **array** parameter as a **string**: `.size()` dispatches
as a string method rather than the array-size method. The variable-index half is
structural -- `elab_expr.cc:23129` flattens an array parameter's elements into
one wide vector and bit-selects it, which requires integral, equal-width
elements, so a string element cannot be represented at all. This needs a real
runtime select over string constants, not a guard: **feature-sized**, and larger
than the "smaller, already reduced" heading it was filed under.

**Reducer caution recorded because it nearly produced a wrong verdict:** the
first draft failed under slang too, but for a defect in the *test* --
`string path = {...}` in a procedural block needs `automatic` (slang: "cannot
refer to automatic variable 'i' from static initializer"). The real code sits in
`task body()`, where declarations are automatic by default. Without chasing that
down, this would have been filed as UPSTREAM_INVALID.

## Residual ledger

| Residual | Status | Pinned by |
|---|---|---|
| type-parameter collapse to a virtual base in a real specialization | loud warning, **not fixed**; now reported precisely instead of blended with two unrelated cases | one line in every UVM compile (`uvm_transaction`) |
| generic body whose type-parameter default is a class lacking the method | still reports, so two errors where slang gives one; erring toward reporting cannot create silent success | `sv_class_type_param_bound_missing_fail` |
| `LEAFS.size()` / `LEAFS[i]` on a string array parameter | loud `sorry:` | next frontier above |
| an ORDINARY class nested inside a parameterized one | takes the loud degrade rather than the hard error, because the scope walk stops at the first parameterized ancestor. Conservative on purpose: it keeps UVM working and cannot create silent success | scope walk in `elab_expr.cc` |
| `dut.*_sva_if` bind failures | untriaged | rstmgr census rows |

No clause-matrix row is promoted to complete.
