# IEEE 1800-2017 Clause Conformance Matrix (paired with 1800-2023)

Governing milestone: **M14B — exhaustive subclause campaign.** The table below
is the retained M14 simulation-led snapshot. It is useful evidence, but it is
**not** a full-compliance certificate. Former `FULL` rows are labeled
`PROVISIONAL (probed subset)` until M14B replaces them with the multidimensional
matrix described below.
IEEE 1800-2017 and IEEE 1800-2023 are both first-class selected editions; this
file is the 2017 baseline, while `../ieee1800_2023_delta.md` records shared and
changed 2023 rules. A result in one edition is never silently promoted to the
other.

Every disposition here is **empirical** — established by compiling and running
representative constructs against the installed simulator, not from
documentation or memory (manifesto principle 1/3). The original audit checked
computed values on representative constructs. It did not exhaust every
subclause or separately prove synthesis, SVA, UVM/DPI, diagnostic and bounded-
termination behavior. OpenTitan has since demonstrated why those dimensions
cannot be inferred from a small simulation probe.

## M14B replacement gate

Each subclause/grammar-production row will have separate evidence cells for:

| Dimension | Required evidence |
|---|---|
| Parse | legal forms accepted; illegal forms rejected at the right boundary |
| Elaborate | names, hierarchy, parameters and overload/specialization choices resolve correctly |
| Contextual type | width, sign, 2/4-state, enum and aggregate identity preserved in every legal context |
| Simulation | computed values and object/container effects match an explicit oracle |
| Scheduling | region, lifetime, race boundary and end-of-simulation traces match the standard |
| Synthesis | legal synthesizable forms lower without process fallback, crash or semantic debt |
| SVA | grammar, attempts, sampling, scheduling, actions and assertion VPI are verified |
| UVM/class runtime | class, constraint, coverage and reusable-library behavior executes, not merely compiles |
| DPI/VPI | ABI, directions, lifetime, concurrency, re-entry and data round trips are verified |
| Diagnostics | unsupported/illegal forms fail loudly and locally; no compile-progress stub or dropped construct |
| Termination | permanent probes and frozen corpora finish within a declared resource bound |
| Differential | pinned Slang and sv-tests results are recorded; disagreements are resolved against the selected IEEE 1800-2017 or IEEE 1800-2023 text |

`FULL` in the replacement matrix means every applicable cell has permanent
positive, negative, semantic and interaction evidence. `UNKNOWN` is not a pass,
and parser acceptance cannot stand in for lowering or runtime behavior. Slang
is used for parsing/elaboration/static-semantics comparison; it is not treated
as a simulator or as the definition of the standard.

Unmodified UVM, OpenTitan, and Caliptra are application evidence gates. VCS,
Questa, and Xcelium are the practical commercial-simulator interoperability
targets after the selected IEEE text; Verilator is diagnostic only. The
frontend, scheduler, SVA, and IR should remain suitable for a later formal
engine, but this matrix claims no proof engine. UPF/IEEE 1801 remains deferred
until the IEEE 1800 language and verification surfaces are substantially
closed.

## Legend

| Code | Meaning |
|------|---------|
| **PROVISIONAL (probed subset)** | The legacy M14 probe passed its sampled simulation constructs; complete subclause, context, diagnostic, and interaction coverage is not established. |
| **SUBSTANTIAL** | Broad executable evidence exists, with material recorded residuals. |
| **PARTIAL** | Core behaviour correct; specific sub-features are recorded corners (listed). |
| **DIAGNOSED** | Not implemented, but rejected with an explicit, loud diagnostic (error/sorry/one-time warning). No silent miscompile. |
| **N/A** | Clause is informative/organizational or not applicable to a simulation tool. |

Manifesto principle 4 forbids **silent** miscompiles: every unsupported
construct must be a loud diagnostic, a correct implementation, or a
deliberately-specified safe lowering. The dated M14 audit found six silent
gaps; those six were closed (four fixed, two converted to loud diagnostics),
but that historical result is not a current zero-silent-gap certificate — see
**§ M14 gap closures** below.

## Matrix

