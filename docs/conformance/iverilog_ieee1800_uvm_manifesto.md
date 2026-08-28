# Icarus Verilog IEEE 1800 / UVM Conformance Manifesto

## Purpose

This document is the governing implementation and conformance plan for the `dsellerbrock/iverilog-uvm` fork.

Its goals are:

1. Implement broad, measurable IEEE 1800-2017 and IEEE 1800-2023
   conformance as two first-class selectable language editions.
2. Run the unmodified Accellera UVM reference implementation and make
   representative OpenTitan and Caliptra RTL/DV flows practically usable
   without source patches that hide compiler defects.
3. Target source, run-time, DPI, and VPI interoperability with the commercial
   RTL/DV ecosystem represented by VCS, Questa, and Xcelium wherever their
   behavior agrees with IEEE 1800.
4. Eliminate silent miscompiles and make every support claim evidence-based
   and falsifiable.
5. Build a standards-correct, typed, formal-ready frontend and assertion IR;
   a proof engine is a later program, not a present capability claim.
6. Defer UPF/IEEE 1801 and other adjacent standards until the IEEE 1800
   language, elaboration, simulation, and verification surfaces are
   substantially closed.

This document is the implementation Bible.

Passing UVM, OpenTitan, or Caliptra is valuable application evidence. None is
proof of full IEEE 1800 conformance.

A milestone is not complete because unsupported corners are documented. A milestone is complete only when its defined scope is implemented, tested, and free of known in-scope gaps.

---

## Strict honesty policy

The project must distinguish exactly between:

- **COMPLETE** — all defined milestone scope is implemented and validated.
- **SUBSET COMPLETE** — a named subset is complete, while broader scope remains open.
- **PARTIAL** — useful implementation exists, but meaningful in-scope functionality remains missing.
- **DIAGNOSED** — unsupported behavior is rejected explicitly and safely.
- **OPEN** — implementation work remains.
- **PROVISIONAL** — evidence is strong but an adversarial truth audit is still required.

Never use `CLOSED` or `FULL` merely because UVM passes, a representative test passes, unsupported forms emit `sorry`, a recorded-corners ledger exists, no silent miscompile is currently known, or the parser accepts the construct.

A loud diagnostic is better than a silent miscompile, but it is still unsupported functionality.

---

## Normative sources

Use sources in this order:

1. The selected edition of IEEE 1800: 2017 in `-g2017` mode and 2023 in
   `-g2023` mode, including published errata applicable to that edition.
2. Reduced positive, negative, and interaction reproducers tied to the
   governing clause and subclause.
3. The unmodified Accellera UVM reference implementation and unchanged
   OpenTitan and Caliptra sources as application conformance witnesses.
4. VCS, Questa, and Xcelium behavior as practical commercial interoperability
   evidence after the IEEE text; disagreement must be recorded rather than
   resolved by majority vote.
5. Slang as a parser/elaboration differential and independent diagnostic
   cross-check.
6. Existing regression evidence and dated application matrices.

Verilator is useful diagnostic evidence, but it is not the language, run-time,
or Annex-H ABI oracle for this project. Never invent clause semantics from
memory or infer standards completeness from one simulator.

For each feature, identify the relevant clause and subclause; record syntax, semantics, typing, scheduling, VPI/DPI implications; and add positive, negative, and interaction tests where applicable.

---

## Core engineering principles

### 1. Fix the simulator, not UVM

When UVM exposes a failure:

1. preserve the original UVM failure;
2. reduce it to pure SystemVerilog;
3. identify the real compiler/runtime defect;
4. implement the general language behavior;
5. preserve the reduced test;
6. rerun unmodified UVM.

Do not add identifier-based UVM special cases.

### 2. Eliminate silent miscompiles first

Priority order:

1. silent wrong behavior;
2. compiler crashes and assertions;
3. runtime corruption;
4. scheduler races;
5. known UVM semantic blockers;
6. loud unsupported features;
7. rare syntax completeness.

Unsupported behavior must be implemented correctly, rejected explicitly, or intentionally lowered with documented standards-justified semantics.

### 3. Parsing is not support

A feature is supported only when all relevant layers work: preprocessing, parsing, name resolution, typing, elaboration, lowering, code generation, runtime, scheduling, VPI/DPI where applicable, and durable tests.

### 4. Prefer architecture over patch accumulation

Repeated failures involving type reconstruction, parameterized classes, aggregate lvalues, method dispatch, event scheduling, assertion execution, or container access must trigger architectural fixes rather than local workarounds.

### 5. Preserve working behavior through characterization tests

Do not rewrite large subsystems blindly. Characterize, test, migrate incrementally, and remove legacy paths only when equivalent behavior exists.

---

## Architectural programs

### Semantic type and IR remediation

The long-term goal is a consistent semantic type representation across name resolution, elaboration, and lowering.

It must preserve exact type, signedness, packed width, unpacked dimensions, two-state/four-state identity, class specialization, enum identity, lvalue/rvalue category, aggregate layout, constant-expression status, and source location.

Required work:

- inventory AST, type, expression, netlist, and elaboration node families;
- identify where type information is lost;
- remove duplicate downstream type reconstruction;
- define typed expression and typed lvalue interfaces;
- define ownership/lifetime rules;
- preserve specialization through variables, properties, locals, formals, returns, and containers;
- make unsupported semantic shapes explicit.

The 2026-08-27 typed-string audit is a concrete checkpoint for this program:
the destination string type now reaches concatenation elaboration, width probes
retain string-method and scoped-function return types, constant folding keeps
string identity, and VVP performs the selected integral-to-string conversion
instead of reconstructing intent from vector bits. Operator legality is checked
where the concatenation is formed, including beneath a conditional or whole
string cast. Nested run-time literal replication keeps string type through
direct targets, whole string casts, and comparisons, rejects integral targets,
and gives zero/nonzero repeats the same once-only operand evaluation. String
methods on data objects and constant parameters carry their exact result
types, enforce arity before lowering, accept a nested-concatenation receiver,
and reject a selected byte as a string-method receiver. Review hardening also
removes the arbitrary repeat cutoff from new typed VVP images, preserves the
legacy unsuffixed opcode for old-image compatibility, preserves multiplier
signedness into the runtime index, diagnoses invalid runtime counts, and keeps
empty/nonprinting/backslash/quote constant-parameter data as semantic bytes.
Constant parameter receivers accept runtime method arguments, comparisons fold
symmetrically, and repetition cannot overwrite a caller-owned VVP index word.
Generic parameterized-class bodies retain parse-form declared-type provenance:
a direct formal/local/property tied to an unresolved type parameter defers the
concat legality decision, while every concrete specialization is checked.
The permanent positive covers string formal/property bindings and the paired
negative retains the integer-binding error.
The legal 1,048,576-byte repeat, error paths, and textual bytecode compatibility
contract are permanent regressions.
Direct `string[index]` concatenation and the literal-only `br_gh800` spelling
remain narrow, documented compatibility extensions rather than general
integral acceptance or IEEE claims. Final validation passes 23/23 focused
legacy, 24/24 focused JSON/VVP, 2,083/2,083 full legacy, 1,161 full JSON/VVP
entries with 0 failures (1,144 executed/pass plus 17 NI), 136/136 negatives,
103/103 VPI, 6/6 textual VVP compatibility, and 354/354 canonical real-DPI
UVM with 0 failures or skips.
Bounded residuals are recorded instead of hidden: fixed-size unpacked-array
string-element method value propagation, argument-type enforcement such as
`s.compare(65)`, reverse mixed comparison, and class-scoped no-parentheses
constant-call legality. Earlier same-branch authentic OpenTitan
Darjeeling/Earlgrey replays, before final generic-class deferral hardening, move
their former internal typed-expression counts from 10/18 to 0/0, but both tops
still fail later; the final narrow change has not been replayed across those
tops, so this evidence does not promote either clause to complete.

