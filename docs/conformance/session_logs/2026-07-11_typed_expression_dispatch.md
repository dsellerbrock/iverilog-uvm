# Session log — 2026-07-11 — Typed-expression method dispatch (M1)

## Baseline

- **Date**: 2026-07-11
- **Branch**: `claude/ieee1800-systemverilog-uvm-tqk5qy`
- **Starting commit**: `a014332` (Merge pull request #38 from dsellerbrock/development)
- **UVM version**: Accellera uvm-core 2020.3.1 (submodule commit `78c0654`, unmodified,
  pinned at official_release_3_1 merge)
- **Baseline build command**:
  ```
  autoconf && ./configure --enable-libveriuser --prefix=$PWD/install && make -j4 && make install
  ```
  (build deps: flex, gperf, libz3-dev installed via apt)
- **Baseline test command**: `PATH=$PWD/install/bin:$PATH bash .github/uvm_test.sh`
- **Baseline result**: **98 passed, 0 failed, 0 skipped** (matches Phase 65 record in
  `docs/claude/uvm_gap_plan.md`)

## Selected gap

Manifesto milestone **M1 — Typed expression and runtime class descriptors**:
method dispatch on arbitrary typed expressions. Covers audit gaps:

- **G31** — enum method on function-call result (`c.next().name()`)
- **G32** — method chaining on class-handle returns (`c.with_v(1).with_v(2).v`)
- **G22** — `uvm_factory::get().create_object_by_name(...)` (singleton-returning
  static accessor + method call)

## Applicable IEEE clauses (IEEE 1800-2017)

- **8.23 Class scope resolution operator ::** and **8.10 Object methods** — a method
  may be invoked on any expression whose type is a class handle; the left-hand side
  of `.` is an object expression, not restricted to a hierarchical name (8.10:
  "Methods are invoked using the same syntax used to access structure members …
  object.method()", where `object` is any class-object-valued expression).
- **6.19.5 Enumerated type methods** — `next()`, `prev()`, `name()`, `first()`,
  `last()`, `num()` apply to any expression of enumeration type, including the
  result of a function call or another enum method (their results are of the
  enum type, so method application composes).
- **8.25 Parameterized classes** — `C#(T)::get()` denotes a static method of the
  specialization; its return value keeps the specialized class type.
- **13.4.1 Return values and void functions** — method-call statements
  (`f().method();`) including void methods.

## Reproducers (probed against baseline build)

| Probe | Form | Baseline result |
|---|---|---|
| probe1 | `make_c(42).get_v()` | **FAILS** — `error: No function named 'get_v'` |
| probe2 | `make_c(7).v` | PASSES (PEMemberAccess path already works) |
| probe3 | `c.with_v(42).with_v(100).v` | **FAILS** — `No function named 'with_v'` |
| probe4 | `next_color(c).name()`, `c.next().name()` | **FAILS** — `No function named 'name'` |
| probe5 | `S::get().get_v()`, `S::get().v`, `P#(byte)::get().size_of()` | **FAILS** for method calls; property access `S::get().v` works |
| probe6 | statement `make_c().bump();` | **FAILS** — syntax error (grammar gap) |

## Root cause (confirmed)

1. **Parser discards the receiver**: `parse.y` rules
   `expr_primary '.' IDENTIFIER argument_list_parens` (and the TYPE_IDENTIFIER
   variant) execute `delete $1;` — the receiver expression is thrown away and a
   bare `PECallFunction(method_name)` is created. Elaboration then reports
   "No function named …". This is a silent-miscompile pattern (manifesto
   principle 4).
2. **No expression-keyed dispatch entry point**: `PECallFunction::elaborate_expr_method_`
   dispatches only from `symbol_search_results` (a resolved *net* + path); there is
   no path that dispatches a method against an arbitrary elaborated `NetExpr` +
   `ivl_type_t`. The dispatch tail (darray/queue/enum/class/string method lowering)
   is reusable but was not factored out.
3. **Statement grammar gap**: `subroutine_call` has no alternative for
   `<call> '.' IDENTIFIER (args)` shapes, so `f().method();`,
   `uvm_factory::get().set_type_override_by_name(...);` are syntax errors.
4. **Return types are already preserved**: `NetEUFunc` inherits
   `NetExpr(res->net_type())` from the return signal, including class
   specializations and enum identity — so no netlist-side change is needed for
   type preservation; the fix is parser + elaboration dispatch.

## Work completed this session

### Implementation (checkpoint 2)

**Parser (`parse.y`)**
- `expr_primary '.' IDENTIFIER/TYPE_IDENTIFIER argument_list_parens` no longer
  deletes the receiver expression. PEIdent receivers are spliced into a
  hierarchical path (preserving existing name-resolution semantics, including
  packages and implicit `this`); all other receiver expressions are carried on
  a receiver-based `PECallFunction`.
- New `subroutine_call` alternatives for statement-context single-hop chains:
  `f(args).m(args);`, `Class::get(args).m(args);`,
  `Class#(p)::get(args).m(args);`. Grammar impact: +2 shift/reduce conflicts
  (448 → 450), resolved by shift which selects the new rules; reduce/reduce
  unchanged (1060); no new useless rules (the three reported ones pre-exist).

**AST (`PExpr.h/cc`, `Statement.h/cc`, `pform_dump.cc`)**
- `PECallFunction` and `PCallTask` gained an optional `receiver_` expression
  and constructors `(PExpr*receiver, perm_string method, parms)`.

**Elaboration (`elab_expr.cc`, `elaborate.cc`)**
- The method-dispatch tail of `PECallFunction::elaborate_expr_method_`
  (darray/queue/enum/class/string dispatch keyed on an elaborated receiver
  expression + exact type) was extracted into shared
  `elaborate_method_dispatch_`. No behavior change for the existing path.
- New `PECallFunction::elaborate_receiver_method_`: elaborates the receiver
  with typed elaboration, reads its exact `net_type()` (class specialization
  and enum identity are already preserved by `NetEUFunc(res->net_type())`),
  and dispatches. Reports a controlled diagnostic when no dispatch applies.
- `PECallFunction::test_width` handles receiver calls (mirrors
  `PEMemberAccess::test_width`).
- New `PCallTask::elaborate_receiver_method_`: class-typed receivers only
  (clean `sorry` otherwise); tasks and void methods via
  `elaborate_build_call_` with the receiver as `this`; non-void methods
  re-expressed as PAssign-to-nothing (IEEE 13.4.1 discard).

**vvp runtime (`vvp/vthread.cc`) — pre-existing latent bug fixed**
- `vthread_get_rd_context_item_scoped` preferred the wt-head frame whenever
  its scope matched. After `do_join`'s pop-push, the returned child frame
  sits at rd-head and is no longer in the wt chain; for nested calls of the
  SAME function (builder chains `c.f(...).f(...)`, `f(g(f(x)))` with f==g)
  the caller's pre-`%alloc`'d same-scope frame at wt-head shadowed the
  returned frame, so the caller read a null/zero result. Fix: prefer rd-head
  when it is live for the scope and absent from the wt chain. The `%alloc`
  staging window keeps wt-head priority (caller frame still chained in wt).
  **Confirmed pre-existing**: pristine baseline build (a014332) fails
  `tests/m1_method_chain_builder_test.sv`'s nested-same-method shape via the
  pre-existing property-access path (`c.with_v(c2.with_v(3).v)` → c.v==0).

### Tests added

| Test | Covers |
|---|---|
| `tests/m1_method_on_call_result_test.sv` | `f().method()`, `f().prop`, void stmt `f().m();` |
| `tests/m1_method_chain_builder_test.sv` | builder chains, mixed chains, nested same-method |
| `tests/m1_enum_method_chain_test.sv` | `enum_f().name()`, `c.next().name()`, deep chains |
| `tests/m1_static_accessor_chain_test.sv` | `S::get().m()`, `S::get().prop`, `P#(T)::get().m()`, stmt form |
| `tests/m1_virtual_dispatch_chain_test.sv` | virtual dispatch via call-result receivers (8.20) |
| `tests/m1_uvm_factory_by_name_test.sv` | G22 unmodified-UVM `uvm_factory::get().create_object_by_name` |
| `tests/negative/*.sv` + `run_negative.sh` | unknown method / unknown enum method on call results → controlled diagnostics |

### Required-probe outcomes (manifesto initial-priority list)

| Probe | Outcome |
|---|---|
| UVM factory by-name (`uvm_factory::get().create_object_by_name`) | **PASS** (G22 fixed) — permanent test added |
| Class-valued `uvm_config_db` set/get | **PASS** (G24 now passes; config-db internals traverse accessor chains) — permanent test `m1_uvm_cfgdb_class_test.sv` |
| Process status enum chaining (`process::self().status().name()`) | **Dispatch fixed** — chain compiles and runs; remaining failure is G07 (status state machine returns 0, no enum identity on the built-in `status` property) → M6 scope |
| Builder-style chaining | **PASS** (G32 fixed incl. vvp frame fix) |
| `$cast` base↔derived UVM objects | **PASS** (exercised inside `m1_uvm_factory_by_name_test.sv`) |

### Results

- All 6 new positive tests PASS under the regression recipe.
- Negative suite: 2/2 PASS (specific diagnostics; note: message printed
  twice due to the pre-existing test_width+elaborate double-elaboration
  pattern shared with PEMemberAccess).
- `make check`: PASS.
- Canonical UVM regression: **104 passed, 0 failed, 0 skipped** (98 baseline
  tests + 6 new m1 tests; `m1_uvm_cfgdb_class_test.sv` was added after that
  run started and verified individually — future runs count 105).
- Bundled ivtest, patched vs pristine baseline build (both run this session):
  **byte-identical results** — vvp_reg.pl `Total=3101, Passed=2961,
  Failed=132, Not Implemented=5, Expected Fail=3` in both; vpi_reg
  `85/85` in both; vvp_reg.py `Ran 284, Failed 12` in both; the failure
  name lists diff empty. All 132+12 failures are pre-existing fork issues,
  unrelated to this change.

## Checkpoint 3 — M2: whole unpacked-array assignment (G25) + G23/G24 disposition

### Requirement

IEEE 1800-2017 **7.6 Assignments in unpacked arrays** (and 6.22.2 equivalent
types): an unpacked array may be assigned from an assignment-compatible
unpacked array (same element counts per dimension, equivalent element types),
with left-to-right element correspondence. UVM's `uvm_field_sarray_int` COPY
op is literally `ARG = local_rhs__.ARG;` (macros/uvm_object_defines.svh), so
G25 reduces to this language feature.

### Reproduction (baseline behavior)

- `arr = rhs.arr` (class property = class property): compiled but was a
  **silent no-op** — tgt-vvp degraded the uarray property load/store to
  1-bit `%prop/v 0` / `%store/prop/v 0, 1`.
- `x = y` (word-array signals) and `a.arr = lv` (property = signal):
  hard elaboration error ("the type of the variable ... doesn't match the
  context type", netvector vs netuarray) because word-array signals carry
  unpacked dimensions on the NetNet, not in net_type().

### Root cause

No whole-array assignment lowering existed: vvp has no whole-array store
(arrays are not stack values), and nothing in elaboration expanded the
copy. The netuarray-typed r-value paths either mis-elaborated (property)
or rejected (signal).

### Implementation

`elaborate.cc`: `PAssign::elaborate`'s netuarray l-value branch now lowers
whole one-dimensional static-array assignments into a canonical-index
element copy `NetForLoop` (`make_uarray_copy_loop_`), reusing the existing
word-indexed l-value (`%store/prop/v/i`, array word stores) and r-value
(`%prop/v/i`, array word reads) machinery. Canonical-to-canonical copy
implements the 7.6 left-to-right correspondence for any declared index
directions. Sources handled: word-array signals (pre-checked via
symbol_search before typed r-value elaboration) and class properties
(NetEProperty intercepted after r-value elaboration). Shape or element
incompatibility produces a specific diagnostic
(`uarray_copy_shapes_compatible_`); count mismatch is a hard error per 7.6.

### Tests

- `tests/m2_uarray_assign_test.sv` — sig=sig, prop=prop, local=prop,
  prop=local, copy-not-alias, byte-element arrays.
- `tests/m2_uvm_field_sarray_copy_test.sv` — unmodified-UVM
  `uvm_field_sarray_int` clone round trip (G25).
- `tests/m2_uvm_register_cb_test.sv` — G23 callback flow
  (RESOLVED-BY-PRIOR; regression protection).
- `tests/negative/m2_uarray_size_mismatch.sv` — `int a[4] = b[5]` rejected
  with a specific diagnostic.

### Dispositions

- **G25: FIXED** (sarray_int; dynamic `uvm_field_array_*` shapes to re-probe).
- **G23: RESOLVED-BY-PRIOR** (full register_cb + do_callbacks + add +
  virtual dispatch passes).
- **G66 (NEW)**: $unit class named `comp` used as a specialization parameter
  breaks unrelated uvm_pkg elaboration; reproducer preserved at
  `tests/probes/g66_unit_class_name_collision_uvm.sv`; simple shadowing
  reductions pass. Recorded in the gap audit.

### Known limitations

- Multi-dimensional whole-array copy not expanded (falls back to the old
  paths: loud error for signals; property case unchanged).
- Function-return unpacked arrays and unpacked-dimension subroutine ports
  remain separate pre-existing loud gaps (typedef-return / `sorry`).

### Results

- Focused: m2 positive tests 4/4 PASS (uarray assign, UVM sarray clone,
  UVM register_cb, UVM dynamic field array — the last verified
  individually, added after the suite run started); negative suite 3/3.
- Canonical UVM regression: **108 passed, 0 failed, 0 skipped**.
- Bundled ivtest: **byte-identical to the pristine-baseline results**
  (vvp_reg 2961/3101 pass + same 132 pre-existing failure names,
  vpi_reg 85/85, vvp_reg.py 284 ran/12 pre-existing failures).
- Follow-up noted: `draw_eval_object: unknown expression type 3` warning
  fires on UVM dynamic-array paths (pre-existing tgt-vvp/eval_object.c
  compile-progress fallback — Phase 75 scope).

## Checkpoint 4 — M3: constraint solver semantics (G15/G17/G18/G20 + G11 impl)

### Requirement

IEEE 1800-2017 Chapter 18 constraint blocks: 18.5.6 implication
(`expr -> constraint_set`), 18.5.7 if-else constraints, 18.5.3 set
membership (enum literals in sets), 18.5.2 constraint inheritance
(derived classes inherit base constraints; same-name overrides).

### Root causes (per gap)

- **G15** (implication): `pexpr_to_constraint_ir` had no case for
  PEBLogic 'q' (`->`) so the whole item silently vanished; the
  `A -> { set }` form additionally lost its consequent in parse.y
  (constraint_trigger returned nothing, action `$$ = $1`).
- **G17** (if-else): parse.y dropped the entire constraint set
  (`$$ = nullptr`).
- **G18** (enum inside): enum literal identifiers resolved to neither
  property nor constant, so set ranges silently dropped out of the
  `(inside ...)` IR (leaving it empty ⇒ true ⇒ underconstrained).
- **G20** (inheritance): (a) derived netclass_t never saw base
  constraint IRs; (b) the `x * 2` expression used `mul`, absent from
  both the IR generator switch and the Z3 parser (as were add/sub in
  the parser — generator emitted them but the solver silently treated
  them as `true`).
- **G11**: the implication half is the G15 fix; `solve...before`
  ordering remains parsed-and-ignored (xor-diversity provides the
  distribution; staged-order solving deferred).

### Implementation

- `PExpr.h/cc`: new `PEConstraintIf` pform node (cond + then/else item
  lists) for constraint-set implication and if-else.
- `parse.y`: constraint_set / constraint_expression_list /
  constraint_trigger now build `std::list<PExpr*>`; the if/else,
  `A -> {...}` and foreach rules no longer leak or silently drop
  (foreach still unsupported: items deleted, documented).
  Grammar conflicts unchanged (450 s/r, 1060 r/r).
- `elaborate.cc` (`pexpr_to_constraint_ir`): new ops impl/iff and
  mul/div/mod; PEConstraintIf lowering
  `(impl C then) [and (impl (not C) else)]`; enum-literal resolution
  through the class scope chain (new `scope` parameter); enum-typed
  property widths; a one-shot warning when a constraint item cannot be
  represented (silent weakening is a manifesto-4 violation).
- `netclass.h/cc`: lazy inheritance merge
  (`merge_inherited_constraint_irs_`), deferred until the base chain
  has elaborated; local same-name constraints override (18.5.2).
  Verified property indexes are chain-stable (vvp `.class` dumps show
  base properties keep their slots in derived classes).
- `vvp/vvp_z3.cc`: `impl` (Z3_mk_implies), `iff` (Z3_mk_iff),
  `add/sub/mul/div/mod` bitvector arithmetic with width harmonization.

### Tests

- `tests/m3_constraint_semantics_test.sv`: five constraint families ×
  20 iterations (implication, if-else sets, enum-literal inside,
  inherited constraint + child arithmetic constraint, solve-before with
  implications and distribution sanity check).

### Known limitations (recorded in audit)

- `foreach` iterative constraints (G16) and `arr.size()` constraints
  (G21): rand arrays are not representable in the scalar p:N:W IR —
  needs array-property solver support (next M3 increment).
- `solve...before` ordering semantics; signed comparisons (IR carries
  no sign; bvult/bvule used); state-variable (non-rand) references in
  class constraints still drop (now warned).

### Results

- Focused: `m3_constraint_semantics_test` PASS (5 families × 20 iterations).
- Canonical UVM regression: **110 passed, 0 failed, 0 skipped** (108 prior
  + m3 test + probes dir excluded by the runner glob).
- Bundled ivtest: **byte-identical to the pristine-baseline results**
  (vvp_reg 2961/3101 + same 132 pre-existing failure names, vpi_reg 85/85,
  vvp_reg.py 284/12).
- The one-shot "constraint item not representable" warning fires once
  during uvm_pkg compile (honest surface of a pre-existing dropped item).

Note: PR #66 (M1+M2) was merged into main by the repository owner during
this checkpoint; the topic branch was restarted from the merged main and
the M3 work committed on top (WIP commit `9d64dda`, regression
confirmation in the follow-up docs commit). New PR: #67.

## Checkpoint 5 — M3: array-property constraints (G21 size, G16 foreach)

### Requirement

IEEE 1800-2017 **18.4** (the size of a rand dynamic array is randomized
subject to constraints; elements are randomized) and **18.5.8 / 18.5.8.1**
(iterative foreach constraints; loop variables range over the array
indexes and shadow outer names).

### Root causes

- **G21**: `arr.size()` in constraints had no IR representation (item
  dropped with the honesty warning); no runtime mechanism resized rand
  dynamic arrays after solving.
- **G16**: foreach constraint sets were dropped in parse.y; array
  ELEMENTS had no IR representation; and rand static-array properties
  were never even filled with random bits by %randomize (only word 0
  scalars).
- **Hang found during implementation**: the solver's inside/dist range
  parser read only literal tokens and made NO forward progress on
  unexpected input — an unparseable range hung the simulation. Fixed
  with expression-capable range parsing plus a guaranteed-progress
  guard. (This robustness defect pre-existed; it was unreachable only
  because nothing emitted compound ranges before.)

### Implementation

- `PExpr.h/cc`, `parse.y`: new `PEConstraintForeach` pform node
  (array name, loop vars, item list) replacing the silent drop.
- `elaborate.cc` (IR generator):
  - `arr.size()` → size variable `s:N:T` (T = darray type text for
    write-back construction, derived from the element type).
  - foreach over one-dimensional 0-based static-array rand properties:
    compile-time unroll with a loop-variable environment
    (`loop_env` parameter; loop vars shadow properties per 18.5.8);
    indexed property refs `arr[i]` → element variables `e:N:W:I`.
  - Constant folding for add/sub/mul/div/mod over literal operands so
    unrolled index arithmetic stays `c:V` in range bounds.
- `vvp/class_type.h/cc`: properties retain base type text + array size
  (`property_base_type`, `property_array_size`).
- `vvp/vthread.cc`: %randomize (both plain and with-variants) fills
  every element of static-array rand properties with random bits.
- `vvp/vvp_z3.cc`: `s:`/`e:` variables; pre-check equality includes
  current sizes/elements; xor-diversity objectives for both; hard size
  cap 65536 (implementation limit for under-constrained sizes);
  write-back creates the darray via a type-text factory, fills
  unconstrained elements randomly, then applies solved element values;
  inside/dist ranges accept expressions and always make progress.

### Tests

- `tests/m3_constraint_array_test.sv`: SizeC (`sz inside {[3:5]};
  arr.size() == sz`) and ForeachC (`foreach (arr[i]) arr[i] inside
  {[i*10:i*10+5]}`) × 10 iterations.

### Known limitations

- foreach over DYNAMIC arrays (runtime-sized) not yet expanded (needs
  solve-time template expansion after the size var is fixed).
- Element addressing assumes 0-based one-dimensional declared ranges.
- Element constraints and `arr.size()` for the SAME array in one solve
  are independent (element vars index only compile-time-known slots).

### Results

- Focused: single-shot size/foreach probes, the 10-iteration combined
  probe, and `m3_constraint_array_test` under the regression recipe all
  PASS.
- Canonical UVM regression: **111 passed, 0 failed, 0 skipped**.
- Bundled ivtest: **byte-identical to the pristine-baseline results**
  (vvp_reg 2961/3101 + same 132 pre-existing failure names, vpi_reg
  85/85, vvp_reg.py 284/12).
- WIP marker on `6f7e875` superseded by this regression confirmation.

## Checkpoint 6 — M3: signed constraint comparisons and negative bounds

### Requirement

IEEE 1800-2017 **11.8.1** (comparisons are signed when both operands are
signed; integer literals are signed) and **11.4.13/18.5.3** (inside with
signed subjects). Constraints on `int` fields with negative bounds are
routine in UVM stimulus.

### Root causes

- Unary minus (`-5`) had no IR conversion (PEUnary handled only `!`), so
  any constraint item containing a negative literal was silently dropped
  (surfaced by the checkpoint-4 honesty warning).
- The IR carried no signedness: all comparisons and inside ranges used
  unsigned BV predicates, making `y < 0` unsatisfiable and negative
  ranges meaningless.

### Implementation

- Generator (`elaborate.cc`): PEUnary `-` folds literals to 64-bit two's
  complement (solver numerals reduce mod 2^W at the use width) and lowers
  non-literal operands to `(sub c:0 x)`; unary `+` passes through.
  Signed property/element types append `:s` to their `p:`/`e:` tokens.
- Solver (`vvp/vvp_z3.cc`): signed-variable tracking; comparisons use
  the bvslt family with sign extension when a signed variable
  participates; `inside`/`dist` ranges use signed predicates and
  sign-extended bounds when the subject is signed.

### Tests

- `tests/m3_constraint_signed_test.sv`: `x inside {[-5:5]}`, `y < 0`,
  `y >= -20` over 20 iterations.

### Results

(recorded when regressions complete)

## Checkpoint history

- Checkpoint 1: manifesto imported to `docs/conformance/`, baseline recorded (this file).
- Checkpoint 2: typed-expression method dispatch implementation + tests + vvp
  returned-frame fix.
- Checkpoint 3: M2 whole unpacked-array assignment (G25) + G23/G24/G66
  dispositions (this section).