| Clause | Title | Disposition | Evidence / notes |
|--------|-------|-------------|------------------|
| 1 | Overview | N/A | Informative. |
| 2 | Normative references | N/A | Informative. |
| 3 | Design & verification building blocks | PROVISIONAL (probed subset) | modules, programs, interfaces, packages, checkers(diag), primitives, compilation unit ($unit) all parse and elaborate; SystemVerilog package/class-only and empty compilation units elaborate without a module root; see clauses 23–29. |
| 4 | Scheduling semantics | PROVISIONAL (probed subset) | Full stratified queue: Preponed, Active, Inactive, NBA, the post-NBA `cbNBASynch` point, Observed, the Reactive set (Reactive / Re-Inactive / Re-NBA), Pre-Postponed and Postponed, drained in 4.4.2 order with per-event region tags. Concurrent assertions sample Preponed, evaluate in Observed and run their actions in Reactive; program processes and their `#0`/NBA use the reactive set; `$finish` drains the remaining regions of its own slot. Whole-property and constant packed-field class/VIF NBAs use NBA or Re-NBA according to their executing process; field updates merge at event execution rather than applying an Active-region snapshot (M4C-8). Region trace and a reverse-insertion region self-test are built in (`IVL_REGION_TRACE`, `IVL_REGION_SELFTEST`), and a Postponed-region write is diagnosed. Evidence: m6_sched_litmus_test, m6_reactive_region_test, m6b_nba_sync (VPI), sv_nba_property_reactive, sv_assert_observed_region, sv_assert_reactive_action, sv_assert_reactive_drain. |
| 5 | Lexical conventions | PROVISIONAL (probed subset) | sized/based/underscored literals, including an underscore between the base specifier and first digit, real/time literals, unbased-unsized `'0/'1/'x/'z`, string escapes, `` `__FILE__ ``/`` `__LINE__ ``. The leading-underscore based-literal form is required by 5.7.1 and used by Caliptra; Slang 11 currently rejects it, so the permanent differential labels that oracle disagreement explicitly. **Fixed in M4B-27:** a string literal converts in assignment context to a one-dimensional signed 2-state unpacked byte array, left aligned in declared index order with null padding or right truncation; invalid element/rank targets are diagnosed instead of reaching a malformed scalar l-value. |
| 6 | Data types | PARTIAL | logic/bit/reg/byte/shortint/int/longint/integer/time, real/shortreal/realtime, chandle, string(+methods), event, enum(+methods), typedef, void, signed/unsigned casts, and builtin net types are supported in the evidenced subsets. **6.6.7/6.6.8 user-defined nettype/interconnect subset:** direct, alias, package/import, and parameter-instance-local nettype declarations preserve canonical identity and underlying integral/real/fixed-aggregate types. Ordinary SystemVerilog resolution functions with one matching dynamic-array input execute for one or multiple logic, bit, and real drivers; malformed resolver VVP metadata is rejected before symbol binding. No-resolver UDNTs enforce one whole-net driver, every UDNT rejects partial member/bit/part drives, and generic interconnects propagate scalar plus declared packed/unpacked shape across supported net-only port edges. Invalid underlying types, resolver signatures, variable/value references, unresolved components, and mixed UDNT components fail loudly. Class-method resolvers and selected/generic operands in interconnect concatenations remain explicit unsupported boundaries, so this is not a FULL claim. **Fixed 2026-08-14:** the 6.20.2.1 symbolic unbounded value `$` is preserved through integral value parameters, direct aliases, and ordered/named overrides; numeric uses, selects, nonintegral types, and value ranges are errors, and `$isunbounded` observes the marker exactly. **Fixed in M4B-17:** an explicit full-width select of an enum now has packed-vector l-value typing while an unselected enum still enforces 6.19.3 compatibility. **Fixed subset in M4C-17:** declaration-level `static`/`automatic` overrides control direct vec4 NBA-target and intra-assignment-control legality even when the containing function has the opposite lifetime; an automatic class/VIF handle does not make the persistent property it selects automatic. Dynamically sized array elements and aggregate-wrapped handle roots remain open. **Fixed 2026-08-14:** supported `type()` operands participate in compile-time `case` matching with ordinary first-match/default/quality behavior, and a `specparam` used in a general elaboration-time constant expression is an error instead of being frozen with a warning; annotation-eligible specparam expressions remain legal. **Fixed/verified 2026-08-27 subset (6.16, Table 6-9, 11.4.12.2):** concatenations in a string assignment context retain string literals and string expressions, including string-returning methods and parentheses-free static functions, preserve folded string identity and explicit integral-to-string casts, and reject a true string expression mixed with an uncast integral expression even beneath a conditional or whole string cast. Nested run-time literal replication remains string-typed through direct targets, whole string casts, and comparisons; string replication into an integral target is rejected; and zero/nonzero repeats evaluate their operand exactly once, with zero producing the empty string. Review hardening removes the arbitrary one-megabyte runtime cutoff, passes a legal 1,048,576-byte variable repeat, preserves multiplier signedness into VVP, and diagnoses negative, X/Z, or index-width-overflow counts. Built-in methods on data objects and constant string parameters carry their exact declared result types, accept a nested-concatenation receiver, reject a scalar selected-byte receiver, and enforce arity before lowering; constant methods preserve semantic empty, nonprinting, backslash, and quote bytes. Generic class templates defer concat legality only for a formal/local/property whose parse-form type parameter is still unresolved, then check each concrete specialization. Final validation passes 23/23 focused legacy, 24/24 focused JSON/VVP, 2,083/2,083 full legacy, 1,161 full JSON/VVP entries with 0 failures, 136/136 negatives, 103/103 VPI, 6/6 textual VVP compatibility, and 354/354 real-DPI UVM. Direct `string[index]` concatenation and the `br_gh800` literal-only mixed group are separately labeled compatibility extensions, not general integral acceptance or IEEE behavior. Bounded residuals include a wrong method value for a fixed-size unpacked signal-array string element, pre-existing acceptance of `s.compare(65)`, `{8'h41} == s`, and non-static `C::f`, plus rejection of a parentheses-free static call in a constant `localparam` concatenation. Corner: `$typename` returns the canonical base representation (e.g. `int`→`logic`), dropping ranges — a diagnosed-by-behaviour introspection limitation, not a value miscompile. |
| 7 | Aggregate data types | PARTIAL | Core forms of packed/unpacked aggregates, dynamic arrays, queues, associative arrays, assignment patterns, locator/reduction/ordering methods, streaming, `$cast`, and bitstream casts are supported in the evidenced subsets below. **Fixed in M14:** module-static integer-keyed assoc value read (was a silent value-loss). **Fixed in M4B-16:** parentheses-free associative-array `size`/`num` now report the live entry count and agree with `size()`/`num()`. **Fixed subset in M4B-21:** an in-range constant partial prefix of a fixed multidimensional unpacked array is a subarray in the supported procedural-copy and continuous-assignment contexts, with declared-direction mapping, strict type/shape equivalence, original-net sensitivity, and per-word driver accounting. **Fixed/verified subset in M4B-22:** queue concatenation assignment builds a complete temporary value before changing the destination, including self/slice operands and bounded-tail evaluation; a clean 923-test sv-tests replay changed exactly the three affected queue cases from semantic failure to verified runtime. **Fixed/verified 2026-08-15:** queue and dynamic-array elements captured by task `ref` formals retain element identity through insert/delete/pop, bounded-tail removal, ordering, whole-container replacement, and dynamic-array deletion. A removed element becomes an outdated private cell for the lifetime of every outstanding alias, across integral, real, string, and object element types. This element-ref binding currently requires a direct signal receiver; nested or class-property container elements and side-effecting object-aggregate capture remain open. **Fixed/verified subset in M4B-23:** direct-context `find_last`/`find_last_index` results contain exactly one last matching value/index or a concretely typed empty queue for queues, dynamic arrays, and direct-signal zero-minimum one-dimensional integral fixed arrays; supported fixed-array first/last respects declared direction, incompatible result contexts are errors, and a missing `with` or malformed iterator argument is diagnosed. Associative locators, nonzero-base/nonintegral direct fixed arrays, multidimensional fixed receivers, aggregate-element value copying, and result typing through expression wrappers remain open or loud as documented. **Extended/verified 2026-08-24:** all six locator methods on one-dimensional fixed-array class properties evaluate the receiver once, preserve negative/nonzero declared indices and leftmost/rightmost `find_first*`/`find_last*` behavior, and return fresh queues for integral, real, string, and class-handle elements. General locator traversal/result order remains deliberately unspecified by 7.12.1; multidimensional property receivers remain loud. **Fixed/verified subset in M4B-24:** a terminal unindexed parentheses-free `min`/`max` on a direct integral dynamic-array or queue signal evaluates the method instead of returning the receiver, carries a concrete queue element type into direct assignment compatibility, and preserves the explicit-call result, empty-result, signedness, bound, and source-value semantics checked by permanent runtime tests. Non-integral and associative receivers remain loud; fixed-array nominal queue typing, iterator/`with` forms, class/property/nested/indexed receivers, and result typing through call-result or wrapper contexts remain open. **Fixed/verified subset in M4C-24:** structure replication, member/type/default precedence, declared-index keys, and nested replicated unpacked structs with fixed-array members preserve their full aggregate shape through VVP lowering. The permanent positive and eight-site negative tests cover the implemented 10.9 subset; remaining simple/user-defined type keys and arbitrary expression keys remain open. **Fixed/verified subset in M4C-25:** constant explicit and indexed range slices of one-dimensional fixed unpacked arrays support blocking/NBA slice-to-slice and slice/whole copies, declared-direction mapping, overlap-safe blocking snapshots, and element-wise equality families. A native 1,027-test replay moved exactly the three Chapter 7 slice cases to runtime-verified. A run-time-variable indexed base, multidimensional range slice, and class/property slice value remain loud residuals. **Fixed in M1B-7:** result-type analysis for a class method reached through a direct unindexed unpacked-struct member follows that member instead of inventing an object result. **Fixed 2026-08-14:** wildcard associative dimensions preserve one wildcard-index type for `[*]`, `[* ]`, `[ *]`, and `[ * ]`. Indexed class-array members remain open. Run-time prefixes, out-of-range source-subarray values, procedural values with more than one residual dimension, class/property partial-prefix sources, and fixed-prefix sources assigned to class/aggregate-member destinations remain loud. Other corners: string/real-VALUED integer-keyed assoc (`string s[int]`) — narrow; `%p` on integral aggregates renders empty (has a stderr warning); member access on an element of an unpacked array of packed struct, and whole-array pattern assignment into such a class property, are fixed (were a crash and a silent zero-fill); **Fixed/verified 2026-08-23:** bounded scalar and fixed-property queue receiver `push_front`, `push_back`, and `insert` mutators preserve the declared maximum; class-property unpacked arrays of `real`/`string` still store every element to one slot (issue #100). |
| 8 | Classes | PARTIAL | new/ctor/this/super, single inheritance, virtual & pure-virtual dispatch, abstract classes, static members, parameterized `#(T)`, typedef fwd-ref, protected/local, `$cast`, and chained `C#(T)::m()` are supported in recorded subsets. **Fixed/verified 2026-09-01 subset (8.19):** non-static instance-constant assignment sites are authorized only in the corresponding constructor. Path-sensitive constructor-flow auditing plus a per-object runtime guard enforce at most one executed assignment across the recorded conditional, return, loop, and detached-fork paths; static constants remain declaration-initialized. **Interface classes / `implements` (2026-08-13):** interface classes form a separate multiple-inheritance graph, retain specialization identity, inherit type declarations only across interface `extends`, enforce pure-method signatures and concrete completion, and participate in assignment, virtual dispatch and `$cast` at run time. The complete related 28-case pinned sv-tests cluster and eight positive/negative dual-harness reducers cover direct/multiple/diamond relations, typedef access, conflicts, partial virtual implementations, illegal members/relations/qualifiers, missing/nonvirtual methods, specialization casts and required generic-class actuals. **Class declaration context (2026-08-14):** nested class declarations retain and restore the complete enclosing-class stack across deeper nesting; out-of-block constructor/function/task bodies are accepted in module scope as well as package/compilation-unit scope, while bodies outside the class's exact declaration scope are rejected without disturbing the caller scope; and each pure virtual method in a non-virtual class is rejected at declaration time. Dual-harness reducers and the corresponding pinned sv-tests cases cover all three boundaries. **Fixed 2026-08-14:** `static const` property order is accepted alongside `const static`; duplicate qualifiers and combined `local protected` are exact errors. An IEEE typedef named `bool` shadows the Icarus extension keyword throughout its visible class/type context, including extern prototypes and out-of-class bodies, without changing the extension when no typedef is visible. **Fixed 2026-08-23:** package-qualified calls through a class's nested typedef (`pkg::class::type_id::method(...)`) work in expression and discarded-return statement contexts, retain explicit class specialization, and preserve independent static storage; reduced arity failures remain loud. **Fixed 2026-08-24:** a derived class can use an inherited, concretely bound superclass type parameter as the root of nested typedef/static calls (`DRIVER_T::type_id::set_inst_override(...)`) in statement and expression contexts; reduced arity failures remain loud and OpenTitan factory overrides are no longer compiled away. **Fixed 2026-08-24 (8.25):** a class type actual that is itself value-parameterized retains the nested actual value in specialization-cache identity, including through dependent superclass substitution. The dual-harness `sv_param_class_dependent_super_value_identity` reducer pins successful width-10 inherited casts and rejected width-11 casts after eager default specialization, and pins positional/named/aliased symbolic `$` as one identity distinct from an ordinary same-width all-X value. Specialization identity uses variant-tagged effective constants: exact IEEE-754 bits for real values (including `-0.0` and the accepted `0.0/0.0` NaN form), complete post-conversion width/sign/four-state storage plus the symbolic-unbounded marker for integral values, and raw string storage. Diagnostic-free integral probing propagates a declared packed formal's assignment width and each arithmetic expression's common signedness through the supported nested unary/binary subset before arithmetic, resolves one constant packed parameter select, and applies four-state-to-two-state coercion for `bit` formals. The dual-harness `sv_param_class_dependent_super_real_identity` reducer pins the formerly colliding `1.0 + 1e-7` / `1.0 + 2e-7` values, integral division/overflow/unary/mixed-sign conversion, packed-formal carry and signed overflow across binary/unary/nested arithmetic, `-0.0`, NaN, a packed select, dependent `N + 1`, and logic/bit/string controls. For unpacked structs, the evidenced semantic subset is fully literal positional patterns and already-evaluated equivalent parameters; declared conversions are reapplied recursively through nested unpacked structs, fixed arrays, and string leaves. Omitted defaults, direct patterns, named/positional class actuals, and a package localparam unify in the reducer. Keyed, replicated, union, or unresolved identifier-bearing aggregate patterns retain scope-sensitive source identity and are not claimed as effective-value canonicalization. Cache-key probes remain diagnostic-free; `sv_param_class_cache_probe_diagnostic_fail` pins one ordinary diagnostic for each invalid real, string, and unpacked-struct actual. Unpacked-array value formals remain outside the parser-supported class-parameter forms. **Fixed in M14:** width-1 (`bit`/`logic`) class-property `$display` (was garbage; value was always correct). Corner: shallow-copy inline static initializer `C b = new a;` at module scope works as `C b; b = new a;`, and in automatic/class scope. |
| 9 | Processes | SUBSTANTIAL | initial/always/always_comb/ff/latch, final, fork/join(/any/none), disable, disable fork, wait fork, static/automatic, `process::self`/`kill`/`await`, and `suspend`/`resume` with real `status()` states (M6B-1). A named begin/end shares the enclosing process identity; fork branches do not (9.3.1). Completed ordinary zero-time activations are reclaimed immediately instead of accumulating until Active-region quiescence; only callback-bearing threads and frames on a live recursive function/final execution chain are retained, with the latter unpinned on unwind or left to their already-queued owning delete after non-local disable. This also removes a double reap and post-reap comparison exposed by immediate reclamation. **Fixed in M1B-6:** lazily elaborating a separately declared task/function from a caller's fork no longer makes its ordinary `return` lexically part of that fork; a `return` actually written in a fork remains an exact-gold compile error. **Fixed in M4B-28:** the IEEE prefix parallel-block label form parses with matching-label and `disable` semantics, and conditional event-expression guards are evaluated per triggering leaf with re-wait, four-state nonmatch, event-or independence, cancellation isolation from unrelated detached children, and nonblocking intra-assignment snapshot preservation. (Verified 2026-08-14.) **Fixed/verified process self-kill unwind:** when `process::kill()` terminates the current logical process from a nested synchronous function, the default iterative call trampoline recognizes frames already reaped and unlinked by `do_disable()` and unwinds them without a second `do_join`; `sv_process_kill_join_reducer` is exact mainline-red coverage and `uvm_process_guard_join_test` pins the Accellera guard shape. **Synthesis boundary verified 2026-08-16:** one-bit asynchronous set/reset predicates written as logical equality or inequality against constant 0/1, in either operand order, are recognized when their truth polarity matches the corresponding `posedge`/`negedge` event. Unsized integer constants are handled without mistaking a mismatched polarity, nonconstant comparison, signed-one widening, or other comparator for a simple asynchronous control. **Fixed/verified 2026-08-24:** an implicit combinational process in a child remains asynchronous and synthesizable when its input formal is connected to a parent packed part-select or packed-struct field. Asynchronous classification keeps the elaborated event probe nexus instead of inferring dependency provenance from neighboring select topology; exact selected `always_comb` simulation sensitivity is independently observed by `sv_always_comb_precise_select_sens`. See the [Caliptra selected-input synthesis log](../session_logs/2026-08-24_caliptra_selected_input_async_synthesis.md). |
| 10 | Assignment statements | PARTIAL | Blocking/nonblocking, continuous assignment, assignment patterns, compound (`+=` etc.), `++`/`--`, and the listed aggregate-assignment subsets are supported. **Fixed/verified 2026-08-15 (10.3.3):** scalar and vector net declaration delays now use inertial rescheduling/cancellation, with rise/fall/turn-off selection and Table 28-9 minimum-delay transitions to X. A pure vector net delay schedules bits independently; a delayed declaration assignment or standalone continuous assignment schedules the vector value as one unit. One-/two-/three-delay forms, parameterized widths, drive-strength ordering, and invalid delay expressions have permanent positive/negative coverage. **M4C-24** expands structure replication and preserves member/type/default and declared-index assignment-pattern keys through contextual elaboration; its VVP path stores nested fixed-array members inside replicated unpacked-struct values without collapsing an array dimension. M4C-8 schedules whole vec4 class/VIF properties and constant packed fields with receiver/RHS capture and event-time field RMW; program-process forms use Re-NBA. M4C-17 preserves these and ordinary persistent-signal NBAs when scheduled by a procedurally called SystemVerilog function instead of rewriting them as blocking; direct automatic vec4 targets remain exact errors, explicit-static locals remain legal, and NBA-bearing functions are not constant functions. Dynamic/indexed/event-controlled property forms are loud rather than silently blocking. Full-width enum bit/part-select targets are preserved across both procedural and continuous assignment (M4B-17). Disjoint continuous/procedural terms on a multidimensional packed variable are checked in canonical flattened bit coordinates, while a true overlapping element remains an error (M4B-18). A run-time packed index after an unpacked-array word keeps both the word address and canonical packed offset (M4B-19). Fixed constant-prefix unpacked subarrays support blocking/NBA value copy and continuous l-values with left-to-left direction mapping, synthesis-safe lowering, and order-independent per-word overlap checks (M4B-21). M4B-22 evaluates a queue concatenation into fresh storage before its single destination update, so self-references cannot observe a partially overwritten queue and bounded tails are still evaluated; clean sv-tests runtime evidence pins that subset. Blocking unpacked-array function results also map declared left to declared left; the nonblocking form remains loud pending a per-word NBA snapshot. Residual M4B-20: driver conflict checking still treats packed terms inside one unpacked word as whole-word terms. Run-time unpacked-subarray prefixes and broader procedural residual shapes remain loud. Function-NBA call-context enforcement, dynamically sized array targets, and captured-handle aggregates remain residual M4C-17 work. Corner: net `alias` (syntax error). |
| 11 | Operators & expressions | PARTIAL | all arithmetic incl `**`, bitwise/logical/comparison/shift, `inside` (values AND ranges), `==?`/`!=?`, `?:` (incl 4-state), concat/replication, streaming, casts, string ops. **Fixed/verified in M4C-28:** ordinary and strength-aware VVP concatenations wait for one delivery from every connected input port before first publication, including all-Z and partial-vector deliveries; parsed input count, not bit coverage or four stored width slots, defines readiness. **Fixed immediate-blocking subset in M4C-18:** streaming targets retain fixed and dynamic-array/queue/string members, including nested class properties, and apply the 11.4.14.4 greedy rule. A streaming operand followed by `with [array_range_expression]` supports index, range, `+:`, and `-:` over any supported one-dimensional fixed/dynamic array or queue. Receiver and range operands evaluate once in standard order immediately before their field; fixed/dynamic selection, resizing, ascending/descending declared bounds, mixed ranged/greedy fields, fixed variable OOB clipping, bounded queues, 2-state coercion, and X/Z range diagnostics are value-pinned. Constant fixed OOB, nonintegral ranges, and an unconstrained field before a ranged field are exact errors. Flattened vectors and object-backed target element counts have separate runtime caps, every source/target range plan has a bounded per-operation element count, rejected target operations preserve the prior value, and fixed target index translation is O(N) overall. Delayed/event-controlled and NBA run-time-sized targets remain explicit compile-time residuals pending scheduled receiver/range/source/target snapshots; they do not fall through to blocking execution. **Fixed subset in M4C-23:** a concatenation expression can be followed directly by a bit, descending constant part, or indexed `+:`/`-:` select with self-determined packed-vector coordinates; other non-identifier primary shapes remain open. Full-width enum selects retain their unsigned packed-vector expression type instead of the enum's named type (M4B-17); exact computed enum elements after an unpacked word retain their declared type (M4B-19). A constant fixed-unpacked prefix is consumable as a subarray value only in M4B-21's supported assignment contexts; there is not yet a general aggregate expression node for run-time/property/deeper-residual forms. Other residual: the general multidimensional packed computed-base path lacks per-dimension run-time out-of-bounds guards (an inner OOB index can alias a neighbouring outer slice) and does not yet reject every non-integral leading index. |
| 12 | Procedural programming statements | PARTIAL | if/else, `case`/`casex`/`casez`, `unique`/`unique0`/`priority` **case and if**, for/foreach/while/do-while/repeat/forever, break/continue/return all FULL. Qualified-if chains preserve if-expression truth, priority short-circuiting, unique all-condition evaluation, first-match execution, final-else suppression, and the required no-match/multiple-match warnings. **Fixed in M14/M4C-19:** `case (x) inside` performs range membership and accepts the full 12.5.4 comma-mixed open-value-range item grammar (values, wildcard values, bounded/unbounded ranges); malformed items recover without a compiler crash, and an ordinary case range is rejected rather than silently never matching. Corners: `if (x matches p)` and `case matches` tag binding (syntax errors / diagnosed). **Fixed/verified 2026-08-27 (12.7, 12.7.1, Syntax 12-5):** a `for_initialization` now accepts several comma-separated `for_variable_declaration`s, each with its own `data_type` and its own same-type declarator continuations, covering typedef-led, package-qualified, class-scoped, specialized-class-scoped, packed-dimensioned, and `var type(expr)` types, and declarator names lexed as TYPE_IDENTIFIER. The implicit block opens before the data type is parsed so inline anonymous enums register their literals in it, and declarators are installed before the condition and step are lexed. Control variables are automatic even in a static subroutine; a statement label names the implicit block for `%m` and `disable`. See the 2026-08-27 section below for the measured boundaries. |
| 13 | Tasks and functions | PARTIAL | Tasks/functions, automatic/static lifetime, ref/const-ref/input/output/inout, default and named arguments, void functions, `void'()`, class/struct/array returns, and recursion are supported across the listed tested forms. A `localparam` interspersed in an old-style task/function body is retained as a declaration rather than misparsed as an executable statement; the Caliptra untyped form is runtime-pinned and ordinary untyped-function controls remain green. **Fixed in M1B-6:** every task/function definition-body elaboration starts in its own lexical fork context, including lazy parameterized-class specialization reached from a forked caller; `sv_fork_lazy_param_typedef_return` pins both function and task bodies while `task_return_fail2` preserves the illegal lexical-fork boundary. **Fixed in M1B-7:** `void'(...)` can discard scalar or object method results reached through a direct unpacked-struct class-handle member with the actual return type and no object-fallback warning; void-casting a task remains an error. **Fixed 2026-08-15 (13.4.4):** function bodies accept the expressly permitted `fork...join_none`, while `fork...join` and `fork...join_any` are rejected across nested/named scopes and class methods; the corresponding task forms remain legal. **Fixed subset in M4C-17:** a procedurally called SystemVerilog function can schedule an NBA to a persistent ordinary signal or supported class/VIF packed target without suspending or applying an immediate store; declaration-level static/automatic lifetime is enforced for direct vec4 locals, and such a function is rejected in a constant expression. This is not full 13.4.4 closure: program-call and freshly allocated local-object runtime forms, nonprocedural/final call-context enforcement, dynamically sized array targets, and automatic aggregates containing captured handles remain open. A blocking unpacked-array function result can target a whole fixed array or fixed-prefix slice and preserves declared-order correspondence across opposite range directions. **Fixed 2026-08-15:** task string `ref` formals use the same bound-reference wrapper as integral, real, and class-handle task formals, including detached fork writes and queue/dynamic-array element cells; whole-container task formals and function string/real formals retain the documented copy path. **Fixed/verified in M4C-29 (6.21/13.3.1 recorded subset):** an otherwise static task or function preserves its static VPI identity and inherited static ports/locals while each call owns storage for explicitly automatic scalar, dynamic-array, and fixed-array declarations, including integral/logic/real/string/object elements and nested named-block overrides. Initializers execute before detached children consume the activation; virtual-interface dispatch, detached-frame retention, array-port context selection, explicit-static fixed-array force/release, and per-declaration VPI lifetime metadata use the declaration's actual context owner. Conversely, explicitly static locals in automatic tasks/functions retain shared one-shot storage. Residuals: the equivalent nonblocking assignment is rejected loudly until aggregate NBA snapshotting exists; indexed struct-member-array method receivers remain open; a function returning an unpacked-array typedef assigned via `'{...}` aborts (ICE — loud but ungraceful). |
| 14 | Clocking blocks | PARTIAL | **Fixed/verified 2026-08-24 subset; itemless public-event follow-up 2026-08-25.** Default/explicit/global clocking, `##N`, `#1step` Preponed sampling, numeric-skew sampling, output drives, and direct/class-held virtual interfaces are supported. Every valid clocking block, including one with no clockvars, has a public synchronization event that fires in Observed after NBA quiescence; static, hierarchical, global, default, VIF, and modport-VIF references use it. Its VIF representation is two-state, so initialization cannot manufacture a time-zero event. Numeric `#0`/`#N` samples are stored before both static and VIF `@(cb)` waiters wake. Same-scope, static-instance, alias, and VIF output drives preserve constant packed member/bit/part selection; current-event and buffered drives share the per-instance apply path and the defining scope's output skew. The follow-up audit made a root indexed class receiver loud before its stateful index can be cloned, centralized output-skew elaboration so one invalid declaration produces one diagnostic independent of drive count, restored exact modport provenance through additional carriers, and made VPI property writes loud instead of bypassing sampling or drive scheduling. Remaining legal boundaries are loud: run-time-selected drives, indexed class receivers, whole unpacked output storage, selected clockvar declaration-assignment targets, and non-default parameterized-interface widths. A clockvar concatenation l-value is rejected as illegal under 14.16. See the [selected-drive](../session_logs/2026-08-24_opentitan_vif_clocking_selected_drive.md), [static-skew/modport](../session_logs/2026-08-24_opentitan_clocking_static_skew_modports.md), and [HMAC frontier](../session_logs/2026-08-24_opentitan_hmac_boolean_dist_subject.md) session logs. |
| 15 | Interprocess synchronization & communication | PARTIAL | named events (`->`/`@`/`wait`/`.triggered`), semaphores, mailboxes (incl `#(T)`) all FULL. Corners: merged events (`e1 = e2`) diagnosed; `wait_order` (syntax error). |
| 16 | Assertions (SVA) | PARTIAL | Synthesized checkers, automaton (NFA) engine by default with the legacy linear engine behind `IVL_SVA_LEGACY=1` and a dual-run parity gate over both. `|->`/`|=>`, `##N`/`##[m:n]`/`##[m:$]` incl. mid-chain, `[*N]`/`[*m:n]`, goto/non-consecutive repetition, `and`/`or`/`intersect`/`within`/`throughout`, `not`/`first_match`, sequence local variables, `strong`/`weak`, `.triggered`/`.matched`, `expect`, procedural concurrent assertions with implicit clock inference, `disable iff`, sampled-value functions with real histories, named properties, defaults, pass/fail actions, cover, and the clause-40 VPI lifecycle. **Caliptra property-local subset (2026-08-16):** named properties and sequences accept plain formals followed by `int` and unsigned packed/scalar `logic` locals. Match-item assignments apply the declared width/sign conversion before later use, every overlapping attempt owns its complete local value, and multidimensional 256-bit captures survive fixed and unbounded implication paths. Broader assertion-variable types, declaration initializers, directions/defaults on formals, and complete branch flow analysis remain outside this bounded subset. **Single-clock NFA implication fan-out (M9-16):** every endpoint of a variable-length or combinator antecedent owns an independent multi-step/tree consequence record for `|->` and `|=>`; same-tick verdict counts retain one action and success/failure callback per record, while step callbacks remain once per checker per tick. An assignment made exactly once on a deterministic leaf prefix is snapshotted per obligation. Branch-local, post-branch, repeated, duplicate, interior-tree, and fused-`##0`-read assignments remain loud until per-live-path locals and assignment-before-read scheduling are available; empty consequences are also loud. Strong end-of-simulation failure actions and failure callbacks repeat once per live consequence record. Loop-free pools have an exact capacity bound and cyclic forms keep the finite-pool/loud-overflow contract. **Selective assertion control:** labeled and per-instance hierarchical `$assertoff`/`$asserton` stop and resume only new attempts for the selected directive, preserve attempts already executing at Off, and retain VPI identity as `(runtime scope, assertion index)`. Finite `always[m:n]` attempts preserved by Off expire at `n`, while unbounded attempts remain live. `$assertkill` reports disable/reset callbacks and aborts active attempts in the linear, NFA, parameter-bound, generated-delay, temporal, and two-/N-domain multiclock checkers. Per-identity generations survive immediate Kill/On pairs; generation-tagged multiclock handoffs cannot revive killed requests; identifier selectors are resolved in their lexical call context and canonicalized to a rooted per-instance identity, canonical generated selectors match `G[2]`, and final strong obligations are suppressed without requiring another assertion clock. The lexical canonicalization covers bare labels through nested procedural blocks, relative scope/child paths, explicit rooted paths, and chronological controls issued before checker registration; string-valued selectors and package/`local::`/`this`/`super` forms retain their existing exact runtime/source-spelling behavior. Queued deferred-immediate reports and pending procedural assertion instances remain the separate R29 cancellation gap. **Concurrent-assertion region placement is conformant (M6B-4):** whole signals, packed selects, direct packed-aggregate members, unpacked-array words, reals, hierarchical names, and direct members of statically bound interface/modport ports sample Preponed; evaluation runs in Observed and actions in Reactive. Runtime-selected interface-array members and package-qualified mutable operands remain loud live-read boundaries. **Parameter-valued bounds are PARTIAL (M9-15):** the focused instance-sized implication/cover paths preserve exact/range/unbounded repetition and bounded-consequence expressions through instance override, reject invalid values during elaboration, and keep unsupported standalone symbolic ranges loud. **Deferred immediate assertions remain PARTIAL (R29):** `#0` and `final` expressions evaluate synchronously; positional scalar, real, string, dynamic-container, and class-handle `$error`/`$display` arguments are value-captured in module, task, function, and class contexts; reports use process-local Observed/Reactive or Postponed queues with flush/cancellation behavior; deferred cover uses the same queues; module/generate items are implicit `always_comb`; labels preserve hierarchy/`%m`; and assertion control gates new reports. Passive zero-actual user tasks are supported for `final`. Illegal action blocks, malformed bytecode, source-final `#0`, and unsupported user-task/method/ref/fixed-unpacked-array action shapes fail loudly. Remaining gaps include general user-subroutine/ref/fixed-array argument capture, deferred-cover database/VPI accounting, assertion-label/outermost-disable cancellation, `$assertkill`/VPI-reset queue cancellation, deferred-immediate VPI assertion identity/result callbacks, cross-clock overlapping `|->`, `disable iff` across a two-or-more-boundary chain, and the separately recorded branch-flow/deferred-immediate gaps. |
| 17 | Checkers | PARTIAL | **M9-9.** `checker`/`endchecker` implemented on the module machinery: typed formals with directionless-defaults-to-input (17.4), default formal values, property/sequence declarations, `assert`/`assume`/`cover`, checker-local `default clocking`, internal variables and procedures, multiple independent instances, nested checker instantiation, `endchecker` labels, and `bind` of a checker. Loud residuals: untyped formals, event-typed formals, free (`rand`) variables (17.9), a checker DECLARED inside a module, procedural instantiation. sv_checker_basic, sv_checker_nested_instance, sv_checker_bind. (Verified 2026-07-25.) |
| 18 | Constrained random value generation | PARTIAL | The evidenced core includes rand/randc, class and bounded scope `randomize()` with/without inline `with`, constraint blocks, `inside`, `dist`, implication, if-else constraints, `solve...before`, soft priority, `disable soft`, `unique {}`, object/property variable control, hooks, foreach/container constraints, `randcase`, `randsequence`, and per-object/per-process RNG state. Inherited constraints are solved as one set and conflicting soft constraints follow declaration priority. **M3B-2 (expanded 2026-08-14):** `randsequence` covers acyclic production reuse, weighted alternatives, constant/default/named input actuals, production `if`/`case`/`repeat`, ordered code blocks, bounded `rand join` interleavings, whole-sequence `break`, and production-local `return`; each unsupported broader form fails loudly. **M3B-17 (expanded 2026-08-12):** fixed unpacked-array `rand_mode` accepts declared-direction and multidimensional element/subarray setters and singular indexed queries. Dynamic arrays and queues use live numeric element modes; associative arrays preserve integral, string, and object key identity. Whole-array setters control current and future members, queue membership and ordering changes carry mode state with existing members, associative delete/reinsert creates a fresh active member, failed solves restore modes, and static aliases converge on canonical storage. The IEEE singular-function rule rejects a whole dynamic/queue/associative query; the whole fixed-array query remains a documented Slang-compatible all-enabled extension. Fixed, dynamic, queue, and associative unpacked `randc` elements carry independent transactional histories. The dynamic/queue/associative subset includes unconstrained and constrained feasible-domain cycles, mode pause/resume, queue permutation and membership changes, associative delete/reinsert, failed-solve rollback, canonical static aliases, and class shallow-copy state. **M3B-18 (2026-08-10):** recursive direct/fixed/D/Q/M class-handle graphs use one alias/cycle-safe transaction; descendant failure restores graph values and instance/static cyclic history, and canonical-static tentative values remain invisible to scheduler/VPI observers until final commit. **Fixed 2026-08-14 (evidenced unpacked-struct-member subset), expanded 2026-08-24:** `rand`/`randc` qualifiers on unpacked-struct members survive parse, elaboration, target lowering, and VVP execution. An outer `rand` struct property activates only qualified members, leaves unqualified state unchanged, preserves per-member transactional `randc` cycles, and constrains sparse enum members to their declared domain (including randc cycling over that feasible set). A class constraint may name a one-level scalar integral or enum member up to 64 bits as an independent solver variable; the `(outer property, member)` identity survives `solve...before`, unqualified or disabled members are pinned state, direct member `rand_mode` setter/query controls activation, enum domains remain declared-literal domains, and model values plus constrained-randc history commit or roll back atomically. Member qualifiers on packed structs/unions and rand real/string members are eager declaration errors even for unused typedefs. A randc integral leaf wider than the 20-bit history cap emits a named warning, including through a nested struct. Legal class-handle/container members remain declaration-positive but an enabled use makes `randomize()` return 0 with a runtime diagnostic. **Still open:** recursive `randsequence` grammars, nonconstant production-actual capture, value-returning productions, non-input formals, nested-control joined lanes, packed-select randomization semantics beyond the compatibility boundary, joint parent/child constraint solving, recursive child hook dispatch, class-handle/container struct-member randomization, deeper/indexed/aggregate unpacked-struct constraint paths, dynamic/associative member-lifecycle corners beyond the evidenced integral subset, and exact cycle completeness beyond the documented width bound. These prevent a FULL claim. Every thread and class object is seeded hierarchically at creation; `srandom`/`get_randstate()`/`set_randstate()` preserve the deterministic state contract. |
| 19 | Functional coverage | PARTIAL | The evidenced implementation includes value/range/default/ignore/illegal bins, `iff`, compact transitions, fixed and per-instance dynamic-family crosses, constructor and `with function sample` formals, recorded instance/type options and queries, and durable reports. The typed constructor subset preserves source/coverpoint width and sign, four-state rejection, 19.5.7 conversion, descending-range emptiness, and OpenTitan's exact `[0 : 2 << (valid_source_width - 1) - 1]` range. Integral open bins coalesce to distinct resolved values; fixed arrays preserve ordered occurrences, put the remainder in the last nonempty bin, and carve after distribution. Object-specific cross plans cover automatic products and the evidenced `binsof`/named-`binsof` `intersect` conjunctions, overlapping named bins, `iff`, `illegal` > `ignore` > normal precedence, and illegal-cross locality. For 2023, `option.cross_retain_auto_bins` defaults to 1; a covergroup value defaults its crosses, a cross-local value overrides it, and coverpoint/`type_option` placements are errors. Constant values and the 2017 edition rejection are implemented; the retention reducer covers inherited fixed/dynamic defaults, local disable/enable overrides, no-explicit-bin retention, and empty ignore/illegal declaration presence. Constructor/per-instance expressions remain open. Current local gates are focus 20/20 in both paths, legacy 4,127 pass / 0 fail / 2 NI / 3 expected fail (4,132 total), JSON/VVP 1,017/1,017, negatives 136/136, VPI 103/103, and canonical UVM 354/354. The final OpenTitan 61-target UVM compile matrix is 8 DEBT / 50 FAIL / 3 SETUP_FAIL / 0 PASS versus 1 DEBT / 57 FAIL / 3 SETUP_FAIL / 0 PASS, with seven FAIL→DEBT transitions, zero timeouts/resource-limit signals, and zero exact or generic former cross-drop diagnostics. It is not a clean application or runtime pass. The final Caliptra static census is Icarus 53/105 in each assertions/no-assertions/synthesis lane versus Slang 54/105, with 52 PASS / 1 DEBT / 51 SHARED_SOURCE_OR_CONFIG / 1 SOURCE_ORDER_DEBT / 0 ICARUS_GAP; the sole Slang advantage is known `csrng_raw_wrap` source-order debt. This is compile/elaboration/synthesis differential evidence, not full DV runtime. Remaining gaps include constructor `ref`/output/inout directions, broader endpoints, constructor/per-instance retention expressions, transition-term illegal crosses, remaining dynamic `with`/`matches`/set/`CrossQueueType` and broader compound selectors, source denominator carving, type-coverage union, report/VPI/normative naming, broader signed static range/intersect normalization, empty trailing fixed-array-bin identity/naming, products over 65,536, and 2023 real/tolerance coverage. Caliptra's hierarchical member cross-item compatibility extension remains separate because 19.6 restricts standard cross items. Complete clause-19 closure is not claimed. |
| 20 | Utility system tasks & functions | PARTIAL | `$clog2/$bits/$size/$dimensions/$left/$right/$low/$high/$increment`, `$isunknown/$onehot/$onehot0/$countones/$countbits`, `$info/$warning/$error/$fatal`, `$time/$realtime/$stime`, math funcs, `$random/$urandom/$urandom_range/$dist_*`. **Fixed 2026-08-14:** `$isunbounded` observes the symbolic 6.20.2.1 parameter value and folds ordinary expressions to false. The 40.3 code-coverage macros and access routines have exact values, signatures, target/domain validation, and standards-defined `SV_COV_NOCOV`/`SV_COV_ERROR` results. Real code-coverage instrumentation and database load/save remain unavailable and are diagnosed, so the clause is PARTIAL. (`$typename` limitation recorded under clause 6.) |
| 21 | Input/output system tasks & functions | PROVISIONAL (probed subset) | full `$display/$write/$monitor/$strobe` format set (`%b/%h/%d/%o/%s/%c/%e/%f/%g/%t/%p/%m/%v`), file I/O (`$fopen…$fscanf/$sscanf/$fgets/$fread`), `$readmem[hb]`/`$writememh`, `$sformat[f]/$swrite`, `$value$plusargs/$test$plusargs`, `$dumpfile/$dumpvars`. (`%p` on integral aggregates recorded under clause 7.) |
| 22 | Compiler directives | PROVISIONAL (probed subset) | `` `define `` (args), `` `ifdef/`ifndef/`elsif/`else/`endif ``, `` `include/`undef ``, stringize `` `" ``, paste `` `` ``, line-continuation, `` `line/`__FILE__/`__LINE__ ``, `` `timescale/`default_nettype/`begin_keywords/`end_keywords/`pragma/`resetall/`celldefine/`unconnected_drive ``. **Fixed/verified 2026-08-15:** macro replacement collection now respects ordinary-string, macro-quote, escaped-quote, token-paste, escaped-identifier and comment token contexts. A replacement cannot borrow a closing quote from its later expansion context; the malformed definition is rejected and not installed. Formal names inside ordinary strings are not substituted, while macro-quoted formals still are. Expansion depth is capped at 256 and aggregate expansions at 1,000,000, turning direct and mutual recursion into bounded errors. Evidence: sv_macro_definition_context, sv_macro_unterminated_string_fail, and sv_macro_recursion_limit_fail, plus the 22-case legacy and four-case JSON macro focus lists. |
| 23 | Modules and hierarchy | PROVISIONAL (probed subset) | instantiation (position/name/`.*`/`.name`), param overrides (order/name), `defparam`, ANSI/non-ANSI ports, hierarchical refs, `bind` (**M13**), empty/unconnected ports. **Fixed/verified 2026-08-16:** a bit- or part-selected actual on an output port remains a directional selected connection instead of being collapsed as its underlying whole net and reflected into the child as a false structural driver; nested output wrappers and genuine continuous/procedural overlap have permanent synthesis coverage. **Verified 2026-08-15 (23.3.3.7):** collapsed net ports apply every wire/tri, wand/triand, wor/trior, tri0, tri1, uwire, supply0 and supply1 dominance cell from Table 23-1, including its warning cells. The dominant delay domain and net type propagate through every collapsed alias; tri0/tri1 and supply pulls have one canonical carrier, so chained and order-reversed multi-instance connections cannot erase or duplicate the pull. Noncollapsed expression/variable connections retain their internal declaration delay. **Fixed/verified 2026-08-27 (23.11/Syntax 23-9 bounded subset):** bind paths retain structured absolute, explicit `$root`, and module/generate-relative identity; select one-dimensional generate/module-array elements; resolve conditional type/shape per active owner; and apply deferred directives to a source-order-independent fixed point. Final arrays require selection. Target lists, target-namespace collisions, module/interface/checker/program/primitive legality boundaries, and late `-y` target/path/compilation-unit-directive discovery are paired regressions. Invalid selections and paths fail loudly. Automatic roots are not rebuilt when a live contained bind discovers a compilation-unit bind after root selection; explicit `-s` selects the intended root in that case. See the dated section below for evidence and explicit residuals. `trireg` remains the frontend's pre-existing explicit unsupported net declaration rather than an unhandled matrix cell. Corner: `extern module`. |
| 24 | Programs | PROVISIONAL (probed subset) | program block, ports, initial/final, multiple programs. Corners: anonymous program, `$exit` (diagnosed). |
| 25 | Interfaces | PARTIAL | interface + modport, parameters, arrays, `import`/`export` methods, clocking-in-interface, virtual interfaces in the evidenced Syntax 25-3 declaration contexts, and modport direction enforcement. **25.5 audit follow-up, verified 2026-08-24:** the selected modport view is retained by direct declarations, typedef/array carriers, class properties and inherited properties, defaulted or explicit class type parameters, unpacked-struct members, and compiler-generated clocking accesses. Retaining the source clocking-block name means independently listing its rewritten raw member does not expose an otherwise unexported clocking block. A VPI-backed output argument cannot write a modport input through the read handle; the put is a loud run-time error and leaves the interface unchanged. Continuous assignments depending on bare, constant-indexed, operator, multi/mixed, and type/size/sign-cast interface-member forms lower behaviorally and retrigger; virtual-interface any-change waits on packed signal members are initialized from and then observe the complete vector, and cast traversal fixes Caliptra's explicit interface-member-to-enum conversion (M5-2). Dynamic posedge, negedge, any-change, and compound event waits through initialized virtual interfaces are runtime-pinned. Using a null virtual interface for any of those waits terminates simulation with one process-global fatal diagnostic and a failing status instead of aborting the simulator process. **Fixed/verified 2026-08-16:** implicit `@*`, `always_comb`, and `always_latch` sensitivity follows packed selects and fixed-unpacked interface-member words, including descending nonzero ranges, multiple member dependencies, ordinary-net/member mixtures, and run-time selectors (the latter conservatively watches every member word). Explicit constant unpacked-word posedge/negedge waits carry the canonical word into VVP. **Fixed 2026-08-24:** a repeated parameterized-class specialization-cache hit defers its method bodies through the same post-root worklist as a cache miss, so scalar and associative-array virtual-interface receivers retain selected-instance dispatch and declaration-scoped default/explicit argument rows. **Fixed/verified 2026-08-30 (25.9/Syntax 25-3 bounded subset):** both `virtual iface` and `virtual interface iface` work directly and through typedefs in compilation-unit, package, module, block, declaring-for, unpacked-struct, qualified class-property, and subroutine argument/return contexts. Source provenance survives arrays, concrete type parameters, forward/package typedefs, and lexical `type(expression)`, so virtual-interface ports, interface items, and union members are errors while ordinary interface ports remain legal. `==`/`!=` compare null, equivalent unparameterized VIFs, and same-definition concrete instances in either order, including constant one-dimensional instance-array and same-type conditional forms; VVP uses bound-instance identity and ordinary classes keep pointer identity. Case/wildcard equality, scalars, different interface definitions, and two concrete instances are errors. A run-time-variable select from an unqualified one-dimensional interface-instance array is separately pinned as an intentional compatibility extension, not §25.9 conformance, because 23.6 requires the instance-array select in a hierarchical name to be constant. Remaining boundaries include parameter-specialization and modport-aware comparison identity, nondefault parameterized VIF member widths, hierarchical/multidimensional run-time dispatch, exact expression-result edge semantics for run-time-selected words, virtual-interface handle rebinding while a wait is armed, streaming/`inside`/assignment-pattern dependency shapes not reached by the standard input traversal, and non-signal VIF members. **Fixed in M14:** `$display` of a continuous-assign-driven interface member. |
| 26 | Packages | PROVISIONAL (probed subset) | decl, `import pkg::*`/`import pkg::item`, typedef/param/function/class members, `::` resolution, `std::`, chained refs, ambiguous-import detection. Corners: a wildcard-imported typedef used as a type name; `export pkg::*` re-export (diagnosed). |
| 27 | Generate constructs | PROVISIONAL (probed subset) | generate for (genvar), if/else, case, nested, named blocks + hierarchical access, module/assign/always instantiation, `generate`/`endgenerate`. Invalid or nonterminating constant generate loops preflight their genvar sequence before allocating any generated scope trees, preserving the duplicate-scope and 500001-iteration diagnostics with bounded memory. |
| 28 | Gate- & switch-level modeling | PROVISIONAL (probed subset) | all primitive gates, tristate (`bufif`/`notif`), MOS (`nmos/pmos/cmos` + resistive), `pullup`/`pulldown`, `tran`/`tranif`, drive strengths, gate delays, instance arrays. |
| 29 | User-defined primitives | PROVISIONAL (probed subset) | combinational & sequential (level+edge) UDPs, UDP `initial`, instantiation, table syntax. |
| 30 | Specify blocks | SUBSTANTIAL | **M13.** Module path delays (`=>`/`*>`), edge-sensitive/state-dependent paths, `specparam`, and the recorded `PATHPULSE$` subset are active with `-gspecify`. Pulse controls and exhaustive path-form coverage remain open or diagnosed. |
| 31 | Timing checks | SUBSTANTIAL | The recorded checker subset, including `$setup/$hold/$recovery/$removal/$skew/$period/$width/$setuphold/$recrem/$nochange/$timeskew/$fullskew`, is runtime-verified under `-gspecify`. Exhaustive edge-descriptor, timestamp/timecheck-condition, and interaction coverage remains open. |
| 32 | Backannotation (SDF) | PARTIAL | `$sdf_annotate` applies IOPATH delays with `-gspecify`; inert (loud warning) without it. Corner: only the first two arguments (file, scope) are used (diagnosed via warning). |
| 33 | Configuring the contents of a design | DIAGNOSED | `config`/`endconfig` (+ `design`/`liblist`/`instance`/`cell`) parse and are skipped with an explicit sorry; the design elaborates with default bindings. Library-map files are not parsed (syntax error). |
| 34 | Protected envelopes | PARTIAL | `` `pragma protect `` begin/end and `` `protect ``/`` `endprotect `` around **plaintext** compile and run (the envelope is transparent). Encrypted envelopes are not supported (no decryption). |
| 35 | Direct programming interface (DPI) | SUBSTANTIAL | libffi-exact `import "DPI-C"` task/function marshaling includes integer atoms, scalar bit/logic, scalar shortreal/real, chandle/string, output/inout, packed vectors, and the recorded fixed/open multidimensional arrays. Signed/unsigned byte/short-int and enum-base returns preserve the Annex H ABI; shortreal uses C `float` in every scalar direction/result, and scalar logic preserves 0/1/Z/X. H.8.9 result legality is checked before every import/export target. Export stubs use exact integer/scalar bit-logic/shortreal/real/chandle/string/void C types, packed bit/logic vector formals, and scalar copy directions; every exported task has the H.8.2 `int` C result. Identical cross-scope/multi-instance exports share one stub; duplicate local linkage names, repeated exports of one SV subroutine, and incompatible cross-scope signatures (including packed dimensions/bounds) are rejected. Its §35.9 status is 0 on normal completion and on a disable targeting only that export, and 1 when an ancestor disables the mixed-language call chain. The ancestor path resumes the parked C stack exactly once for cleanup: `svIsDisabledState()` reports 1, a checked imported task acknowledges by returning 1, or an imported function calls `svAckDisabledState()` before return; neither disabled SV tail executes. Protocol mismatches and a §35.9(d) post-disable export call are fatal. Newly compiled tasks use `%dpi/call/task/ack`; legacy `%dpi/call/task` retains its void ABI for normal old images and diagnoses a disabled call. Packed-vector function results remain illegal under H.8.9; output/inout string storage survives automatic-frame teardown. The sized import-array subset follows the commercial direct-pointer ABI used by VCS, Questa, and Xcelium; open formals retain `svOpenArrayHandle`, and those commercial simulators remain the ABI interoperability target rather than Verilator. Time-consuming task bridges use POSIX `<ucontext.h>` or Win32 Fibers. Remaining loud legal gaps are imported shortreal arrays and fixed-size unpacked export formals; exported open arrays and class-handle formals are diagnosed as IEEE-illegal. The exhaustive signature/runtime cross-product remains M14B-9 work. |
| 36 | Programming language interface (VPI) | SUBSTANTIAL | **M12 CLOSED for the recorded object-model scope.** Typed variables with value-change callbacks, dynamic arrays/queues/assoc with element access, class member navigation, interfaces/modports/packages as scopes, and live covergroup handles are supported. A property-aware handle may read an integral or string virtual-interface property. Its `vpi_put_value` path is deliberately read-only/write-loud: writing reports a run-time error, sets a failing status, and leaves the VIF property unchanged because a direct put would bypass 14.13 sampling, 14.16 clocking-output scheduling, or 25.5 modport direction. Ordinary class-property puts remain supported. The bundled VPI suite and dedicated VIF-write, class-event-lifetime, declaration-lifetime, and array-word-lifetime reducers pass. |
| Annex A | Formal syntax | N/A | Reference grammar. |
| Annex B | Keywords | PROVISIONAL (probed subset) | keyword sets gated by generation (`` `begin_keywords ``). |
| Annex C–L | (packages, tasks, misc annexes) | PARTIAL | `std::` semaphore/mailbox/process supported; `std::mailbox#(T)` via the `std::` prefix is a syntax error (bare `mailbox#(T)` works). |