Do not attempt an all-at-once rewrite.

### Scheduler remediation

Maintain an inventory mapping every scheduling path to runtime API, queue, IEEE region, and permanent test.

Cover Active, Inactive, NBA, Observed, Reactive, Re-Inactive, Re-NBA, Postponed, program scheduling, assertion sampling/evaluation, clocking sampling/driving, named events, nonblocking event triggers, VPI callbacks, DPI task suspension/resumption, end-of-step cleanup, and finalization.

Do not claim scheduler completion until region ownership is documented and race-sensitive litmus tests cover all major paths.

### Aggregate and container model

Unify behavior for static arrays, dynamic arrays, queues, associative arrays, packed/unpacked structs and unions, nested aggregates, and strings where appropriate.

Shared operations should cover indexing, slicing, iteration, resizing, copying, comparison, sorting, reduction, locator methods, assignment compatibility, aggregate layout, VPI, and DPI.

### Runtime class identity

Runtime class objects should preserve concrete class type, base type, specialization identity, property descriptors, virtual method identity, cast relationships, factory-visible type names, and VPI-visible metadata.

---

# Milestone scope and historical truth status

The canonical live status and current focus are in
[`ROADMAP.md`](ROADMAP.md); dated evidence and exact invocations are in
[`CURRENT_WORK.md`](CURRENT_WORK.md) and the session logs. Counts embedded in
this manifesto describe the named checkpoint and must not override newer
evidence.

## M0 — Reproducible baseline

**Status: COMPLETE**

Maintain clean builds, canonical regressions, UVM, negative tests, VPI, cross-platform CI, and baseline comparison procedures.

## M1A — Typed receiver expressions and chained dispatch

**Status: COMPLETE**

## M1B — Specialization and aggregate typing fidelity

**Status: PARTIAL**

- [x] Fix member access on type-parameter-typed output/ref formals.
      *(Verified resolved 2026-07-21 — see the P1 entry; pinned by
      `sv_typeparam_formal_member`.)*
- [~] Audit specialization through variables, properties, locals, arrays,
      returns, and formals. *(Audited 2026-07-21: specialization is
      preserved through locals, properties, fixed/queue/assoc arrays of
      specialized handles, output/ref formals, function returns, nested
      parameterization, parameterized inheritance + virtual dispatch, and
      per-specialization statics — all correct. The audit uncovered and
      fixed a compiler crash unrelated to specialization: a method call on
      a constant-indexed element of a static unpacked array of class
      handles (`arr[0].method()`) fed a folded-constant index to the
      variable-index normalize path, aborting ivl on a
      `canonical_expr` assertion (`elab_expr.cc`; test
      `sv_array_handle_const_index_method`). Two deeper defects remain
      OPEN, see below.)*
