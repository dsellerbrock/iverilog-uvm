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

## Checkpoint history

- Checkpoint 1: manifesto imported to `docs/conformance/`, baseline recorded (this file).
- Checkpoint 2: typed-expression method dispatch implementation + tests + vvp
  returned-frame fix.
- Checkpoint 3: M2 whole unpacked-array assignment (G25) + G23/G24/G66
  dispositions (this section).