## 2026-08-26 clauses 7 and 10 associative-pattern refinement

Clauses 7 and 10 remain **PARTIAL**. For the directly evidenced 7.4, 7.9.11,
and 10.9.1 subset, a nonempty associative-array assignment pattern may contain
explicit constant string, integral, or enum keys and at most one `default`.
Keys are converted in the declared index context before duplicate detection;
duplicate keys/defaults, nonconstant or X/Z integral keys, and incompatible
key/value categories are errors. The default is fallback state rather than an
entry. Items evaluate once in lexical order into a fresh typed value, and the
destination changes only after the complete right-hand side exists. Whole
maps and value elements copy independently; class elements retain handle
identity.

Paired positive and negative reducers exercise declaration, procedural,
typed/cast-pattern, argument, return, and conditional contexts plus exact
OpenTitan enum-to-string, enum-to-queue, nested-map, and fixed-prefix forms.
The direct signal-backed fixed-unpacked subset, ending in integral/string/
real-valued associative leaves, preserves nonzero/descending and mixed
multidimensional ranges, independent slots, selected-map methods, and
invalid-outer-index no-op stores with once-only RHS evaluation. Every fixed
dimension is checked before flattening, so multidimensional OOB components
cannot alias valid siblings through whole-map or entry stores, entry reads, or
map methods. Explicit/default real reads, direct stores, sibling isolation,
and constant/variable outer selectors are paired. Packed bit/part/member and
other deeper or partial entry tails, property/member and struct-nested
receivers, fixed queue/dynamic-array leaves, fixed-prefix maps with
class-handle/container/struct values, broader receiver/value contexts, and
exhaustive clause closure remain open or loud.
This checkpoint supersedes only the earlier statement that arbitrary
associative constant-expression keys were wholly unimplemented; it does not
close the separate simple/user-defined type-key or general assignment-pattern
residuals.

