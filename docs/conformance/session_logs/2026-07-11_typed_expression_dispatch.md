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

See CURRENT_WORK.md and commits on branch `claude/ieee1800-systemverilog-uvm-tqk5qy`.

(Updated as checkpoints land — see bottom of file.)

## Checkpoint history

- Checkpoint 1: manifesto imported to `docs/conformance/`, baseline recorded (this file).