- [~] Reprobe specialization inside nested aggregates. *(2026-07-21:
      defect (a) RESOLVED, (b) OPEN. (a) The struct-member-of-array-element
      symptom generalized to: member access on an element of a static
      unpacked array or a plain dynamic array of an UNPACKED struct is not
      correctly lowered — writes drop, reads return garbage (queues,
      associative arrays, packed structs and scalar unpacked structs all
      work, as they store each element as an object or a flat vector). Full
      support is a large storage/codegen effort disproportionate to the
      (rare, non-UVM) usage, so per the honesty policy the silent
      miscompile is now a loud `sorry` at both the l-value (`elab_lval.cc`)
      and r-value (`elab_expr.cc check_for_struct_members`) sites, gated on
      the container being `netuarray_t` / plain `netdarray_t` (not
      `netqueue_t`). CE test `sv_ustruct_array_member_ce`. A sibling of
      STATIC-array member access RESOLVED 2026-07-22: a static unpacked
      array of an object-backed unpacked struct now default-constructs its
      elements lazily. The `.array/obj` declaration carries the element class
      type (`tgt-vvp/vvp_scope.c`), `compile_object_array` resolves it into
      `__vpiArray::element_defn_` (`vvp/array.cc`, grammar in `vvp/parse.y`),
      and `get_word_obj` constructs and caches a default element object on
      first access — so `arr[i].field = x` on a never-whole-assigned element
      addresses a real object and a read of an unassigned element returns the
      struct default (0). The member-write codegen loads the indexed element
      with `%load/obja` (`tgt-vvp/stmt_assign.c`). Class-handle arrays emit no
      element type and correctly keep null elements. The `elab_lval.cc`
      `sorry` is narrowed to the DYNAMIC-array case only (darray object
      elements are not yet default-constructed). Positive test
      `sv_ustruct_array_member`; CE test `sv_ustruct_array_member_ce`
      repurposed to the still-unsupported darray case. Known separate
      limitation: `%p` on a whole struct-object array element still aborts in
      the decimal formatter (an M4B `%p`-aggregate display gap, pre-existing
      and orthogonal to member access — member reads/writes are unaffected).
      A sibling of
      defect (a), the WHOLE-element write `arr[i] = <expr>` (no member
      select), was first found to crash the same way and was briefly gated
      with a `sorry` — then ROOT-CAUSED and FIXED (2026-07-21o). The bug was
      pure codegen: `show_stmt_assign_object` (`tgt-vvp/stmt_assign.c`)
      diverted ANY assignment-pattern r-value to `draw_array_pattern`, which
      is the WHOLE-ARRAY distributor — it ignores the l-value word index and
      read the struct's fields `'{a,b}` as successive array *elements*
      (`arr[0]=a; arr[1]=b`), calling `draw_eval_object` on a plain integer
      and emitting `%null`. The fix only calls `draw_array_pattern` when the
      l-value has NO word index (a true whole-array assign); a per-element
      pattern (`ivl_lval_idx != 0`) now falls through to the same
      build-the-object + `%store/obja` path the scalar `s = '{...}` and the
      element-copy/struct-var cases already use. So `arr[i] = '{...}`, a
      struct-variable assign, and an element-to-element copy all work now,
      and member READS of an assigned element read back correctly. Positive
      test `sv_ustruct_array_element` (the earlier CE test was removed). Note
      the sibling still open: a member WRITE `arr[i].field = x` to an element
      that was never whole-assigned drops silently because static object-array
      elements are not auto-constructed (each element starts null); that path
      stays gated by the member-access `sorry` above until element
      auto-construction lands. While reducing
      (a) a second real crash surfaced and was fixed: the TASK-method path
      (`arr[0].method();` as a statement — a void method with a constant
      index) hit the same `canonical_expr` assertion as the earlier
      function-expression fix; `elaborate_root_indexed_method_target_expr_`
      now uses the constant normalize path too (test
      `sv_array_handle_const_index_method` extended to cover it).
      (b) `$cast` between two different specializations of the same
      parameterized class (Box#(byte) vs Box#(shortint)) wrongly succeeded —
      RESOLVED 2026-07-21. The run-time cast check
      (`vpi/sys_sv_class.cc class_cast_compatible_`) keyed types on the bare
      class name (`vpiName`), which is `"Box"` for every specialization, so
      distinct specializations aliased. Root cause: the compiler emits a
      separate `.class` record for the same specialization in each
      referencing scope, each with a different `scope_path`, so neither the
      class-type pointer nor `vpiFullName` is invariant per specialization —
      but the dispatch prefix (`m._ivl_0` vs `m._ivl_1`) is. The fix exposes
      the dispatch prefix through `vpiDefName` (`vvp/class_type.cc`) and keys
      the cast on it, so matching specializations still cast and mismatched
      ones are rejected; ordinary inheritance up/down casts are unchanged.
      Test `sv_cast_param_class_specialization`.)*
- [ ] Remove remaining compile-progress fallbacks caused by lost specialization.
- [ ] Add adversarial parameterized-UVM regressions.

## M1C — Canonical semantic IR migration

**Status: OPEN**

- [ ] Inventory legacy semantic representations.
- [ ] Define canonical type descriptor boundaries.
- [ ] Define typed lvalue interfaces.
- [ ] Document semantic ownership/lifetime rules.
- [ ] Identify compiler paths bypassing canonical typing.
- [ ] Migrate high-risk expression and aggregate families incrementally.

## M2 — UVM factory, config, callbacks, and field automation

**Status: COMPLETE FOR DEFINED MILESTONE SCOPE**

Future failures belong to the underlying language/runtime subsystem unless the UVM mechanism itself is incorrect.

## M3A — Common class-based UVM constraint solving

**Status: COMPLETE FOR COMMON UVM FLOWS**

## M3B — Full clause-18 randomization

**Status: PARTIAL**

- [x] Implement `std::randomize(var...)`. *(Done 2026-07-21: the scope
      (non-class) expression form now lowers to `$ivl_std_randomize`, whose
      VPI implementation writes an unconstrained random value into each
      integral variable argument and returns 1 — previously it returned
      success without assigning anything (silent no-randomization). The
      statement form with a with-clause keeps its range/enum/retry
      constraint lowering; a with-clause in expression context randomizes
      the variables but does not enforce the constraints (loud warning).
      Test `sv_std_randomize_scope`.)*
- [x] Implement `randcase`. *(Done 2026-07-21: `PRandCase` lowers to
      procedural code — each weight evaluated once, summed, one
      `$urandom_range(sum-1)` draw, cumulative-threshold branch select; a
      zero total weight executes no branch. Was a `sorry`. Test
      `sv_randcase`.)*
- [ ] Implement `randsequence`.
- [x] Implement `unique {}` constraints. *(Done 2026-07-21: `unique {vars,
      arr, ...}` (IEEE 1800-2017 18.5.5) parses (`PEUnique`) and the
      constraint-IR emitter expands un-indexed rand array operands to their
      elements and emits pairwise `(ne ...)` terms to the Z3 backend.
      Handles scalar-variable lists and whole-array operands. Was a syntax
      error. Test `sv_constraint_unique`.)*
- [ ] Implement `disable soft`.
- [ ] Reaudit `rand_mode` and `constraint_mode` combinations.
- [ ] Add seed-stability and failed-randomization state tests.

## M4A — Core container runtime and known silent value-loss fixes

**Status: COMPLETE FOR CURRENT CORE**

## M4B — Aggregate/container completion

**Status: PARTIAL**

- [x] Implement the evidenced IEEE 1800-2017/2023 7.4/7.9.11/10.9.1
      associative-array assignment-pattern subset. Explicit constant string,
      integral, and enum keys plus at most one non-entry fallback `default`
      construct a fresh typed map; right-hand-side expressions execute once in
      lexical order before one destination replacement. Defaults remain
      outside map membership. Whole maps and recorded container/struct values
      copy independently, while class handles retain handle identity. Paired
      reducers cover declaration, procedural, typed-pattern, argument, return,
      and conditional contexts; nonconstant and X/Z keys, duplicate
      key/default, and incompatible key/value diagnostics; and the exact
      OpenTitan enum-to-string, enum-to-queue, and nested-map shapes. Direct
      signal-backed fixed prefixes ending in integral, string, or real-valued
      maps cover whole-map, entry, and map-method paths behind nonzero,
      descending, and multidimensional ranges. Explicit/default real reads,
      direct stores, sibling isolation, and constant/variable outer selectors
      are value-pinned. Every fixed dimension is bounds-checked before
      flattening, so a multidimensional OOB selector cannot alias a valid
      sibling: whole-map and entry stores remain no-ops after once-only RHS
      evaluation, and entry reads or map methods cannot touch the sibling.
      Packed bit/part/member and other deeper/partial entry tails,
      property/member and struct-nested receivers, fixed queue/darray leaves,
      fixed-prefix maps with class-handle/container/struct values,
      associative-array-typed parameters, broader receiver/value contexts,
      and exhaustive clause closure remain loud or open.
- [x] Support wildcard associative-array index declarations where required. *(Done 2026-07-21: `type name[*];` (IEEE 1800-2017 7.8.1) now parses. The lexer folds `[*` into one token (`K_LBSTAR`, shared with the SVA consecutive-repetition opener) whose comment wrongly assumed `[*` had no other use, so `variable_dimension` gained a `K_LBSTAR ']'` rule that builds an associative array with a placeholder integral index type (assoc arrays share one queue-compat runtime form regardless of declared index type). Integral keys, exists/delete/size/foreach all work. Test `sv_assoc_wildcard_index`.)*
- [x] Correct `%p` formatting for integral aggregates. *(Done 2026-07-21:
      rewrote the `%p` handler as a recursive assignment-pattern formatter
      (`format_p_value` in `vpi/sys_display.c`). Queues, dynamic arrays,
      fixed unpacked arrays and associative arrays now print
      `'{v0, v1, ...}` (assoc as `'{key:val, ...}`) with integral elements
      in decimal, reals via `%g`, strings quoted; empty containers print
      `'{}`. The old handler asked every element for `vpiStringVal`, so
      integral elements came out as raw ASCII bytes (99 → `'c'`) or empty
      (unimplemented `get_word(string)` for queue/darray elements). Also
      fixed assoc key rendering (vector keys were the raw byte encoding —
      now decimal, `vvp_assoc.h peek_entry`) and queue element type
      detection for real/string queues (`vpi_darray.cc get_word_value`).
      Test `sv_display_p_aggregates`. Element signedness fixed 2026-07-21:
      signed integral dynamic-array/queue/assoc elements now render in
      signed decimal (`-1`, not `4294967295`). The declared element
      signedness is carried on the `.var/darray` / `.var/queue` declaration
      (a `'+'` marker emitted by codegen, parsed via a `signed_opt`
      grammar flag, stored on `__vpiDarrayVar`, and used by
      `get_word_value`) — the VPI-handle route, which is one declaration
      site rather than the 10+ lazy runtime construction sites. Test
      `sv_display_p_signed`. Two cosmetic refinements remain (deferred as
      disproportionate to a display-only payoff): a multi-dimensional
      unpacked array prints flat (`'{1,2,3,4,5,6}`) rather than nested
      because iverilog flattens unpacked dims and VPI exposes no per-dim
      geometry for the element iterator; and a packed struct prints as one
      decimal rather than a `'{member:val}` pattern.)*
- [x] Fix nested packed-struct array literal compiler crash. *(Done
      2026-07-21: module-scope nested literals work on all probed shapes;
      the remaining defect was a class-property whole-array pattern store
      that silently zero-filled — fixed via `draw_prop_array_pattern`
      (`%store/prop/v/i` per element). Test `sv_class_prop_array_pattern`.
      Sibling real/string class-property array storage is a separate,
      deeper defect: issue #100.)*
- [x] Fix unpacked-array typedef return plus assignment-pattern compiler
      crash. *(2026-07-21: IMPLEMENTED (issue #99). A function may return an
      unpacked array; the return signal is emitted as a real array
      (`elab_sig.cc` splits the unpacked dims; `vvp_scope.c` no longer
      skips it), the body stores the result elements into it, and the call
      site invokes the function like a void function then copies the words
      out into the target array/slice (`draw_ufunc_uarray`). Automatic and
      static functions; int/real/string elements; multi-dimensional
      returns; slice targets. Shape mismatches are a clean elaboration
      error. Tests `sv_uarray_func_return` (positive) and
      `sv_uarray_func_return_fail` (CE, now a shape mismatch). Note:
      unpacked arrays in automatic scopes use static storage in vvp, so a
      recursive function returning an array through concurrent activations
      shares that storage — a pre-existing vvp property, not introduced
      here.)*
- [x] Fix class-property unpacked arrays of `real`/`string` (were a silent
      miscompile — every element stored to one slot). *(Done 2026-07-21:
      array-capable real/string cobject property storage + indexed opcodes
      `%store/prop/{r,str}/i` / `%prop/{r,str}/i`. Test
      `sv_class_prop_real_string_array`. Issue #100.)*
- [ ] Continue adversarial nested-container testing.
- [ ] Reaudit nested property read/write/method shapes after future typing changes.

## M5 — Interfaces and modports

**Status: PARTIAL — AUDITED 2026-07-21**

- [x] Audit full modport member access restrictions. *(2026-07-21:
      direction enforcement (writing an input member through a modport)
      was already implemented and errors cleanly. Member VISIBILITY was
      NOT enforced — writing a member the modport does not list compiled
      silently; now a clean error (`elab_lval.cc`, alongside the direction
      check; import/export-listed subroutines stay accessible). CE test
      `sv_modport_visibility_fail`. READ-side visibility now enforced too
      (2026-07-21n): reading an interface member not listed in the modport
      through the expression path (`x = p.hidden;`) used to compile
      silently and then ICE in synthesis ("Failed to synthesize
      expression"); it is now the same clean error, added in
      `PEIdent::elaborate_expr_class_member_` (`elab_expr.cc`), visibility
      only — reading a listed input OR output member stays legal. CE test
      `sv_modport_read_visibility_fail`.)*
- [x] Revalidate output/inout imported task copy-back. *(2026-07-21:
      works — single-attached-instance binding with an explicit warning
      that dynamic multi-instance copy-back is not implemented; verified
      accumulating state + output arg across two calls.)*
- [x] Remove or justify hard dispatch limits such as `VIF_DISPATCH_MAX`.
      *(2026-07-21: REMOVED. The fixed 64-instance cap silently dropped
      instances beyond it, so virtual calls through handles bound to
      instances 65+ quietly did nothing. Collection is now dynamically
      sized. Test `sv_vif_dispatch_many` (72 instances). The same
      investigation found and fixed a broader silent miscompile: the
      receiver index of `arr[i].method()` on a STATIC array of class
      handles or virtual interfaces was dropped in BOTH the task-method
      and function-method elaboration paths — every call dispatched
      through element 0. Test `sv_class_array_method_dispatch`.)*
- [x] Verify per-specialization interface typing. *(2026-07-21: verified —
      two specializations of a parameterized interface keep distinct
      widths/parameter values, both data and methods.)*
- [~] Stress parameterized virtual-interface arrays. *(2026-07-21:
      constant-index vif-array binding (`vp[2] = pins[2]`) and
      element-indexed method dispatch work; binding with a RUNTIME index
      (`vp[i] = pins[i]` in a loop) fails at elaboration — "Scope index
      expression is not constant" — because interface-instance selection
      is a scope operation. Needs a runtime instance-dispatch table.)*
- [~] Audit bare module-scope virtual-interface declarations. *(2026-07-21:
      a `virtual pin_if vp;` declaration at compilation-unit ($unit) scope
      is a parse error. Module-scope and class-property declarations
      work.)*
- [x] Fix change-sensitivity on interface-member (object-property) reads.
      *(Found 2026-07-21n, FIXED 2026-07-21p. An edge/`@*` sensitivity whose
      source is an interface-member read did not fire when that member
      changed: interfaces are modeled as class objects, so the member read
      lowers to a property access whose value-change event was built on the
      object HANDLE (which never changes after binding), not on the
      underlying interface signal. `assign p.b = p.a;` and `always @(p.a)
      p.b = p.a;` (p an interface port) left `b` stuck at its T0 value.
      The fix reuses the existing virtual-interface edge machinery
      (`%wait/vif/anyedge`, which dynamically resolves a vif object's
      per-signal edge functor at run time) that previously handled only the
      NESTED `obj.vif_handle.sig` UVM pattern. A DIRECT interface-port member
      `p.sig` — where the port handle IS the vif object, with no intermediate
      vif property — is now detected in the explicit `@()` event path
      (`elaborate.cc`) and encoded as a direct vif probe (sentinel
      `vif_N == UINT_MAX`); codegen (`tgt-vvp/vvp_process.c`) emits
      `%load/obj <port>; %wait/vif/<edge> <M>` with no `%prop/obj` extraction.
      The vif-member continuous-assign lowering
      (`elaborate_vif_member_assign_`) now sensitizes the re-apply process on
      `@(<rhs>)` instead of `@*`, so a single interface-member r-value routes
      through the direct probe. A real-net r-value (`assign inf.req =
      rnd[0];`, `ivltests/sv_interface.v`) is unaffected — `@(rnd[0])`
      sensitizes on the real net exactly as `@*` did. Test
      `sv_interface_member_sensitivity` (continuous-assign + explicit-`@`,
      both edges). Extended 2026-07-22 to a SINGLE interface member wrapped
      in operators (`assign p.out = ~p.in;`, `p.a[i]`, `sel ? p.a : ...`):
      `collect_iface_member_props_` recurses the event expression, and when
      exactly one interface member and no ordinary-net read is present a
      direct vif probe is built in the general (post-`synthesize`) event path
      too — previously such expressions failed to synthesize (class property)
      and the event was dropped to a T0-only trigger. Finally extended
      2026-07-22 to MULTI-member and MIXED r-values (`p.a & p.c`,
      `p.a & module_net`): `%wait/vif` waits on a single signal per event, so
      the vif-member continuous-assign lowering now FANS OUT into one
      `always @(read) (lhs = rhs)` process per distinct signal read in the
      r-value (`collect_pform_reads_` + a `symbol_search`/dedup filter),
      each re-applying the whole assignment when its own source changes — an
      interface member routes through the vif probe, an ordinary net through a
      normal probe. This exposed a second bug: `NetEvent::find_similar_event`
      merged the per-member events because their probe nets (the shared vif
      HANDLE) matched, collapsing both to one signal's `vif_M`; a
      `vif_probes_match_` guard now blocks merging events whose vif signal
      identity (edge kind / `vif_N` / `vif_M` / `vif_pre_N`) differs. All
      common bare / operator-wrapped / multi-member / mixed forms and a
      posedge control are covered by `sv_interface_member_sensitivity`.
      The later M5-2 audit added cast-transparent collection and full-vector,
      current-value-seeded VIF any-change probes. Runtime selector dependencies
      and the remaining wrapper/exact compound-event gaps are tracked in the
      ROADMAP rather than being called complete here.)*

## M6A — Core scheduler/runtime repairs

**Status: SUBSET COMPLETE**

## M6B — Scheduler conformance

**Status: PARTIAL**

Completed: construct-level region inventory, event-region litmus tests, program completion behavior, `$exit`, nonblocking event trigger fixes, and callf trampoline architecture.

Remaining:

- [x] Implement per-instance class event storage and triggering. *(Done
      2026-07-21: per-object `vvp_named_event_dyn` storage + `%evt/obj` /
      `%wait/obj` opcodes; `->obj.ev` / `@(obj.ev)` are per-instance for
      obj.ev, a.b.ev, arr[i].ev, and assoc `m_events[k].ev`. Also fixed a
      pre-existing fork double-reap crash exposed by the change.)*
- [x] Implement correct `process.status()` transitions. *(2026-07-21:
      SUSPENDED reported for suspended processes; FINISHED / KILLED /
      WAITING(event/join) / RUNNING already worked. Final refinement done
      2026-07-21: a process parked on a `#delay` reported RUNNING, not
      WAITING — the delay reschedules the thread on the timing wheel
      (`is_scheduled` stays set) with no distinguishing flag. New
      `i_am_delaying` vthread flag (set in `of_DELAY`/`of_DELAYX`, cleared
      when the thread resumes in `vthread_run`) drives the WAITING
      transition. All six states verified in
      `sv_process_status_transitions`.)*
- [x] Implement `process::suspend()` and `process::resume()`. *(Done
      2026-07-21: `%process/suspend` / `%process/resume` opcodes; a
      suspended thread is skipped by vthread_run with the pending wake
      recorded, so resume() continues exactly where it left off — including
      an event that fired while suspended (deferred, not lost).
      Self-suspend parks immediately. Test `sv_process_suspend_resume`.)*
- [x] Implement the recorded post-NBA `cbNBASynch` callback region.
- [x] Define scheduling and disable cleanup for the recorded time-consuming
      DPI import/export subset.
- [x] Implement Preponed/Observed/Reactive assertion lifecycle scheduling for
      the recorded operand and action subset.
- [ ] Keep the scheduler inventory synchronized with every scheduler change.

## M7 — Accellera UVM qualification

**Status: COMPLETE FOR THE CURRENT LOCAL HARNESS CHECKPOINT — 354/354, 0 failed, 0 skipped**

The RAL front door and major UVM subsystems execute correctly, and the
bundled UVM regression suite passes with zero skips.

The current dynamic-cross and final-hardening tree passes the complete
canonical real-DPI harness 354/354.

- [x] Fix per-instance class events so UVM objection events do not cross-wake between instances. *(Done 2026-07-21; the shared-event cross-wake is gone.)*
- [x] Fix the `m7_objection_stress` run-phase completion blocker. *(Done
      2026-07-21. The real cause was NOT objection count propagation (that
      is correct) but a runtime defect: a reference to `this` from a nested
      detached (join_none) fork body resolved to null for later iterations,
      so the phase hopper's per-phase `drop_objection` saw a null `this`,
      `get_objection()` returned null, and the drop silently no-op'd on the
      null handle. Fixed in `vvp/vthread.cc`
      (`vthread_get_rd_context_item_scoped` single-live-activation fallback).
      Issue #103. Tests `sv_this_nested_detached_fork` +
      `m7_objection_stress_test` (un-skipped, now PASS).)*
- [x] Re-enable and verify full extract/check/report/final phase execution.
      *(m7 now ends at t=80 with all post-run phases executing.)*
- [x] Run full RAL, sequence, objection, TLM, callback, and phasing stress
      suites. *(The last merged canonical UVM checkpoint passes 354/354 with real
      DPI, 0 failed, and 0 skipped; preserve exact tool provenance in the
      dated evidence.)*

Note: the harness suite is green, but per the truth rules this is
"COMPLETE for the probed suite," not a proof of standards-complete UVM.

## M8 — Clocking blocks and program scheduling

**Status: PARTIAL**

Sampled inputs, common output drives, `##N`, default/global clocking, and the
recorded virtual-interface paths work. Run-time-selected drives, indexed class
receivers, whole unpacked clocking outputs, and the remaining clause-14 audit
surface prevent a completion claim.

- [ ] Reprobe edge-qualified skew forms.
- [ ] Reprobe real/string/aggregate clockvars.
- [ ] Stress parameterized virtual-interface clocking.
- [ ] Stress clocking + program + assertion + VPI ordering.
- [ ] Verify every clause-14 subfeature has a disposition.

## M9A — Core SVA token-pipeline engine

**Status: COMPLETE**

## M9B — Fixed-shape sequence algebra

**Status: SUBSTANTIAL / PARTIAL**

## M9C — Temporal property operators

**Status: PARTIAL**

## M9D — Advanced SVA semantics and automaton engine

**Status: SUBSTANTIAL / PARTIAL**

The automaton/NFA engine is now the default and covers the recorded implication,
window, repetition, local-variable, `first_match`, sequence-composition,
strength, endpoint-method, and common multiclock subsets. `expect`, checker
constructs, and assertion lifecycle callbacks are implemented in their
recorded scopes. The legacy linear engine remains available only as a
diagnostic differential. Remaining loud boundaries include cross-clock
overlapping `|->`, `disable iff` across a two-or-more-boundary chain, and the
separately recorded branch-flow and deferred-immediate gaps. This is not a
complete clause-16 or formal-verification claim.

## M10A — Core DPI imports and packed vectors

**Status: COMPLETE FOR CURRENT SUBSET**

## M10B/M10C — DPI completion

**Status: SUBSTANTIAL / PARTIAL**

Imports, exports/C-to-SystemVerilog calls, context and scope selection,
multidimensional fixed/open arrays in the recorded ABI subset, scalar and
packed types, time-consuming tasks, re-entry, and the clause-35.9 disable
protocol have executable evidence. VCS, Questa, and Xcelium remain the
commercial Annex-H interoperability targets. Imported shortreal arrays, legal
fixed-size unpacked export formals, and the exhaustive signature/runtime and
cross-platform matrix remain open, so clause 35 is not complete.

## M11A — Class-embedded functional coverage core

**Status: SUBSET COMPLETE**

The fixed declaration/sampling core is stable in the recorded subset. This
label does not include every clause-19 bin, option, constructor, reporting,
type-coverage, VPI, or cross interaction.

## M11B — Full clause-19 declaration and sampling surface

**Status: PARTIAL**

- [x] Implement the recorded package/module/interface/class covergroup and
      sampling-event subsets.
- [x] Implement the recorded `with function sample`, options, durable text
      report, transition, cross, and adversarial fixed-bin subsets.
- [~] Implement typed per-instance constructor-dependent integral bin ranges.
      The bounded construction-time grammar preserves width, signedness,
      X/Z exclusion, coverpoint-domain conversion, descending-range emptiness,
      the ordered source-occurrence stream used by fixed arrays, and
      OpenTitan's TL-agent expression. Open arrays use the distinct-value rule
      in the next item rather than occurrence identity.
- [x] Apply the audited bounded array-bin identity and distribution rules.
      Integral open arrays (`bins b[]`) coalesce duplicate/overlapping ranges into one
      value-named bin per distinct resolved value. Fixed arrays (`bins b[N]`)
      preserve the `M` ordered matching occurrences, use
      `B = max(floor(M/N), 1)`, assign `B` occurrences to each bin before the
      last while values remain, place every remainder occurrence in the final
      nonempty bin, and remove ignore/illegal values only after distribution
      without redistribution.
      Paired legacy and JSON/VVP gates pass 20/20 across `-g2017` and
      `-g2023` for this and the typed-constructor subset.
- [ ] Preserve constructor port directions, including full `ref`, `output`, and
      `inout` semantics, across covergroup construction and sampling.
- [ ] Implement broader endpoint expressions and context-sized fill literals.
- [x] Integrate dynamic families into automatic crosses and the evidenced
      named `binsof`/`intersect` conjunctions. The topology is frozen
      per covergroup object after constructor capture, and fixed, transition,
      and dynamic logical source bins participate in one routed product. The
      bounded focus passes 20/20 in both harnesses; the unchanged OpenTitan
      matrix advances seven targets from FAIL to DEBT and removes the former
      dynamic-cross-drop diagnostic from all 20 affected targets.
- [ ] Implement construction-time dynamic `with` filters and the remaining
      cross selection grammar: `with`, `matches`, set expressions, and
      `CrossQueueType`.
- [ ] Subtract dynamic ignore/illegal values from denominators and integrate
      dynamic families into type coverage.
- [x] Enforce the audited cross routing model in the bounded fixed/dynamic
      forms: form the Cartesian product of every source-bin identity matched
      by a sample;
      count overlapping named normal bins independently but at most once per
      named bin per sample; apply `illegal` over `ignore` over normal
      precedence independently of declaration order; and leave unrelated
      coverpoint/cross counts intact when an illegal cross bin matches.
- [ ] Extend illegal named-cross routing to transition source terms; the
      current per-instance plan rejects that combination explicitly.
- [ ] Complete report/VPI and normative naming detail, type-coverage union
      semantics, broader signed static range/intersect normalization, empty
      trailing fixed-array-bin identity/naming, arbitrary coverpoint
      expressions, and products beyond the explicit 65,536-bin topology cap.
- [ ] Implement all remaining option/type-option semantics. In particular,
      1800-2017 retains uncovered automatic cross bins, while 1800-2023
      `option.cross_retain_auto_bins` defaults to 1. A covergroup-level value
      supplies the default for its crosses, and a cross-local value overrides
      it; coverpoint and every `type_option` placement are errors. A constant
      zero removes automatic bins when any explicit normal, ignore, or illegal
      cross record is present, including an empty selection. Constant values,
      scope errors, and the 2017 edition rejection are implemented. The focused
      reducer pins normal/no-explicit cases, inherited fixed/dynamic defaults,
      local disable/enable overrides, and empty ignore/illegal declarations.
      Procedural-write and repeated-assignment cases remain incompletely
      evidenced. Constructor/per-instance option expressions remain open even
      though 19.7 requires evaluation at construction.
- [ ] Complete the remaining IEEE 1800-2023 real/tolerance coverage surface.

The current local associative-pattern focus passes 54/54 in each harness;
canonical legacy ivtest passes 4,127 with zero unexpected failures (2 NI and
3 expected fail, 4,132 total); JSON/VVP passes 1,017/1,017; negatives pass
136/136; VPI passes 103/103; and canonical real-DPI UVM passes 354/354. Both
parser conflict profiles match the exact `origin/main` parent. The post-audit
OpenTitan compile matrix is 8 DEBT / 50 FAIL / 3 SETUP_FAIL / 0 PASS,
unchanged in classification from the preceding checkpoint, with zero
timeouts/resource-limit signals and zero former associative-pattern
syntax/refusal diagnostics. The affected targets advance to independent
frontiers; this is not a clean application or runtime pass. Native ARM
`regtool.py` regenerates the UART register RTL byte-for-byte identically. The
post-audit Caliptra static census is Icarus 53/105 in each
assertions/no-assertions/synthesis lane versus Slang 54/105, with 52 PASS, 1
DEBT, 51 SHARED_SOURCE_OR_CONFIG, 1 SOURCE_ORDER_DEBT, and 0 ICARUS_GAP. Its
sole Slang advantage is known `csrng_raw_wrap` source-order debt; this is not
full Caliptra DV runtime.

## M12A — Core SystemVerilog VPI object model

**Status: SUBSTANTIAL**

## M12B/M12C — VPI completion

**Status: COMPLETE FOR THE RECORDED OBJECT-MODEL SUBSET** — all nine listed
items are done. The current local canonical UVM checkpoint is 354/354. Use
`CURRENT_WORK.md` for the live VPI count and exact build provenance.

- [x] Implement assertion start/step/disable lifecycle callbacks.
      *(Start/Success/Failure from the automaton checkers,
      Disable/Enable/Reset from the global control tasks, and
      StepSuccess/StepFailure from the slot advance. Step reports are
      per-tick — they cover every attempt that stepped that tick — so
      the step matched-expression list and state pair are zeroed
      rather than guessed. The legacy engine delivers all but the
      step pair.)*
- [x] Populate meaningful `s_vpi_attempt_info`.
      *(attemptStartTime recovers a completing attempt's real launch
      tick from a start-time ring for fixed-latency assertions —
      always for Success, and for Failure where every reported
      failure ran the full latency (implications). Plain-sequence
      failures, variable-latency, cyclic and legacy/multiclock
      checkers report the completion tick. failExpr stays 0: there is
      no SVA sub-expression handle model.)*
- [x] Complete bit-select force/release.
      *(vpi_put_value force/release on a single bit-select handle,
      plus cbForce/cbRelease registration on bit-select handles.)*
- [x] Complete associative-array element writes.
- [x] Complete nested class-member traversal.
- [x] Expose complete modport direction/access metadata.
- [x] Complete covergroup drill-down handles.
- [x] Define and test VPI object lifetime/free behavior.
- [x] Expose live runtime-container class properties and element callbacks.
      *(Queue, dynamic-array and associative-array properties report their
      declared/live kind and size, support member/index iteration and typed
      element access, and keep saved member handles live across owner
      replacement and growth. `cbValueChange` on direct and class-property
      elements fires for SV and VPI writes with per-element filtering when
      notifications share a class root. Whole-container property writes
      remain a loud boundary.)*

## M13A — Implemented long-tail core

**Status: SUBSET COMPLETE**

Includes substantial support for module/type bind plus a bounded structured,
owner-scoped instance-target subset, let, specify paths, common timing checks,
rare net/strength constructs, and preprocessing corner cases.

## M13B — Remaining long-tail support

**Status: PARTIAL**

- [x] Implement structured absolute, explicit `$root`, and
      module/generate-relative bind paths, including constant-selected
      one-dimensional generate and module-instance-array targets. A final
      instance array requires selection.
- [x] Resolve same-named conditional alternatives per active owner even when
      their concrete target types or scalar/array shapes differ.
- [x] Activate a contained directive only for elaborated module/generate
      occurrences, evaluate genvar/parameter-dependent selects per owner, and
      reach a source-order-independent fixed point for deferred owners and
      targets.
- [x] Implement declaration-scoped bind target-instance lists, including
      selected relative entries and explicit-root entries.
- [x] Enforce the target namespace: same bound-instance names are legal on
      disjoint targets, while overlapping applications and existing-name
      collisions are errors; bind-under-bind is rejected in direct and
      deferred source orders.
- [x] Enforce module/interface target legality, including legal checker
      instantiation into an interface and loud checker/program/illegal
      module-or-primitive cases. IEEE 23.11 permits only interface/checker
      instantiations into an interface target; the internal M13 fixture was
      corrected from module to interface, which is a fixture correction rather
      than a compiler compatibility regression.
- [x] Re-resolve pending binds when `-y` loads a target definition, a
      definition traversed by the target path, or a source that contributes a
      new compilation-unit bind. A live contained owner joins that library bind
      to the same activation closure, while inactive/excluded owners do not
      load or diagnose their dependency. A UDP bound type loaded only from
      `-y` retains the Syntax 23-9 rejection.
- [x] Document the automatic-root boundary: roots account for a
      library-supplied compilation-unit bind found during initial bind
      processing, but are not retroactively recomputed when a live contained
      bind discovers it after root selection; use explicit `-s` for that case.
- [x] Pin the direct nested conditional-generate/generate-for collector with
      paired bind cases plus a plain non-bind smoke.
- [x] Pass the paired bind-focused legacy and JSON/VVP gates, 110/110 each,
      with the parser conflict state unchanged at 535 shift/reduce and 1119
      reduce/reduce.
- [x] Pass full legacy 2063/2063, full JSON/VVP 1141/1141, negatives 136/136,
      VPI 103/103, and the real-DPI UVM umbrella 354/354 with zero
      failures/skips for the final branch state.
- [ ] Extend the existing one-dimensional model to multidimensional
      module-instance arrays; complete clause-23 closure remains an M14B audit.
- [ ] Implement actual `config` semantics and library mapping.
- [ ] Implement `trireg` charge semantics.
- [x] Implement `$nochange`.
- [x] Implement `$timeskew`.
- [x] Implement `$fullskew`.
- [x] Implement timing-check edge descriptor lists.
- [x] Implement timestamp/timecheck conditions.
- [ ] Implement `pulsestyle`.
- [ ] Implement `showcancelled`.

## M14A — Initial IEEE 1800-2017 clause disposition

**Status: COMPLETE**

This means the matrix exists and every top-level clause has a disposition. It does not mean the language is fully conformant.

## M14B — Exhaustive subclause conformance campaign

**Status: OPEN**

- [ ] Correct stale `FULL` labels where in-clause features remain unsupported.
- [ ] Re-evaluate every `FULL` row containing a documented corner.
- [ ] Downgrade clauses 19, 31, 35, and 36 until known missing features are implemented.
- [ ] Add subclause-level evidence.
- [ ] Link matrix rows directly to permanent tests.
- [ ] Repeat silent-miscompile hunting with adversarial and generated tests.
- [ ] Maintain a zero-known-silent-gap policy.

## M15 — IEEE 1800-2023 first-class conformance campaign

**Status: ACTIVE / PARTIAL**

`-g2023` is a first-class selected edition, not postponed delta work. Every
changed or newly added 2023 rule must receive an explicit disposition and
paired tests where the editions agree or intentionally differ. Work proceeds
alongside 2017 closure under the same silent-miscompile-first priority rule;
neither edition may borrow an unsupported feature claim from the other.

---

# Highest-priority correctness backlog

## P0 — Per-instance class events

**Status: IMPLEMENTED (2026-07-21).** Non-static class `event` properties
now have per-instance runtime storage; the shared-event cross-wake is gone.

- [x] Store event identity per runtime object instance.
- [x] Add dynamic class-property event wait operations.
- [x] Add dynamic class-property event trigger operations (blocking + NB).
- [ ] Verify event assignment/alias semantics. *(Not implemented; UVM does not use it.)*
- [x] Verify multiple waiters.
- [x] Re-run UVM objection and phase-hopper stress tests. *(The event
      cross-wake and R27 detached-fork staging defect are closed; the last
      current local canonical checkpoint passes 354/354.)*

Known follow-up: `obj.ev.triggered` still lowers through the shared-event
path (the `%evtest/obj` opcode exists but isn't wired into expression
elaboration yet).

## P0 — `$unit` class timescale semantics

**Status: FIXED (2026-07-21).** `$time`/`$realtime` in a `$unit`-scope class
method now scale to the active `` `timescale `` (they used to walk out to
`$unit` = 1 s and give 0 for a stored `$time`). Fix: `sys_time_scope()` in
`vpi/sys_time.c` stops the scope walk before crossing into a package/`$unit`.

- [x] Apply active timescale/timeunit semantics to `$unit` class declarations.
- [x] Verify `$time`.
- [x] Verify `$realtime`.
- [x] Verify delays inside class methods.
- [x] Verify nested calls and package interaction. *(module / `$unit` / package
      classes all covered; ivtest `sv_unit_class_timescale`.)*

## P1 — Remaining type-parameter formal member access

- [x] Fix member access on output/ref formals typed by type parameters.
      *(Verified RESOLVED 2026-07-21: the original "Variable t does not
      have a field named ..." defect (m7 stress findings 2026-07-18) no
      longer reproduces on any probed shape — it was fixed by the
      intervening M1B typing and virtual-output copy-back work. Probed:
      output-T and ref-T deref in parameterized methods; T inherited from
      a specialized base; deref after a nested parameterized call; virtual
      dispatch through a parameterized base handle with subclass-member
      deref; nested t.sub.inner deref in output tasks and ref functions.)*
- [x] Add pure-language and UVM-shaped tests. *(Test
      `sv_typeparam_formal_member` pins all six shapes; UVM-shaped
      coverage via `m1b_typeparam_member_call_test` and
      `m1b_virtual_output_copyback_test` in the UVM suite.)*

## P1 — Known compiler crashes

- [x] Fix nested literal into array of packed structs. *(2026-07-21:
      module-scope works; class-property whole-array pattern store no
      longer zero-fills. Test `sv_class_prop_array_pattern`.)*
- [x] Fix function return of unpacked-array typedef with assignment
      pattern. *(2026-07-21: fully implemented — see the M4B entry (issue
      #99). Positive test `sv_uarray_func_return`; the CE test now pins the
      shape-mismatch diagnostic.)*
- [~] Search for adjacent assertion/abort paths and add negative hardening
      tests. *(Ongoing: added CE hardening test for the uarray-return
      abort; more assert/abort sweeps pending.)*

---

# Conformance matrix truth rules

A clause may be marked `FULL` only if all in-scope subfeatures are implemented, no known in-clause unsupported feature remains, no known compiler crash remains, no known silent miscompile remains, positive and negative tests exist, and interaction behavior has been tested where applicable.

If a clause has known unsupported functionality, use `PARTIAL` or `DIAGNOSED`.

`FULL on probed constructs` is not equivalent to standards-complete.

---

# Definition of done

A feature is complete only when:

1. governing clause identified;
2. syntax implemented;
3. illegal forms diagnosed;
4. names resolve correctly;
5. exact types preserved;
6. elaboration correct;
7. runtime correct;
8. scheduling correct where applicable;
9. VPI defined where applicable;
10. DPI defined where applicable;
11. positive tests pass;
12. negative tests pass;
13. interaction tests pass;
14. UVM regression passes where applicable;
15. broader regression remains baseline-clean;
16. conformance documentation updated;
17. no known in-scope corner remains hidden behind a completion label;
18. both `-g2017` and `-g2023` have an explicit, tested disposition where the
    feature is shared or edition-sensitive;
19. unchanged UVM, OpenTitan, and Caliptra application gates are rerun where
    the feature is on their path, with every remaining failure classified;
20. work is committed and pushed.

---

# Execution order

Unless new evidence changes priorities:

1. Fix newly demonstrated silent miscompiles, crashes, corruption, and
   scheduler/runtime safety defects.
2. Close the current unchanged OpenTitan and Caliptra compiler/runtime
   frontier with general IEEE behavior and permanent reduced tests.
3. Continue the paired IEEE 1800-2017/2023 subclause campaign, keeping edition
   differences explicit and measurable.
4. Finish the remaining M1B/M5/M6 type, interface, and scheduler foundations.
5. Finish the M9 SVA/typed-IR surface needed by RTL DV and a future formal
   engine; do not claim a proof engine before one exists.
6. Finish M10 DPI and M12 VPI commercial-interoperability surfaces, using VCS,
   Questa, and Xcelium as practical cross-checks after the IEEE text.
7. Finish M11 functional coverage, including dynamic `with`/cross/type/report
   semantics exposed by OpenTitan and Caliptra.
8. Finish M13 long-tail support and the M14B exhaustive subclause campaign.
9. Begin UPF/IEEE 1801 only after IEEE 1800 is substantially closed and the
   architecture can represent its power-intent semantics without shortcuts.

Always prioritize newly discovered silent miscompiles or crashes above this order.

---

# Final principle

The goal is not to produce the appearance of completeness.

The goal is measurable conformance.

Every support claim must be tied to a standard clause, real implementation, permanent tests, regression evidence, and honest remaining limitations.

When reality and milestone wording disagree, change the milestone wording.