## 2026-09-04 hierarchical state foreach (bounded increment)

The new inline class-constraint path covers a selected caller/package owner
whose queue/dynamic-array member holds class handles or unpacked structs,
with integral fields up to 64 bits. It preserves iterator type/scope and guard
errors (IEEE 1800-2017 18.5.8.1/18.5.13; IEEE 1800-2023 18.5.7.1/18.5.12),
including empty queues, null owners, typed ternary indices, and failed-solve
rollback. Independent rand-array foreach templates retain their original
size/element passes. Target-root/selectors requiring additional resolution,
nested hierarchical templates, and broader paths remain diagnosed. Clause 18
remains **PARTIAL**; application counts require the complete census diff.
See the [implementation, boundaries and validation record](../session_logs/2026-09-04_hierarchical_state_foreach.md).

## 2026-08-24 clause-18 signed fixed-array index repair

For the evidenced 18.5.8.2 subset, typed signed constants used to index a
fixed-array class property in a constraint are sign-extended before
declared-to-canonical index mapping. Negative declared indices therefore
retain every solver leaf and agree with `iterator.index()` reduction
semantics. `sv_constraint_fixed_array_reduction` pins the individual leaves
and their weighted reduction result.

## 2026-08-24 clause-18 expression-subject distributions

For the evidenced unguarded IEEE 1800-2017 18.5.4 subset (renumbered 18.5.3
in IEEE 1800-2023), the evidenced HMAC relational `dist` subject is converted
from Z3's Bool representation to its SystemVerilog one-bit integral value
before branch matching. Exact probability-proportional selection now also
applies to the recursively validated active expression subset, not only a bare
random property; the sampled expression value is pinned before ordinary model
diversity chooses the participating properties. Pin comparisons retain the
branch comparison width, while arithmetic subjects retain the wider physical
solver sort needed for carry/product headroom.

The accepted compared-expression subset includes typed terminals, packed bit
selects, constant part selects, ordinary packed concatenations, direct
`$countones(terminal)` and `$countones(~unsigned_terminal)`, terminal
comparisons, and conservatively typed `+`, `-`, and `*` trees. Unsigned
division and signed/unsigned modulus by a constant nonzero terminal are
accepted when the dividend is explicitly bounded to its SystemVerilog result
width. Direct add/multiply, signed subtraction, unsigned division, modulus,
and non-widened unsigned unary bitwise-not remain supported roots. Ground
comparison, ternary, add/subtract/multiply/divide/modulus, power, shift, and
XOR expressions fold at their SystemVerilog result width before shape
validation. Constant repeated concatenation folds when its complete result is
at most 64 bits. A compared bare fill literal and the OpenTitan
`'1 - integral_literal` endpoint shape are materialized at the subject's
comparison width when that width is at most 64 bits. Other context-dependent
unary, ternary, power, shift, and binary-bitwise trees remain loud rather than
being interpreted with an invented context. Signed constant occurrences use
fresh aliases, so Z3 numeral hash-consing cannot leak signedness between equal
raw numerals.

The emitted distribution IR distinguishes `:=` from `:/`, while accepting an
unmarked historical range branch as `:/`. Exact ranges up to 256 members are
sampled item first and feasible member second: `:=` retains
`weight * complete_source_span` after pruning, `:/` retains one aggregate item
weight, and overlapping items contribute additively. Typed and open bounds use
the same IEEE 11.8.1 comparison order for the hard predicate, normalized
coordinate, and exact pin, including signed ranges crossing zero. Each source
weight may be at most `UINT_MAX`; checked aggregate totals may exceed 32 bits
and are accumulated through `uint64_t`. Item selection uses an unbiased
two-word 64-bit rejection ticket, followed by an unbiased member-index draw.
An aggregate-total overflow, over-cap range, wider weight, nonground item, or
mixed comparison order emits a bounded warning and preserves the hard domain
through the documented weighted-soft fallback.

Exact branch coordinates and current-object scalar value storage remain
bounded to 64 bits. A source literal or resolved constant in a dist
subject/item/endpoint/weight with nonzero or unknown bits above bit 63 is a
compile-time error because the textual IR cannot preserve those bits; a wider
value whose high bits are all zero remains representable. A wide ground weight
that fits `uint64_t` evaluates normally, while a result above `uint64_t` warns,
remains nonzero, and saturates only the fallback objective. Guarded class
distributions, scope `std::randomize`, and multiple distributions over one
subject retain their documented approximations.

An exhaustive scan of the pinned OpenTitan source found 714 direct `.sv`
`dist` locations across 253 files. The current subset accepts 579 and leaves
135 loud/unlowered sites: 132 require indexed-member or package/aggregate-array
value lowering, and three Darjeeling alert-handler sites require 77-bit fill
literal/runtime-coordinate storage. The two additional supported `.svh` dist
macro bodies have ten source invocation sites; preprocessor configuration
makes a single corpus-wide elaborated-node total misleading. The 72 indexed
Flash weight expressions occur inside 36 of the already-counted 117 Flash
indexed-subject sites. `sv_constraint_dist_boolean_subject`,
`sv_constraint_dist_wide_literal_fail`, and `run_dist_ir_compat.sh` pin the
implemented boundary.

## 2026-08-24 clause-16 endpoint-local refinement

The M9-16 bounded local-variable subset now permits a deterministic-prefix
assignment RHS to read a local assigned earlier on that prefix. Nonlocal
operands are sampled Preponed, and the local holes are evaluated from the
current antecedent attempt or consequence-obligation record on the assigning
edge. Calls over locals, selected-local objects, self/future/unassigned
dependencies, and unknown expression shapes remain loud. The same conservative
assignment-before-read boundary applies to every zero-inclusive continuation:
`##0`, `##[0:n]`, and `##[0:$]`; lower-bound-one continuations remain
supported. Antecedent endpoint acceptance contributes the once-per-checker/tick
StepSuccess event even for `|=>`, while success/failure callbacks retain their
per-resolved-obligation multiplicity.

## 2026-08-26 clause-35 DPI disable-protocol refinement

| Clause | Boundary | Disposition / evidence |
|---|---|---|
| 35.8, 35.9(a), and H.8.2 | Exported-task C signature and simulator status | Generated task stubs are `int task_name(...)`, not `void`. They return 0 after ordinary completion and after a disable targeting the exported task itself; they return 1 when an ancestor disables the enclosing imported-subroutine chain. `run_dpi_disable_protocol.sh` asserts the generated C source as well as behavior. |
| 35.9(a)–(c) | Foreign cleanup and acknowledgment | A parked imported-task coroutine owns its call-state record across suspension. An ancestor disable resumes that C stack exactly once with `svIsDisabledState() == 1`, allowing cleanup before the task returns 1; a disabled imported function calls `svAckDisabledState()`. Direct-export disable leaves the import normal, and simultaneous normal/disabled stacks retain independent state. The scheduler retains the caller and completed child through resume so C may legally re-enter a synchronous export that disables the caller before the original resume frame unwinds; it also installs that caller as `running_thread` while C executes, preserving caller-specific automatic VPI context. `m10l_dpi_disable_protocol_test` checks all of these paths, including two concurrent resumed-C VPI writes and ancestor cleanup while the caller owns an outstanding branch that survived `join_any`, after outliving the killed SV delays. |
| 35.9(b)–(d) | Mandatory protocol enforcement | `%dpi/call/task/ack` invokes new imported-task C code with the integer ABI and validates 0 for normal or 1 for disabled return. A mismatched task return, a disabled imported function that omits `svAckDisabledState()`, and any further export call after the disabled state begins issue fatal simulation errors. `run_dpi_disable_protocol_negatives.sh` pins the four expected-fatal cases and verifies that no forbidden tail executes. |
| 35.9 and VVP image compatibility | Pre-protocol imported-task bytecode | `%dpi/call/task` remains the legacy void-call opcode rather than being reinterpreted as an integer return. `run_dpi_legacy_task_void_compat.sh` loads a hand-pinned old image and C void function normally, then derives a historical-opcode disabled image from current export metadata and requires the fatal no-ack-channel diagnostic instead of a guessed status. |

This closes the recorded disable-handshake submatrix, not clause 35 as a
whole. Imported shortreal arrays and legal fixed-size unpacked export formals
remain loud gaps, and M14B-9 still owns the exhaustive signature/runtime cross
product. VCS, Questa, and Xcelium remain the practical Annex-H interoperability
oracle after the IEEE text; Verilator was not used as an ABI oracle.

## 2026-08-25 OpenTitan event, Preponed, and packed-index refinement

| Clause | Boundary | Disposition / evidence |
|---|---|---|
| 4.4 and 16 | Preponed reads of resolved strength nets | `%hist/on` retains a full vec8 driven-value snapshot once per time slot and `%load/preponed` reduces that saved value on read. Force overlays remain outside driven history. The exact reducer plus 57/57 legacy and 16/16 JSON/VVP assertion focuses pass. |
| 7.4 and 11.5.2 | Run-time outer packed element index followed by an indexed part select | Every dimension's element index is normalized at width one before the residual packed width is applied as a stride. Singleton `[0:0]`, ascending, and descending outer dimensions with run-time `+:`/`-:` inner bases are permanent legacy and JSON/VVP regressions. |
| 9.4.2 and 9.4.3 | `@(object.property)` and `wait(object.property)` through a selected owner | The armed owner expression is evaluated once; mutation wakeup is filtered by property, fixed-array word, and optional packed bit, with same-value suppression, invalid-selector parking, retained owner lifetime, and cancellation-safe unlinking. Class-only compound waits re-evaluate. **Refined 2026-08-30:** an explicit `or`/comma event list may mix an independently prepared class-property or VIF-member leaf with ordinary signals, named events, run-time-selected event-array elements, and direct/default/global clocking events. Isolated join-any lowering resumes once and cancels every losing registration without killing an unrelated detached child; each leaf elaborates once and a rejected leaf diagnoses once. A single leaf whose expression itself combines VIF and class/ordinary dependencies remains loud. A class-only compound `@` filters scheduled wakeups against an arm-time snapshot, but a complete expression that changes and restores before that waiter runs can still be missed. Root/handle replacement, associative delete/rekey, and key/index mutation while armed remain unclaimed. |
| 13.5.2, 35.5.6.1, and Annex H | Sized fixed unpacked arrays across DPI | Sized formals use the commercial direct C-pointer ABI; open formals use `svOpenArrayHandle`. Scalar `svBit`/`svLogic` and packed `[0:0]` stay distinct, X/Z and output/inout copy back, multidimensional C storage is numeric-low-first/rightmost-fastest, and actual/formal copies map declared left to declared left per dimension. The backward-compatible 24-bit VVP element-width descriptor is tested at 256 and 384 bits. The exact OpenTitan SHA-384 ABI plus eleven controls pass 12/12 REAL DPI. Pure DPI is loaded with `vvp -d`; `-m` remains VPI-only. |

Full mechanism, boundary, OpenTitan replay, and Apple Silicon invocation
evidence are in the [session log](../session_logs/2026-08-25_opentitan_class_events_resolved_preponed_packed_index.md).

## 2026-08-24 clause-18 unpacked-struct constraint-leaf refinement

For the evidenced one-level scalar integral/enum subset, inline target-member
lookup precedes same-named caller state, including
`randomize() with (identifier_list)`. Explicit `this.record.member` and
`super.record.member` paths retain their inherited outer-property identity.
`disable soft record.member` disables only that leaf, while
`disable soft record` covers its descendants. Signed constant folding keeps
the declared width through unary and binary arithmetic before solver
write-back. A fixed- or dynamic-array index on the class receiver in
`items[index].record.member.rand_mode()` is distinct from an indexed outer
record: setter/query select that object exactly once, preserve adjacent-object
mode isolation, and retain Icarus's established disabled-query/setter-no-op
behavior for out-of-range or null receivers. Indexed outer records, deeper paths,
aggregates, and leaves wider than 64 bits remain focused compile-time
diagnostics rather than falling back to an unrelated terminal property name.

## 2026-08-24 clause-16 strong-action target correction

When an unbounded strong assertion needs a copied end-of-simulation action,
the supported task/void-function-call subset now retains package
qualification. `pkg::report(...)` remains that exact target rather than
becoming an unqualified lookup in the synthesized checker scope. The
self-checking package-action reducer is red against the prior compiler, and
the unmodified OpenTitan TL-UL checker loses all four corresponding
unknown-task warnings.

## 2026-08-24 clocking static-skew, modport, and VPI audit refinement

This refinement records the exact supported or loud boundary. For this dated
2026-08-24 refinement, the listed focus, broad, VPI, negative, UVM, OpenTitan,
and Caliptra reruns were completed; they are not the current corpus status.

| Clause | Boundary | Disposition / evidence |
|---|---|---|
| 14.3–14.5 | Clocking declarations, input/output skew, and declaration-assignment aliases | Static and VIF waiters observe numeric-skew samples only after their stores. Output skew is evaluated in the clocking block's defining scope by the shared apply process. A nonconstant output skew is one declaration error independent of the number of drives. A selected declaration-assignment target that cannot own whole hidden storage is loud. |
| 14.13 | Input sampling and VIF property reads | Packed integral/struct inputs use the sampled property; numeric `#0` and `#N` ordering is pinned. A read-only VPI consumer may fetch the property. Non-vector and unpacked inputs retain the documented loud alias boundary. |
| 14.16 | Clocking-output storage and scheduling | Constant packed member/bit/part selections retain one buffer and per-bit pending mask for same-scope, static-instance, alias, and VIF spellings. Current-event drives kick that instance's apply process. A run-time selector, root or nested indexed class receiver, whole unpacked output, or unrepresentable selected declaration target is rejected before ordinary NBA lowering. A concatenation/pattern l-value containing a clockvar is illegal. |
| 25.5 | Exact modport provenance | The qualifier and source clocking-block name survive direct, typedef/array, class-property/inheritance, class-type-parameter, unpacked-struct, and generated clocking-state carriers. Negative reducers require exact one-per-source visibility diagnostics. |
| 36 with 14.13/14.16/25.5 | VPI-backed system-call argument | Property reads remain supported. Any `vpi_put_value` to a virtual-interface property is a loud run-time error with unchanged state and nonzero status; this includes `$value$plusargs` directed at a sampled input, clocking output, or modport input. |

Historical 2026-08-24 post-audit results: both clocking focuses 36/36; clocking Slang differential
59/59; SystemVerilog manifest 1850/1850; JSON/VVP manifest 918/918; default
legacy manifest 4029 pass / 2 NI / 3 EF / 0 fail; VPI 97/97; negative
diagnostics 111/111; `make check` pass; real-DPI UVM 338/338; fresh
OpenTitan setup + compile 7/7 with six long runtimes advancing to the CPU
guard and ADC retaining its known testbench fatal; and Caliptra Icarus 53/105
versus Slang 54/105 with zero `ICARUS_GAP`.

The ignored local references are
`docs/standards/local/IEEE_Std_1800-2017.pdf` and
`docs/standards/local/IEEE_Std_1800-2023.pdf`; hashes and provenance belong in
the ignored local manifest. They are not part of the repository change. This
file remains the 2017 baseline, paired with the first-class 2023 survey and
tests.

## 2026-08-23 verified fixed-container property subclauses

These rows refine the coarse clause 7 and 8 entries above. They describe the
implemented and runtime-verified boundary; the deliberately loud residuals
mean neither parent clause nor this subset is upgraded to `FULL`.

| Clause | Title | Disposition | Evidence / notes |
|--------|-------|-------------|------------------|
| 7.4 | Fixed-size unpacked arrays above container leaves | PARTIAL | **Fixed/verified subset.** A direct non-static instance-class property may have one or more ascending, descending, nonzero-based or multidimensional fixed unpacked dimensions above a queue or associative-array leaf. The fixed prefix is atomically range-checked and canonicalized separately from trailing container indices, and each slot has independent storage. Whole-outer assignment decomposes in declared order and value-copies every selected container. Undefined, negative-after-canonicalization, wide-unsigned and out-of-range outer indices take the type-appropriate empty/default read path and make writes/mutators warned no-ops rather than aliasing slot zero; this includes scalar integral/bit, real, string, class-handle and unpacked-struct properties plus packed read-modify-write, with every dimension and RHS evaluated once. Direct dynamic-array leaves, signal-backed/static declarations, struct-nested fixed-container properties and whole-outer r-value materialization remain loud. The new 15/15 legacy and 15/15 split focuses, complete 1,792/1,792 and 860/860 manifests, Slang differential, and final OpenTitan blocker replay are recorded in the [session log](../session_logs/2026-08-23_opentitan_fixed_array_container_class_properties.md). |
| 7.8–7.10 | Associative arrays, methods and queues below a fixed property prefix | PARTIAL | **Fixed/verified subset.** A fully selected queue/map leaf supports whole-container value assignment, context-typed element/key reads and writes, queue/associative methods, r-value queue slices, `$` reads/method receivers, and packed element selects. Runtime lowering covers integral, real, string, class-handle, aggregate and nested-container values, preserves bounded inner-queue copy, and avoids duplicate evaluation of the selected queue receiver used for `$` and the fixed outer index. A bare fixed-array RHS is materialized in declared order as the destination queue kind and bound. Associative vivification inserts nil dynamic-array children without manufacturing queues, notifies the outer root on insertion, and preserves root provenance for later child mutation. Arbitrary trailing queue/associative/dynamic-array chains retain recursive receiver typing and value-copy behavior; selected nested dynamic arrays support `delete()`. Whole-outer r-value reads, fixed-property queue-slice l-values, `$` l-values, incomplete fixed prefixes, direct property selection from a function-call result, and packed/compound whole-container assignment remain loud. The final unmodified OpenTitan replay contains zero occurrences of the former array-of-queue rejection and reaches independent later blockers; it is not an OpenTitan pass claim. See the [session log](../session_logs/2026-08-23_opentitan_fixed_array_container_class_properties.md). |
| 8.5 | Object properties containing fixed arrays of queues/maps | PARTIAL | **Fixed/verified subset.** The admitted shape is a direct non-static data property: VVP class storage constructs one independent queue/map object per fixed slot in every class instance, and selected leaves retain container value semantics while class-handle elements retain handle identity. Scalar and selected fixed-slot queue properties accept a bare fixed-array RHS as an independent queue value, including declared-order conversion and bounded truncation. Positive runtime reducers, invalid-index oracles, exact negative diagnostics, both complete ivtest manifests, and the OpenTitan witness replay verify this boundary. Static class properties use signal-backed storage and remain a focused `sorry`; the same is true for a fixed queue/map array nested inside an unpacked-struct property. No randomization, `ref`, VPI, synthesis or OpenTitan-runtime closure is claimed. See the [session log](../session_logs/2026-08-23_opentitan_fixed_array_container_class_properties.md). |

## 2026-08-24 queue range expressions and dynamic-array result boundary

| Clause | Title | Disposition | Evidence / notes |
|--------|-------|-------------|------------------|
| 7.4.5, 7.4.6, 7.6 | Dynamic-array slice result and assignment typing | PARTIAL | **Fixed/verified direct blocking colon-assignment subset.** `dst = src[left:right]` now gives a direct one-dimensional plain dynamic-array signal slice its required fixed-size `netuarray_t` result when both fully defined constant bounds follow the implicit ascending direction and source/target element types are equivalent. Assignment maps elements left-to-right, resizes the dynamic target, preserves two-/four-state, real, string, class-handle, and unpacked-struct values (including nested dynamic members), returns the element default for OOB source indices, and snapshots a self-slice before replacing its destination. Source coordinates are exact signed 64-bit constants while the synthetic fixed result uses canonical `[0:count-1]`, preserving LP64 values without imposing them on LLP64 `netrange_t`. VVP reloads each destination index after evaluating its leaf, bounds-checks wide object reads before the unsigned storage API, and retains an unpacked-struct element prototype so partial/all-OOB defaults survive a class-property container copy; class handles retain identity and null defaults. Slang 11.0.448 accepts the shared positive source under 1800-2017 and 1800-2023; its signed-32-bit dynamic-index restriction is isolated behind the Icarus-only wide-index checks. Focused legacy and JSON gates pass 15/15 and 10/10; the unmodified OpenTitan HMAC graph moves from one hard line-82 error to compile exit 0. Legal indexed-variable, property/nested, fixed-target, standalone/type-query, multidimensional, delayed/NBA, compound, and unpacked-union-element forms remain loud or unclaimed. The union boundary is a focused `sorry` rather than exposing the current X initialization where Table 7-1 requires the first member's default, and does not claim broader union runtime semantics. Illegal bounds and inequivalent elements retain exact errors; associative ranges remain illegal. See the [HMAC session log](../session_logs/2026-08-24_opentitan_hmac_dynamic_array_slice_rvalues.md) and the earlier [queue boundary log](../session_logs/2026-08-24_opentitan_usbdev_variable_queue_slices.md). |
| 7.10.1 | Queue colon and indexed range expressions | PARTIAL | **Fixed/verified r-value subset.** `Q[a:b]`, `Q[base +: width]`, `Q[base -: width]`, and, as of 2026-08-30, `Q[$:hi]` accept the recorded integral run-time operands and evaluate the receiver and each explicit operand exactly once. The IEEE text explicitly grants arbitrary operands to queue colon bounds; applying that exception to indexed queue ranges is the Slang-compatible interpretation recorded here, not an unqualified 7.10.1 claim. Colon endpoints clamp to the live queue; reversed or X/Z ranges are empty. For `Q[$:hi]`, `$` is derived from the already-evaluated source's live last index: an exact or above-last `hi` returns the final item, while a lower/reversed or X/Z bound and an empty source return an empty queue. Indexed ranges normalize into ascending queue order, clamp without over-allocation, and return empty for an X/Z base or a nonpositive/X/Z width. Every slice has an **unbounded queue** result even when the receiver is bounded, remains container-valued through nested/property/static/method/untyped-display and streaming paths, and value-copies nested container elements while retaining class-handle identity. The earlier range focus gates and application evidence remain historical; the new left-`$` rows pass 6/6 in each paired legacy and JSON/VVP path and do not add an application replay. Queue-slice l-values, including `Q[$:hi]`, and an indexed `+:`/`-:` selector whose base is the `$` token remain separate loud parser/lowering boundaries. See the [2026-08-24 range log](../session_logs/2026-08-24_opentitan_usbdev_variable_queue_slices.md) and the [2026-08-30 follow-on](../session_logs/2026-08-30_virtual_interface_event_list_queue_slice.md). |

## 2026-08-24 fixed class-property unpacked-array slice l-values

This refinement makes the clause-7 matrix row's older “class/property slice
value” residual precise: property-slice **r-values** remain open, while the
direct blocking pattern-lvalue subset below is implemented.

| Clause | Title | Disposition | Evidence / notes |
|--------|-------|-------------|------------------|
| 7.4.5, 7.4.6, 7.6, 8.5, 10.4, 10.9.1 | Fixed class-property unpacked-array slice l-values | PARTIAL | **Fixed/verified direct blocking pattern subset.** A final in-range constant colon or constant-base `+:`/`-:` range on a direct non-static one-dimensional fixed unpacked-array property retains a fixed-size unpacked-array l-value type. A simple assignment pattern is context-typed by that selected range and maps elements left-to-left in declared order. The complete RHS is captured before any property word changes, so overlap has snapshot semantics and words outside the range remain unchanged. Permanent tests cover OpenTitan's `exp_digest[8:15]` and `[12:15] = '{default:0}`, ascending/descending and negative/nonzero ranges, indexed polarity, packed integral, real and string elements, receiver evaluation, and overlap. Slang 11.0.448+e222e7dc0 accepts the source under both IEEE 1800-2017 and 1800-2023 and gives the selection and contextual pattern the same fixed-array type. Runtime indexed bases, multidimensional or typedef-nested property slices, property-slice r-values, NBA and non-pattern/compound stores, and aggregate/object elements remain loud or unclaimed. Compile-time out-of-range rejection is a current strict implementation boundary, not an additional IEEE conformance claim. Parent clauses remain `PARTIAL`. See the [session log](../session_logs/2026-08-24_opentitan_dma_fixed_property_slice_lvalues.md). |

## 2026-08-24 implicit randomization hooks

| Clause | Title | Disposition | Evidence / notes |
|--------|-------|-------------|------------------|
| 18.6.2 | `pre_randomize()` and `post_randomize()` | PARTIAL | **Fixed/verified default-body subset.** Every completed class hierarchy now supplies the standard's implicit zero-argument empty hook when no declaration exists. Ordinary, implicit-`this`, explicit-`super`, and arbitrary receiver-expression calls are supported, and an empty hook still evaluates its receiver exactly once. Parsed user declarations retain normal method resolution; nonzero argument lists are errors. The dual-harness reducers, Slang differential, complete 1,796/1,796 and 864/864 manifests, and unmodified OpenTitan DMA replay are recorded in the [session log](../session_logs/2026-08-24_opentitan_implicit_randomization_hooks.md). Recursive child hook dispatch and the other clause-18 boundaries remain open, so clause 18 remains `PARTIAL`. |

## 2026-08-14 sv-tests class-type closure

- **Clause 6:** an unused typedef is now declaration-validated when its type
  graph contains explicit dimensions, and an unresolved forward typedef is
  diagnosed once even when never referenced. Resolved forward declarations
  and parameter-dependent module/class typedef widths remain legal. Evidence:
  `sv_typedef_eager_{valid,invalid_width_fail,unresolved_forward_fail}`.
- **Clauses 8 and 25:** class type-parameter defaults accept both
  `virtual iface` and `virtual interface iface`, including forward interface
  names, explicit modport suffixes, and unresolved defaults that are never
  selected. An explicit known non-interface name is rejected; an overridden
  missing default remains lazy, while a concrete property, signal, or return
  type that selects it is diagnosed exactly once. Evidence:
  `sv_typeparam_virtual_interface_{default,default_override,explicit_modport,
  known_noninterface_fail,default_use_fail}`.

## M14 gap closures

The audit found six remaining **silent** gaps (constructs that compiled
but produced a wrong result or no effect with no diagnostic). All are
closed:

**Fixed (real implementation):**
1. **`case (x) inside` range matching** (12.5.4) — range items collapsed
   to their lower bound; interior values never matched. Now lowered to
   the `inside` membership operator (ranges, comma-lists, singles, array
   membership). `parse.y` + `pform.cc` (`pform_make_case_inside`, guard
   duplicator).
2. **Module-static integer-keyed associative-array value read** (7.8) —
   a module-scope `int m[int]` stored via `%aa/store` but read via a
   positional darray load, always returning the default (class-member
   assoc was fine). Added the integer-key assoc read branch in
   `tgt-vvp/eval_vec4.c`.
3. **Width-1 class-property `$display`** (8) — a 1-bit `bit`/`logic`
   property took a pass-object-handle fast path (its width equalled the
   object-handle width) and printed garbage; the value itself was
   correct. Class data properties now always evaluate to a temp
   (`tgt-vvp/draw_vpi.c`). The same fix corrected `$display` of
   continuous-assign-driven interface members (clause 25).
4. **`checker`/`endchecker`** (17) — a bare "syntax error" that aborted
   the whole parse is now an explicit sorry with error recovery, so the
   rest of the source still compiles (`parse.y`).

**Converted to loud diagnostics (implementation deferred):**
5. **`randcase`** (18.16) — was a silent empty block (no branch ran);
   now a loud sorry.
6. **`std::randomize(var)` scope form** (18) — returned success while
   leaving the variable unchanged; now emits a loud one-time warning
   (kept non-fatal because UVM DV uses it as a success predicate).

## Recorded corners (M14 follow-up ledger)

- `$typename` canonical-form output; `%p` on integral aggregates.
- string/real-VALUED integer-keyed assoc reads; `int a[*]` wildcard-key
  declaration.
- Function returning an unpacked-array typedef via `'{...}` assigned as a
  whole array: no longer aborts — now a graceful `sorry` (the vvp calling
  convention still lacks an unpacked-array return path; full support is
  issue #99). The nested-literal-into-array-of-packed-struct abort is
  resolved: module-scope literals work and the class-property whole-array
  pattern store no longer silently zero-fills (issue #97 family). A
  distinct, still-open defect: class-property unpacked arrays of
  `real`/`string` store every element to one slot (issue #100).
- net `alias`; `wait_order`; `randsequence`;
  `unique{}` constraint; `disable soft`;
  `if/case (x matches p)` binding.
- `virtual <iface> v;` as a bare module-scope variable; wildcard-imported
  typedef used as a type; `export pkg::*` re-export; `std::mailbox#(T)`.
- `rand_mode(0)` field freeze; `process.status()`/`suspend`/`resume`.
- shallow-copy inline static initializer `C b = new a;` at module scope.
- `$exit`, `extern module`, anonymous program, library-map files.
- timescale/timeunit conflict not diagnosed (3.14.3).

Each corner is a **loud diagnostic** (syntax error, sorry, warning, or —
for the two ICEs — an assertion abort) or a documented behavioural
limitation. None is a silent miscompile.

## 2026-08-27 clauses 6.16 and 11.4.12.2 typed string concatenation

The shared IEEE 1800-2017/2023 string-conversion and concatenation rules are
covered by paired `-g2017`/`-g2023` positive and negative regressions. This is
a bounded contextual-typing and runtime subset; clauses 6 and 11 remain
`PARTIAL`.

| Boundary | Disposition / evidence |
|---|---|
| String assignment context | FIXED. A concatenation assigned to a string parameter, fixed unpacked string-array element, procedural string variable, or equivalent typed consumer is elaborated with the complete destination type. The exact OpenTitan scalar and fixed-table path shapes are permanent runtime cases. |
| Operand categories from Table 6-9 | FIXED for the evidenced subset. String expressions and string literals compose as strings, including nested groups. An all-literal group is converted by its string context while the same source retains packed-integral meaning outside that context. An uncast integral-only concatenation is a focused error. A true string expression mixed with an uncast integral expression is rejected at the operator, including beneath a conditional or whole string cast; an explicit cast of that operand is the supported conversion request. In a generic class template, a direct formal/local/property whose parse-form type is an unresolved class type parameter defers this decision until specialization; `string` bindings pass and the paired concrete-`int` case remains a hard error. The retained `br_gh800` form is a narrow literal-only compatibility extension containing at least one string literal plus integral literals, not permission for an integral variable, select, call, or other expression. |
| String-producing calls and result types | FIXED for the pinned forms. Width/type probing retains the declared string result of a built-in method and of a zero-argument static function invoked without parentheses under 13.5.5. Direct and dependent `T::type_name` calls execute the declared function rather than substituting a synthetic class name. For data objects and constant string parameters, built-in results retain `int` for `len`/`compare`/`icompare`, `byte` for `getc`, `integer` for `atoi`/`atohex`/`atobin`/`atooct`, `real` for `atoreal`, and `string` for `toupper`/`tolower`/`substr`; a nested string concatenation can be a method receiver. Review hardening makes constant-parameter methods consume semantic bytes, preserving empty, nonprinting, backslash, and quote data instead of a rendered representation. A parentheses-free static class call in a constant `localparam` concatenation remains a current gap. Class-scoped invocation of a non-static method without an object remains a pre-existing wrong acceptance and is not included in the static-call claim. |
| Method receiver and arity checks | FIXED for the pinned data-object and constant-parameter paths. A selected character of a scalar string has `byte` type and cannot receive `.len()` or another string method, including through direct, struct, or class-property spelling; the diagnostic no longer dispatches on the unselected whole string. Built-ins require exactly 0 arguments for `len`/conversion/case methods, 1 for `compare`/`icompare`/`getc`, and 2 for `substr`. Missing or extra arguments are hard errors before call lowering rather than ignored/defaulted arguments or a post-diagnostic malformed call. Argument-type conversion remains separate: `s.compare(65)` is a pre-existing wrong acceptance. |
| Constant folding and explicit casts | FIXED. A contextually string-typed constant concatenation remains a string constant after folding, and integral-to-string conversion removes null bytes. A selected integral value evaluated through an explicit string cast reaches VVP's vector-to-string conversion and produces the selected character instead of an empty string. |
| Replication | FIXED for the evidenced shared 2017/2023 subset. Constant and run-time integral multipliers over string operands are runtime-pinned, including `{repeat_count{{"A", "B"}}}` in a direct string target, a whole string cast, and both comparison operand orders; a string-typed multiplier and a string replication assigned to an integral target are rejected. Zero and nonzero repeats evaluate their operand exactly once, and zero produces the empty string. Review hardening removes the arbitrary cutoff from new typed VVP images: a legal **1,048,576-byte** variable repeat passes, lowering preserves signedness, and negative, X/Z, or runtime-index-width failure is diagnosed. The unsuffixed opcode preserves its historical signed/copy-boundary behavior for old textual images and is pinned independently. Each repeat owns its VVP index word, so a bounded-queue RHS cannot corrupt its caller's live bound. Slang 11 rejects the standalone zero-repeat reducer because it permits zero only inside an enclosing concatenation; that narrow differential disagreement is recorded without changing the IEEE interpretation. |
| Direct `string[index]` operand | COMPATIBILITY EXTENSION only inside the documented concatenation. IEEE string indexing yields a byte, and Slang 11 rejects that byte directly inside the string concatenation. OpenTitan uses the spelling in commercial-simulator-targeted DV source, so Icarus admits only a final 8-bit select whose underlying object is string. An ordinary packed-vector byte select still requires `string'(...)`, and the byte cannot receive a string method. VCS, Questa, and Xcelium were not run for this increment. |
| Bounded residuals | PRE-EXISTING unless stated otherwise. A fixed-size unpacked signal-array string element retains its two-character value but direct `.len()` reports 1; dynamic arrays, queues, and a fixed array in a class property return 2 in the same probe. `s.compare(65)`, `{8'h41} == s`, and a non-static method called as `C::f` are accepted but rejected by Slang. The current branch still rejects a legal parentheses-free static call in a constant `localparam` concatenation; the baseline was already broken on that source by a different internal typed result. |
| Validation | Final gates pass **23/23 focused legacy**, **24/24 focused JSON/VVP**, **2,083/2,083 full legacy**, **1,161 full JSON/VVP entries with 0 failures** (1,144 executed/pass plus 17 NI), **136/136 negatives**, **103/103 VPI**, **6/6 textual VVP compatibility**, and **354/354 canonical real-DPI UVM** with 0 failures/skips. The clean canonical `origin/main` compiler at `6bfe64ce` reaches two internal typed-concatenation errors and then the `par_string` assertion on the expanded current positive reducer; the final compiler runs that exact source to `PASSED`. |
| OpenTitan application replay | Earlier same-branch authentic Darjeeling/Earlgrey top-chip replays, before final generic-class deferral hardening, move the internal typed-concatenation diagnostic counts from **10/18** to **0/0**. Both first report the independent queue-versus-dynamic-array context mismatch at `spi_agent_cfg.sv:139`, then traverse a much larger independent diagnostic graph before the compiler exits 139 without a VVP image. The final narrow deferral change has not been replayed across those tops. Neither top elaborates, and no new 61-target matrix has been run. |

Full mechanism and boundary detail is in the
[typed-string session log](../session_logs/2026-08-27_opentitan_typed_string_concatenation.md).


## 2026-08-27 clause-12 declaring for-loop refinement

IEEE 1800-2017 and IEEE 1800-2023 12.7 / 12.7.1, Syntax 12-5 including
footnote 14. Behavior is identical under `-g2017` and `-g2023`; every
regression below is registered as a 2017/2023 pair.

| Boundary | Disposition / evidence |
|---|---|
| Several `for_variable_declaration`s, each with its own `data_type` | FIXED. `for (enum_t e = e.first(), int i = 0, byte b = i + 1; ...)`. Previously only a single keyword-typed declaration parsed; a typedef-led list fell into error recovery, which warned and dropped the loop. `sv_for_decl_type_forms`. |
| Same-type declarator continuations | FIXED. `for (int i = 0, j = i + 3, k = j + 2; ...)`, with earlier declarations visible to later initializers. `sv_for_decl_type_forms`. |
| Package-qualified and class-scoped member types | FIXED. `p::regno_t`, `C::nibble_t [1:0]`, `p::C::word_t`, `C#(byte)::T`, `p::C#(byte)::word_t`. The class qualifier is retained as a separately owned type node, resolved and specialized before the member typedef elaborates in the resulting concrete class scope, so `p::C::word_t` keeps its 8 bits instead of widening to 32. |
| `var type(expr)`; bare `type(expr)` | FIXED / correctly rejected. Footnote 14 permits the type_reference form only under `var`. `sv_for_decl_bare_type_ref`. |
| Declarator name that shadows a visible typedef | FIXED. Declarators are installed at the first `;`, so the condition and step lex the name as IDENTIFIER. `for (int shadow = 0; shadow < 3; shadow++)` previously bound its condition to the type and never terminated. `sv_for_decl_scope_forms`. |
| Inline anonymous enum identity and non-leakage | FIXED. The implicit block opens before the data type is parsed. Sibling loops declaring `enum {A, B}` do not collide, and their literals do not reach the enclosing block. `sv_for_decl_scope_forms`. |
| Automatic control-variable lifetime in a static subroutine | FIXED. Two overlapping activations each record their own 0,1,2 sequence, while an explicitly static body local keeps its shared lifetime. `sv_for_decl_type_forms`, `sv_for_decl_scope_forms`. |
| Control-variable instance count | One automatic instance per loop entry, not per iteration, per 12.7.1. A detached child that outlives the loop reads the final value; a per-iteration body-local automatic keeps its own frame. Pinned by `sv_for_decl_scope_forms`. |
| Labeled implicit block | FIXED at module level: `loop2: for (int i = ...)` names the block, and `%m` and `disable loop2` resolve through it. This compiler reports no named block through `%m` from inside a subroutine (a plain `begin : name` behaves identically), so that is an unrelated pre-existing limitation, not a 12.7.1 boundary. |
| Duplicate declarators; unknown class member type; earlier initializer reading a later declarator | Correctly rejected with one focused diagnostic each and a non-signal exit. `sv_for_decl_dup_declarator`, `sv_for_decl_bad_member_type`, `sv_for_decl_after_use`. |
| Loop variable escaping after the loop | OPEN, and general rather than 12.7.1-specific. An assignment to a name that has left scope produces the SystemVerilog compile-progress warning and a zero exit, identically for a declaring for-loop, for a plain named block, and on the previous mainline. Non-escape is asserted semantically instead. |
| Synthesis of a declaring for-loop | A loop declaring exactly one control variable keeps the explicit index/initial-value pair and synthesizes as before. Several control variables have no single index; that is reported and rejected, and no longer segfaults. `sv_always_comb_for_null_index`. |

### Parser conflict state

535 shift/reduce and 1119 reduce/reduce, against 535/1115 on the merge base.
The four added reduce/reduce are the packed-dimension-versus-index decision in
the class-scoped initializer states; no other conflict state changed its item
signature. Conflict totals alone are insufficient evidence here: `'('` and
IDENTIFIER both carry declared precedence, so a decision between them is
resolved silently and is never counted. The acceptance criterion used was that
the state after `for (` contains exactly one item and reduces on `$default`.

## 2026-08-27 clause-23.11 bind target-instance paths

IEEE 1800-2017 23.11 and Syntax 23-9 permit a bind target instance to be a
hierarchical identifier with constant bit selections. The implemented and
permanently paired `-g2017`/`-g2023` subset is:

| Boundary | Disposition / evidence |
|---|---|
| Structured absolute and root-qualified paths | FIXED. Parsed components retain selections and lexical identity. Absolute paths, explicit `$root` entries, module/generate-relative dotted paths, and a package-localparam-selected loop-generate child resolve without a designwide terminal-name search. `sv_bind_indexed_relative_targets{,_2023}`, `sv_bind_explicit_root_target_list{,_2023}`. |
| One-dimensional generate and instance-array selection | FIXED. A descending `[3:1]` instance array and loop-generate scopes select exactly the requested elaborated element. Final as well as intermediate instance arrays require selection; an unselected final array is rejected. The bound actual observes the target's parameter, pinning target-viewpoint resolution. `sv_bind_indexed_relative_targets{,_2023}`, `sv_bind_target_unselected_array_fail{,_2023}`, `sv_bind_target_path_shape_fail{,_2023}`. |
| Conditional per-owner type and shape | FIXED. Same-named conditional/case alternatives resolve only through the active occurrence, including alternatives with different module/interface types and scalar-versus-array or generate-for-versus-scalar shapes. A missing select is diagnosed only for the active array occurrence. `sv_bind_conditional_different_types{,_2023}`, `sv_bind_conditional_{array_shape_fail,generate_shape,generate_scalar_shape}{,_2023}`, `sv_bind_interface_inactive_alternative{,_2023}`. |
| Declaration-scope activation, lexical identity, and per-owner expressions | FIXED. A contained directive exists only for each elaborated occurrence of its exact module/generate declaration. Inactive conditional/case arms, excluded roots, and uninstantiated owners neither attach nor report false misses. Nearest-generate lookup wins, and genvar/parameter-dependent selections are evaluated independently per owner. `sv_bind_owner_{generate_lexical,inactive_generate,inactive_invalid,excluded_absolute,loop_genvar_select,select_specialization_fail}{,_2023}`. |
| Deferred activation and source order | FIXED. Pending directives are reconsidered to a fixed point when owners or targets become available; direct and deferred ordering produces the same result. Active invalid owners diagnose, inactive ones do not. `sv_bind_owner_active_invalid_fail{,_2023}`, `sv_bind_fixed_point_owner_overlap_fail{,_2023}`, `sv_bind_fixed_point_target_{first,reversed}_fail{,_2023}`. |
| Bound-instance namespace and collisions | FIXED. The same introduced name is legal on disjoint concrete targets. Direct/direct, direct/list, multiple-owner, definition-name, and same-base array-instance overlaps on one target are focused errors. `sv_bind_same_name_{disjoint,target_overlap_fail,list_overlap_fail}{,_2023}`, `sv_bind_same_base_array_collision_fail{,_2023}`, `sv_bind_owner_{absolute_disjoint,absolute_overlap_fail,definition_collision_fail,duplicate_designwide_fail}{,_2023}`. |
| Declaration-scoped target-instance lists | FIXED for the evidenced structured subset. Absolute, explicit-root, declaration-relative, and selected one-dimensional entries use the same owner context and collision rules; invalid-first and invalid-last orders report consistently. `m13b_bind_instance_test`, `sv_bind_owner_scoped_target_list{,_2023}`, `sv_bind_explicit_root_target_list{,_2023}`, `sv_bind_target_list_invalid_{first,last}_fail{,_2023}`. |
| Target and origin legality | FIXED for the paired boundary matrix. Bind targets and target-list declarations are modules/interfaces, not checkers/programs. IEEE 23.11 permits only an interface or checker instantiation into an interface target; a module or UDP is rejected. UDP bound instantiations are rejected for module targets too, including a UDP type loaded only from `-y`; program/checker declaration origins are rejected, and checker declarations are not promoted to design roots. The internal M13 fixture was corrected module→interface to conform to the standard, not to preserve a compiler compatibility extension. `sv_bind_{interface_checker,interface_module_fail,interface_udp_fail,module_udp_fail,library_udp_kind_fail,checker_target_fail,program_instance_target_fail,target_list_scope_kind_fail,origin_scope_fail,checker_root_selection}{,_2023}`. |
| Library definitions and directives | FIXED with one documented root-selection policy. Pending binds are re-resolved when `-y` discovers a target definition or a container definition traversed by the target path. A loaded source may append a compilation-unit bind, whether reached during the initial compilation-unit closure or from a live contained bind; inactive/excluded owners never load or diagnose their dependency. Automatic roots account for the initial-closure case but are not retroactively rebuilt for the contained-owner case, which uses explicit `-s`. `sv_bind_library_{target,path,late_root,udp_kind_fail}{,_2023}`, `sv_bind_owner_{library_cu_closure,inactive_library}{,_2023}`. |
| Invalid selections and no-match | Correctly rejected. Dynamic, X/Z, host-overflow, out-of-range, scalar-selected, missing-selection, and absolute no-match forms are loud; the diagnostic outcome does not depend on invalid target-list entry order. `sv_bind_target_{dynamic_select,range_select,path_shape_fail,unselected_array_fail}{,_2023}`, `sv_bind_owner_nonroot_absolute_fail{,_2023}`. |
| Bind beneath a bound instance | Correctly rejected for direct/deferred target and owner creation in either source order; claiming or replaying a deferred directive cannot make the introduced hierarchy a legal target. `sv_bind_{owner_nested_first_fail,owner_nested_reversed_fail,nested_direct_first_fail,nested_direct_reversed_fail,nested_deferred_fail,fixed_point_target_first_fail,fixed_point_target_reversed_fail}{,_2023}`. |
| Direct nested generate collector | FIXED. A conditional-generate alternative that directly contains a generate-for contributes the selected lexical path. `sv_bind_conditional_{generate_shape,generate_scalar_shape}{,_2023}` permanently pin the two bind shapes; a plain non-bind nested-generate local smoke confirmed that the collector fix does not depend on bind side effects. |
| Bare target name | Resolved lexically from the containing generate/module, with a local instance taking precedence over a same-named module/interface type. The former designwide terminal-name compatibility search is removed. `sv_bind_target_instance`. |

The previous mainline rejects the positive selected paths in both editions.
The parser remains at 535 shift/reduce and 1119 reduce/reduce conflicts, with
no changed canonical conflicting item core relative to the post-declaring-loop
mainline.

The paired focused legacy and JSON/VVP harnesses each pass 110/110 on the final
native-ARM64 install. Full legacy passes 2063/2063, full JSON/VVP passes
1141/1141, negatives pass 136/136, VPI passes 103/103, and the real-DPI UVM
umbrella passes 354/354 with zero failures/skips.
No new full OpenTitan replay was made after the owner and fixed-point hardening;
the session log preserves the earlier replay only as historical frontier
evidence.

This is not clause-23 closure. Multidimensional module-instance arrays remain
outside the compiler's existing one-dimensional instance-array model.
Automatic roots are not retroactively recomputed for a compilation-unit bind
discovered only after a live contained bind loads a library; use explicit `-s`
for that exact-root case. An exhaustive clause-23 combination audit is still
required before a complete conformance claim.

## 2026-08-28 clauses 6.24, 7.6, 7.10.5, and 13.3–13.5 positional-container refinement

IEEE 1800-2017 and IEEE 1800-2023 have the same rules for this cluster. The
standard destination-typed copy and cast repairs and the separately labeled
OpenTitan interoperability extension share lowering without sharing a
conformance claim.

| Boundary | Status | Disposition / evidence |
|---|---|---|
| 7.6 positional unpacked-array assignment | FIXED for the evidenced value/copy contexts | Equivalent slowest-varying elements permit queue/dynamic-array cross-kind assignment. The target is resized from the source count and receives a fresh left-to-right element copy with its declared runtime kind. Only the slowest-varying dimension may differ in kind; paired task/function input/output/inout negatives reject `int[][]` versus `int[$][$]`, while a legal queue-of-dynamic-arrays control varies only the outer kind. Destination-typed collection splices apply compatibility again at their element boundary. Covered paths include direct signals, class properties, selected and nested properties, conditionals, function results, subroutine boundaries, queue methods, assignment patterns, object splices, nested containers, and unpacked-struct members. A real queue-to-dynamic assignment reaches atom-contiguous dynamic-array DPI storage instead of retaining a queue object. |
| 6.24.1 assignment-compatible explicit casts | FIXED for evidenced positional containers | An explicit queue/dynamic-array cast with equivalent elements materializes a typed temporary before an enclosing assignment or method can hide it. Same-kind and cross-kind real casts, a bounded destination, direct queue method use, conditional sources, value isolation, and complete nested-associative element equivalence (including key and wildcard metadata) are paired 2017/2023 regressions. A non-bit-stream real/integral mismatch is diagnosed once rather than inherited from an outer assignment context. |
| 6.24.3 non-assignment-compatible bit-stream casts | FIXED for the integral positional-container subset | Integral queue/dynamic-array elements may change width through a strict MSB-first pack/unpack when the complete source stream divides exactly into the destination element width. The byte-queue/word-dynamic-array round trip and independent destination kinds are pinned. A nondivisible source, a result larger than a bounded queue, or the existing bounded runtime-width guard returns a nonzero simulation status with a stable error and an empty result; strict casts do not borrow ordinary stream padding or bounded-assignment truncation. General recursive aggregate/class/structure bit-stream casts still use legacy paths and are not claimed by this row. |
| 7.10.5 bounded queues | FIXED for the evidenced assignment/copy/cast paths | Ordinary same-kind and cross-kind writes preserve the declared target bound, discard tail elements, and warn across assignment, function input/output/inout, aggregate, nested-container, and associative-value contexts. An assignment-compatible cast preserves a fitting bound, while an oversized strict cast fails instead of truncating. A direct strict cast carries a 64-bit bound and therefore handles the tested bound above `UINT_MAX` without wrap. Ordinary queue signal/method storage still has older unsigned-bound paths, so this is not general support for queue bounds above `UINT_MAX`. |
| 13.3.2, 13.4.2, and 13.5 native output lifetime/call semantics | FIXED for the evidenced queue/dynamic-array subset | Native output formals are copy-out only. Automatic task/function outputs begin at their declared empty default on every invocation; static task/function outputs retain private formal storage even when an explicitly automatic local requires a task call frame. Inout still copies in and out. Empty native bodies retain input side effects, frame/dispatch semantics, untouched output defaults, and copy-back. The caller-shape copy-in exception is confined to DPI imported open-array output formals; DPI queue/dynamic-array output acceptance remains an interoperability boundary. Task and nonvoid-function output/inout actuals are lvalue-checked and require equivalent positional-container elements; failed copy-in does not produce a second copy-back diagnostic. |
| 7.4.5, 7.6, 7.7, 13.5, and 35.5.6.1 fixed slice function actuals | FIXED for direct one-dimensional signal slices | A constant legal slice passed to a value-returning native or DPI function remains one aggregate value with its backing signal, exact storage window, element type, selected bounds, and direction. Native fixed and unsized formals copy input/output/inout elements left-to-right; automatic pure fixed outputs start from the element default, static outputs retain their formal words, and copyback changes only the selected actual range. Fixed formal/actual count and element mismatches and illegal reverse slices are elaboration errors. A DPI open formal reports the actual slice bounds, uses numeric declared indices in C, and copies output/inout writes back through the bounded window without inspecting the unspecified initial output contents. Missing descriptors, OOB windows, and source-size mismatches in textual VVP are non-asserting and stores are atomic. Focused evidence is 24/24 legacy, 21/21 JSON/VVP, 1/1 real DPI, and 7/7 malformed-IR invariants. Multidimensional, class/property-backed, and `ref` slice actuals remain outside this row. |
| 6.22.2 and 6.11.2 OpenTitan spelling | DIAGNOSED plus INTEROPERABILITY EXTENSION | Packed element equivalence remains strict about width, signedness, state representation, enum identity, and nested associative metadata. Only an ordinary blocking cross-kind assignment between non-enum packed `bit`/`logic` elements of equal nonzero width and signedness is widened; 4-state-to-2-state conversion maps X/Z to zero. Same-kind assignment, initialization, delayed/nonblocking assignment, casts, formal/ref binding, width, signedness, and enum identity are not widened. Slang 11.0.448 rejects the exact OpenTitan assignments in both editions and VCS compatibility mode; no VCS, Questa, or Xcelium executable was run. |
| VVP textual conversion/loader contract | FIXED and malformed-input-pinned | `%queue/to/darray` retains its legacy spelling, `%container/to/queue` adds the inverse typed copy, and typed object-splice opcodes carry an optional unpacked-struct prototype in an out-of-line descriptor. `vvp_code_s` remains 24 bytes on ARM64. The loader validates exact arity, element and stream encodings, queue bounds, and resolved prototype kind before scheduling; runtime backstops avoid assertions and preserve operand-stack balance. Direct fixtures cover ordinary conversion, truncation, malformed arity/encoding/prototype, and strict runtime-limit failure. |
| Validation and application evidence | PROVISIONAL checkpoint | The final container-focused gates pass 79/79 legacy and 72/72 JSON/VVP; the fixed-slice gates pass 24/24 legacy, 21/21 JSON/VVP, 1/1 focused real DPI, and 7/7 textual-IR recovery invariants. The post-slice broad replay passes 2,151/2,151 full legacy, 1,229/1,229 full JSON/VVP, 136/136 negatives, 103/103 VPI, and 354/354 canonical real-DPI UVM with no failures or skips. The current authentic OpenTitan replay has zero `spi_agent_cfg.sv:139`/`:143` mismatch occurrences in `spi_device_sim`, `spi_host_sim`, Darjeeling, and Earlgrey; recorded prior red counterparts prove removal only for the two top-chip closures. All four remain FAIL at independent later mechanisms. See the [session log](../session_logs/2026-08-28_opentitan_queue_darray_destination_conversion.md). |

This is not complete clause-6, clause-7, or clause-13 support. The mixed-state
ordinary-assignment extension still requires a bare direct-identifier RHS;
selected, scoped, property, nested, and function-return sources are not
widened by that extension. General recursive bit-stream casts and ordinary
queue bounds above `UINT_MAX` remain explicitly outside the fixed subset.

## 2026-08-30 clauses 7.10.1, 9.4.2, 23.6, and 25.9 refinement

IEEE 1800-2017 and IEEE 1800-2023 state the same rules used by this bounded
increment. The paired `-g2017`/`-g2023` tests distinguish the normative
language subset from one explicitly labeled compatibility extension.

| Clause | Boundary | Disposition / evidence |
|---|---|---|
| 7.10.1 | Left-`$` queue range r-value, `q[$:hi]` | FIXED for the evidenced r-value subset. The receiver is evaluated once, `$` is derived from that live queue's last index, and the integral `hi` is evaluated once. An exact or above-last `hi` returns the final item; a lower/reversed or X/Z bound and an empty source return an empty queue. The result is always an unbounded queue. Direct, selected class-property, static-property, method/type-query, integral, logic, real, string, class-handle, and nested-container paths are pinned; nested containers are copied and class handles retain identity. A nonqueue receiver or nonintegral explicit bound is an error. The corresponding l-value and `$` as an indexed `+:`/`-:` base remain loud boundaries. `sv_queue_slice_dollar_left{,_fail,_lvalue_fail}`. |
| 9.4.2, with 6.17, 14.10/14.12/14.14, and 15.5 leaf forms | Mixed explicit event lists | FIXED for an explicit `or`/comma list whose leaves can be lowered independently. Each leaf is prepared once and its retained expression is transferred to exactly one lowering path. A VIF-member or class-property leaf may coexist with ordinary signals, named events, a run-time-selected event-array element, and direct/default/global clocking events. Isolated join-any helpers resume the user statement once and cancel all losing registrations without killing an unrelated detached child. Simultaneous winners resume once; same-value and masked class-property writes do not wake. Rejected leaves diagnose once. A single leaf expression that itself combines VIF and class/ordinary dependencies remains loud, and the prior compound-snapshot and owner/key/index-mutation boundaries are unchanged. `sv_class_property_mixed_event_value_change`, `sv_event_list_vif_{mixed_once,preserved_leaves}`, and the prepare-once diagnostic pairs. |
| 25.9 and Syntax 25-3 | Virtual-interface declaration spelling, provenance, and forbidden contexts | FIXED for the evidenced declaration subset. `virtual iface` and `virtual interface iface` are accepted directly and through typedefs in compilation-unit, package, module, block, declaring-for, unpacked-struct, qualified class-property, and task/function/method argument and return contexts. Source provenance follows arrays, forward/package typedefs, concrete type parameters, and lexical `type(expression)`, so module/interface/program ports, interface items, and union members are rejected while ordinary interface ports remain legal. Parameter overrides still use default member widths and warn; this row does not claim complete specialization semantics. `sv_vif_explicit_interface_{class_property,data_type_contexts}` and the forbidden-context pairs. |
| 25.9 | Virtual-interface `==` and `!=` | FIXED for the unparameterized identity subset. A VIF may compare with null, an equivalent VIF, or a same-definition concrete interface instance in either operand order. VVP compares the bound scope plus interface definition, so two wrappers for one instance compare equal, different instances do not, and ordinary class objects retain pointer identity. Constant one-dimensional instance-array elements, same-type conditional VIFs, rebinding, null, lexical shadowing, and same-spelling instance/type names are pinned. Scalars, different interface definitions, two concrete instances, `===`/`!==`, and `==?`/`!=?` remain exact errors. Parameter specialization and modport selection are not yet complete parts of comparison type identity. `sv_vif_instance_comparison` and six negative sources. |
| 23.6 compatibility boundary | Run-time-variable interface-instance-array selection used as a 25.9 operand | INTENTIONAL EXTENSION, not IEEE conformance. Both editions require an instance-array select in a hierarchical name to be a constant expression. `sv_vif_instance_runtime_index_extension` separately pins the unqualified one-dimensional run-time dispatch needed by application flows. Slang 11 accepts the core 25.9 positive and rejects this extension in both editions. Hierarchical and multidimensional run-time dispatch are not claimed. Slang's separate acceptance of VIF case/wildcard operators is not used as evidence against 25.9's normative Icarus diagnostics. |
| Validation | PROVISIONAL checkpoint | The VIF context/comparison/extension lists pass 22/22 in each legacy and JSON/VVP path; the chapter-9 lists pass 14/14 in each path; and the new left-`$` queue rows pass 6/6 in each path. The broad replay passes 2,188/2,188 legacy, 1,266 JSON/VVP entries with 0 failures (1,249 pass and 17 unchanged NI), 149/149 negatives, 103/103 VPI, and 354/354 canonical real-DPI UVM. Homebrew Bison 3.8.2 reports 533 shift/reduce and 1119 reduce/reduce conflicts, versus 535/1119 on the merge base, with no unintended canonical conflicting-state terminal-action change. No OpenTitan or Caliptra application matrix was replayed. |

This is not complete clause-7, clause-9, clause-23, or clause-25 support. In
particular, parameter-specialized and modport-aware VIF comparison identity,
nondefault parameterized-interface member widths, hierarchical or
multidimensional run-time instance dispatch, mixed dependency families inside
one event-expression leaf, left-`$` queue-slice l-values, and `$` as an indexed
range base remain outside the conformance subset. See the
[session log](../session_logs/2026-08-30_virtual_interface_event_list_queue_slice.md).

## 2026-09-01 clauses 8.19 and 19.5 constructor-order subset

Paired 2017/2023 evidence covers a bounded class instance-constant and
embedded-covergroup constructor-order subset:

- Only a corresponding class constructor may initialize a non-static instance
  constant. Static constants remain declaration-initialized.
- A path-sensitive source audit authorizes the recorded assignment sites. A
  per-object VVP guard enforces the dynamic rule that at most one assignment
  executes, including distinct sites reached through conditional, loop,
  `continue`, return, and detached-fork paths.
- An embedded covergroup that refers to an enclosing-class instance constant
  requires definite initialization before construction. The initializer and
  referring constructor may not share one loop or `fork...join_none` region.
- A procedural `for` header initializer executes once outside its repeated
  region; its body and step share the repeated region. Flow distinguishes a
  literal-false zero trip, omitted/direct-nonzero-literal guaranteed entry,
  `continue` into the step, and `break`/return exits. Other constant-expression
  proofs remain conservative.
- Literal and already-evaluated class-parameter repeat counts distinguish zero,
  one, and runtime/repeated flow without speculative elaboration. Lexical
  formals, locals, and explicit or pinned wildcard imports shadow a class
  parameter. Unary minus retains the literal's width and signedness.

The focused legacy and JSON/VVP gates each pass **44/44**. The post-change
broad gates pass **2,212/2,212** SystemVerilog, **1,290 JSON/VVP entries with
0 failures**, **149/149** negatives, **103/103** VPI, **1/1** malformed-VVP
guard checks, and **354/354** real-DPI UVM with no failures or skips. Nine
positive synthesis loop reducers and one negative sentinel preserve the
ordinary `NetForLoop` fast path.

On clean, unmodified OpenTitan revision `7a3ad34b`, the focused
`lowrisc:dv:rv_timer_sim:0.1` UVM compile now has setup return 0, compile return
0, and **0 hard errors**. Its four former instance-constant range drops are
absent; the row improves from FAIL to **DEBT** and retains 17 unrelated loud
debt diagnostics, so this is not an application pass. The pinned ARM64 Python
3.13/FuseSoC flow was used, and `util/regtool.py` regenerated the UART register
RTL byte-for-byte identically to the checked-in sources.

This is bounded clause-8/19 support, not closure. Nonliteral constant-condition
proof, exhaustive constructor control flow, broader covergroup expressions,
and the previously recorded clause-19 gaps remain open. See the
[session log](../session_logs/2026-09-01_class_instance_constant_constructor_order.md).

## 2026-09-01 clauses 8.13, 9.2.2.2.1, 13.4, 13.5, and 25.9 virtual-interface functions

Every language regression in this section is paired under `-g2017` and
`-g2023`.

| Boundary | Disposition / evidence |
|---|---|
| 25.9 value-returning dynamic dispatch | FIXED for unparameterized virtual interfaces. The frontend records every compatible concrete interface-function scope and a scope-keyed argument row. VVP compares the receiver's bound instance, selects exactly one candidate, evaluates only its row, and enters that method. Rebinding and multiple concrete instances are runtime-pinned. |
| 13.5.1/13.5.3 arguments and defaults | FIXED for input-only scalar/container formals in the recorded subset. Named and positional actuals are assignment-contextualized against each candidate. An omitted argument clones that candidate's declaration-scoped default, including interface-member reads, earlier-formal references, and nested VIF-function calls. Missing required actuals and named-then-positional calls remain hard errors. |
| 13.4.1/13.4.2 automatic and static lifetime | FIXED for the recorded typed forms. Automatic functions allocate their own frame. Static-formal setup is staged in an invocation-local typed overlay and committed immediately before the body; recursion from the body still observes shared static storage. Nested setup and automatic/static recursion are checked. |
| Typed and discarded results | FIXED for packed scalar/wide, real, string, class-handle, queue, and dynamic-array results. A statement-position cast/discard executes the selected function and balances the corresponding VVP stack. The object stack grows on demand beyond the former 32-value limit. |
| Null receiver | FIXED. A null dynamic VIF function receiver terminates at runtime. The no-concrete-instance case still elaborates explicit actuals against the declaration signature before emitting the required null failure. |
| 9.2.2.2.1 `always_comb` sensitivity | FIXED for a function-body read through a constant element of an interface-port array. Dependency discovery includes the selected member while declaration-only interface scopes remain absent from target conversion. |
| 8.13 inherited value parameters | FIXED for unqualified lookup in a derived class method. After local lookup, specialized superclass scopes are searched nearest-first. `sv_inherited_class_parameter_vif_task` passes the inherited value 80 * 2 into an implicit-input VIF task formal; exact main warns and observes 0. |
| Statement-row compile-progress compatibility | PRESERVED and isolated. If frontend recovery has already produced a null actual for a VIF task statement, target lowering skips only that store as main did. This does not relax value-returning VIF expressions, ordinary subroutine calls, formal-direction checks, or legal-source diagnostics. |
| Unsupported boundaries | LOUD or documented. Output/inout/ref VIF-function arguments, fixed-unpacked arguments/returns, complete parameterized-interface and modport specialization, and synthesis lowering remain outside this subset. |
| Focused validation | The paired legacy and JSON/VVP lists each pass **31/31**. Final broad and application totals are recorded in the associated session log. |

This is a bounded cluster, not complete clause 8, 9, 13, or 25 support. See
the [session log](../session_logs/2026-09-01_virtual_interface_functions.md).

## 2026-09-02 clauses 6.22, 7.4-7.10, 13.5, 15.4.5-15.4.9, and 25.5/25.7/25.9 refinement

This increment preserves semantic type and l-value identity across
parameterized interfaces, recursive containers, and mailbox calls. It is a
bounded refinement, not closure of any parent clause.

| Boundary | Disposition / evidence |
|---|---|
| 6.22.1 and 25.7 modport prototypes | FIXED for the recorded declaration and call subset. Identifier-form imports use the interface declaration signature for ordinary positional calls. A full prototype is required where 25.7 requires it and is checked at elaboration even if never called. Argument count/direction, return type, significant formal names, fixed bounds, packed shape, array kind, associative index type, defaults, duplicate declarations, visibility, and missing exports retain focused diagnostics. Matching is deliberately stricter than equivalence: an equivalent-but-nonmatching packed representation does not satisfy a modport prototype. Parser recovery clears an incomplete item after an error and at a physical-file boundary. |
| 25.9 parameterized and modport-selected VIF dispatch | FIXED for the evidenced dynamic-call subset. Evaluated parameter values/types and the selected modport remain part of the semantic interface type. Each physical scope retains the carrier for its interface-local enum, unpacked-record, and class declarations. The current VIF binding chooses the compatible physical method candidate without executing an unrelated specialization. Scalar task `output`, `inout`, and `ref` formals select and write back through that same candidate. Output/inout/ref VIF **function** formals, arbitrary fixed-unpacked formals/returns, exhaustive specialization interactions, and synthesis closure are not claimed. The new nominal-result/task-copyback rows pass 8/8 in each legacy and JSON/VVP harness; the exact-main compiler is 0/8 in both harnesses. |
| 25.5 selected actual and physical interface arrays | FIXED for the recorded direct forms. A selected-modport actual connected to an unqualified physical interface formal retains the actual instance's evaluated parameter specialization. Member access, selected task copyback, and parameterized/forwarded interface-array paths pass 4/4 together. This does not claim arbitrary hierarchical or multidimensional runtime instance selection. |
| 7.4.2, 7.4.5, 7.5, 7.6, 7.8, and 7.10 recursive Q/D/A layout | FIXED for the recorded runtime carrier and fixed-word subset. VVP preserves each nested queue/dynamic/associative kind, queue-bound state, child layout, value-copy boundary, and mutation root. A fixed unpacked-array element may be a Q/D/A value or the tested D/Q and A/Q compositions; selecting the fixed word retains both ranks and evaluates its receiver index once. New recursive metadata is validated before scheduling while legacy images retain their legacy path. The repaired regression cluster passes 13/13 and the paired fixed-container reducer passes 2/2. General recursive aggregates, VPI/DPI closure for every shape, and broad bit-stream casts remain open. |
| 6.22.2 and 15.4.9 typed-mailbox methods | IMPLEMENTED; final focused validation pending. Statement and expression calls use the mailbox type's semantic equivalence relation for `put`, `get`, `peek`, `try_put`, `try_get`, and `try_peek`. A class typedef alias is admitted, nominally distinct classes are rejected, and distinct packed declarations that satisfy 6.22.2 remain legal even when they do not match under 6.22.1. Bare `mailbox` and `mailbox#()` retain the dynamic form. No passing mailbox count is claimed at this checkpoint. |
| 13.5 and 15.4.5-15.4.8 mailbox reference output | IMPLEMENTED; final focused validation pending. Retrieval calls retain an elaborated l-value rather than replacing it with an r-value. Target/runtime state captures the receiver and selector before a blocking operation and is intended to write direct scalar/string/real/object variables, packed selects, class properties, fixed words, and queue/dynamic-array elements. A successful try writes back; an empty try leaves its target unchanged. Associative-element reference lifetime and the coherent installed-tool reducer run remain pending. |
| Validation/application boundary | PROVISIONAL checkpoint. Proven focused results are VIF 8/8 in each harness with exact-main red proofs of 0/8 in both harnesses, parser recovery against exact golds, recursive containers 13/13, interface arrays 4/4, and fixed containers 2/2. Full legacy, JSON/VVP, negative, VPI, real-DPI UVM, OpenTitan, and Caliptra replays have not run for this increment. The recorded application baselines therefore remain OpenTitan 192 PASS of 530 classified rows and Caliptra Icarus 53/105 versus Slang 54/105 in its static census. |

The corresponding IEEE 1800-2023 rules are unchanged for the implemented
semantics. Its multidimensional-array text is numbered 7.4.4 rather than
2017's 7.4.5. See the
[session log](../session_logs/2026-09-02_parameterized_vif_recursive_containers_typed_mailbox.md)
and the paired-edition delta entry.

## 2026-09-04 dynamic root randomization callbacks

| Clause | Mechanism | Status | Evidence / remaining boundary |
|---|---|---|---|
| 18.6.2 / 18.6.3 / 18.11 | Dynamic root pre/post callbacks, including checker calls | PARTIAL | Runtime dispatch selects the actual class's independently nearest callbacks; direct nonvirtual calls stay static. Root pre runs before inline state capture; post runs only on successful solve. Paired 2017/2023 regressions cover sibling/inherited classes, parameterization, escaped identifiers (5.6.1), virtual method encoding (8.20), receiver identity, nested frames and null checker side effects. Enabled-member callbacks and simultaneous global constraints remain open; the real xbar now exposes the latter as a failing solve. See the [session record](../session_logs/2026-09-04_dynamic_root_randomize_hooks.md) for exact validation and limitations. |

## 2026-09-04 enabled random-member callback increment

IEEE 1800-2017 18.6.2/18.6.3, 18.8 and 18.11: enabled member pre callbacks
precede graph snapshots; posts use retained successful participants. Aliases,
cycles, callback-created edges, explicit selection, element modes and nested
automatic frames have paired regressions. Status remains **PARTIAL**, with
complete regression gates passing and both application classifications
unchanged (OT203 PASS, Caliptra52 PASS/GAP0). Simultaneous global constraints
remain open. See the [member callback record](../session_logs/2026-09-04_enabled_member_randomize_hooks.md).

## 2026-09-04 global constraint solver working increment

**PARTIAL; full repository gate and application comparisons complete.** IEEE 1800-2017
18.5.9/18.5.10 and IEEE 1800-2023 18.5.8/18.5.9 have an owner-aware joint
solver and bounded complete-tuple sampler. Declaration-order soft priority,
static identity, transaction rollback, and constrained randc stages have paired
regressions. Unsupported staged distributions and history/size bounds fail
explicitly on the new route. This does not complete these clauses or full DV.

Both editions 8.4/11.4.5/18.4: typed constraint handle identity and procedural
null-property case inequality. IEEE 2017 18.5.13 / 2023 18.5.12: guards retain
state/random/error classification under call selection. Both editions 18.3:
constraint case operators hard-error; associative state reads retain X/Z rejection.
State foreach shares the canonical active selection (2017 18.5.8.1/18.5.9;
2023 18.5.7.1/18.5.8), including static aliases and inactive ternary-arm typing
(both editions 11.6.1/11.8.2).

Build18 grounds inactive scalar storage before expression expansion while
retaining provenance, signedness, and X/Z errors. The existing nested-state UVM
test recovers from a 60s timeout to less than 0.3s. State distribution endpoints
now qualify for the existing exact sampler (2017 18.5.4; 2023 18.5.3); active
endpoint controls retain the documented fallback warning. All 58 direct checks,
the corrected legacy diagnostic case, and 166 JSON focus cases pass. Full gate5
passes: legacy 4621/4626 (0 failed, 2 NI, 3 EF), JSON 1515/0, VPI 103/103, negative
149/0, runtime invariants, and real-DPI UVM 355/0/0.

See the [session record](../session_logs/2026-09-04_global_constraint_solver.md)
for exact gates, review findings, explicit boundaries, and application baselines.

The final census diff retains all 203 OpenTitan PASS rows and summed compile
debt 2223; Caliptra remains 52 PASS / ICARUS_GAP 0 across all 105 unchanged rows.
Twenty already-failing OpenTitan runtime rows now reject joint dist/order earlier,
including all eight xbars at cfg.randomize. TL agent changes from timeout to
explicit failure. These are documented boundaries, not runtime completion gains.


**Independent-component follow-up, local gate and application comparison complete:** IEEE 1800-2017
18.5.9/18.5.10 and IEEE 1800-2023 18.5.8/18.5.9 now have complete projected
sampling per syntactically independent factor while retaining one global hard
problem. The 1024-tuple proof bound applies per factor. One unconditional hard
distribution on a canonical scalar/element is supported per factor, with
state-only weights and fully feasible ground ranges (2017 18.5.4; 2023 18.5.3).
Residual tuples are conditionally uniform. Unsupported soft/guarded/coupled
multiple distributions, active weights, partial range exclusion, and
solve-before fail explicitly. Three new paired families and 34 legacy focus
checks pass. Full gate: legacy4627/4632 (0failed,2NI,3EF), JSON1521/0,
VPI103/103, negative149/0, runtimeinvariants, real-DPI UVM355/0/0. The fresh
530-row OpenTitan comparison retains 203 PASS with no lost PASS; all eight xbar
runtime rows now time out after the earlier constraint boundary. There is no
completed application gain. The stored semantic_debt_count sum is 2221 versus
2223 solely because two pairs of diagnostics interleaved onto shared log lines;
warning/error tokens and compiler return codes match, so no semantic debt
improvement is claimed. Caliptra's 105 static rows are unchanged at52 PASS and
ICARUS_GAP0. The session record links the complete per-row/input/raw-log audit.
