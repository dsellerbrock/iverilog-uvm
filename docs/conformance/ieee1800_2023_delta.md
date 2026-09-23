# IEEE 1800-2023 first-class conformance survey

Canonical 2023 edition record. The initial scoping table is historical; later
dated refinements carry their own evidence and limits. Shared implementation
updates live in the [2017 matrix](matrices/ieee1800_2017_clause_matrix.md);
record only the edition relationship here rather than repeating entire fix logs.

The tested 2023 §15.5.3 class-event `.triggered` behavior shares the
[2017 implementation scope and paired local evidence](matrices/ieee1800_2017_clause_matrix.md#september-23-class-event-triggered-state).
No edition-specific difference or full clause/application qualification is
claimed.

The 2023 §11.4.13 unpacked-array traversal and wildcard-membership semantics
share the bounded ordinary-expression implementation in the
[2017 matrix](matrices/ieee1800_2017_clause_matrix.md#september-23-constant-unpacked-array-membership).
Paired focused tests show no edition difference; a constraint-context SPI
compile error remains outside this implementation scope.

Static/automatic named-event triggered sensitivity shares the paired 2017
implementation and replay recorded in the
[2017 matrix](matrices/ieee1800_2017_clause_matrix.md#september-23-static-and-automatic-named-event-triggered-sensitivity).
The AON smoke timeout is recorded as incomplete runtime evidence, not DV
qualification.

The candidate 2023 §§7.12.1/15.5 associative `find_index` and multi-object
class-event list checks share the [2017 implementation scope and paired local
evidence](matrices/ieee1800_2017_clause_matrix.md#september-23-associative-find_index-and-multi-object-class-event-lists).
No edition-specific difference or application DV qualification is claimed.

The tested 2023 §§7.5/18.4 nested outer resize and §18.5.7.1 sparse-key
constraint `foreach` share the [2017 implementation and paired local evidence](matrices/ieee1800_2017_clause_matrix.md#september-23-2026--nested-outer-resize-and-sparse-key-constraint-foreach).
The §38.36.1 force/release callback statement identity shares the [2017
implementation and paired evidence](matrices/ieee1800_2017_clause_matrix.md#september-23-2026--forcerelease-callback-statement-identity).
No edition-specific difference or full application qualification is claimed.

The tested 2023 §§9.4/12.5/12.8 case-exit stack correction shares the [2017
implementation and paired evidence](matrices/ieee1800_2017_clause_matrix.md#september-23-2026--case-selector-cleanup-on-early-body-exit).
No edition-specific behavior or full clause-12 qualification is asserted.

The tested 2023 §22.5.1 macro-actual cast-delimiter rule shares the [2017
implementation and paired evidence](matrices/ieee1800_2017_clause_matrix.md#september-23-2026--cast-delimiters-inside-macro-actual-arguments).
The 2023 text additionally names triple quotes as a matched delimiter; this
candidate does not implement or qualify that edition-specific form.
The later matched `()`, `[]`, and `{}` macro-actual correction shares the
[2017 implementation and paired evidence](matrices/ieee1800_2017_clause_matrix.md#september-23-2026--matched-delimiters-inside-macro-actual-arguments);
triple-quote handling is still outside that scope.

The tested §38.36.1 force/release callback-registration boundary shares the
[2017 implementation and paired evidence](matrices/ieee1800_2017_clause_matrix.md#september-23-2026--forcerelease-vpi-callback-registration).
No edition-specific behavior is asserted for this subset.

The tested 2023 §§14.12/16.14.6 late module default-clocking rule shares the
[2017 implementation and scoped evidence](matrices/ieee1800_2017_clause_matrix.md#september-23-2026--late-module-default-clocking-for-assertions); paired
edition execution found no difference in this subset. Broader SVA qualification
remains open.

The direct zero-argument queue-pop method rule in §§5.13/7.10.2.4 shares the
2017 implementation. [Paired focused evidence](session_logs/2026-09-23_opentitan_queue_pop_focus.json)
shows no edition difference for the tested class-property subset; broader
queue-method qualification remains open.
The [expression-context associative-array rejection boundary](session_logs/2026-09-23_queue_pop_assoc_boundary.json)
is likewise paired across both editions. The [statement-method candidate](session_logs/2026-09-23_assoc_queue_statement_methods_focus.json)
shares the 2017 fix and paired evidence; broad qualification remains open.

The 2023 §16.7 finite-sequence naming correction shares the [2017 matrix
scope](matrices/ieee1800_2017_clause_matrix.md#september-23-long-finite-sva-sequences)
and has separate `-g2023` executable 999/1000/1001-step evidence. No edition
difference or broader SVA/formal qualification is claimed.

The September 23 selected-bit property NBA candidate has separate `-g2023`
positive, negative, and boundary runs alongside its `-g2017` checks; see the
[shared scope and evidence](session_logs/2026-09-23_opentitan_nba_codegen_focus.json).
No edition-specific difference or broader property-NBA qualification is claimed.

This began on 2026-07-29 as Campaign 7's M15 scoping record. The initial method
used two independent secondary sources — K. Shinozuka,
"A Subjective Review on IEEE Std 1800-2023" (DVCon Japan 2024, written
against the published standard) and B. Pierce, "What's new in
SystemVerilog-2023? Part 1" (Dec 2023, SV committee member, exact
syntax-rule citations) — cross-checked with live probes against the
current compiler. That historical provenance remains useful, but it is no
longer the normative basis.

IEEE 1800-2023 is now a first-class selected edition alongside 1800-2017.
Implementation and closure decisions must cite the locally consulted, ignored
`docs/standards/local/IEEE_Std_1800-2023.pdf`, compare the corresponding 2017
rule and applicable errata, and add executable `-g2023` evidence. The table
below is a scoping survey, not a complete clause matrix or a claim that every
probe is current. Secondary sources may help find deltas but cannot override
the selected LRM. Shared rules should normally have paired `-g2017`/`-g2023`
tests; changed rules need positive 2023 and edition-rejection evidence.

Unmodified UVM, OpenTitan, and Caliptra are application gates, not substitutes
for the standard. VCS, Questa, and Xcelium are the practical commercial-
simulator compatibility targets after the selected IEEE text; Slang is a
parser/elaboration differential and Verilator is diagnostic only. The work is
intended to leave a formal-ready frontend and SVA/IR foundation, but a proof
engine is later work and UPF/IEEE 1801 remains deferred.

## Candidate and previously probed 2023 changes; row-level direct-LRM closure pending

Keep `CERTAIN` below only as the historical scoping confidence. A row is not
closed until it has a direct-LRM citation, date, and executable edition gate.

| # | Item | Scoping confidence | Fork status (historically probed) | Size |
|---|------|------------|----------------------|------|
| 1 | Triple-quoted strings `"""…"""` (5.9) | CERTAIN | UNSUPPORTED (lexer) | S |
| 2 | `ref static` tf arguments | CERTAIN | UNSUPPORTED (grammar) | M |
| 3 | Associative-array-typed parameters | CERTAIN | UNSUPPORTED | M |
| 4 | Restricted type parameters (`type enum/struct/class`) | CERTAIN | UNSUPPORTED | S–M |
| 5 | `type(this)` self-type | CERTAIN | UNSUPPORTED | M |
| 6 | Soft packed unions (`union soft`) | CERTAIN | UNSUPPORTED (hard packed unions work) | M |
| 7 | Named index iterator in array locator methods | CERTAIN | grammar accepts, binding missing ("Unable to bind `myidx`") | S |
| 8 | Array `map()` method (7.12.5) | CERTAIN | UNSUPPORTED but scaffolded — fails at elaboration on the shared `.method(iter) with` dispatcher, not at parse | S |
| 9 | Class `:final` specifier | CERTAIN | UNSUPPORTED | S |
| 10 | Constructor `default` argument keyword | CERTAIN | UNSUPPORTED | M |
| 11 | Method `:extends`/`:initial`/`:final` override specifiers | CERTAIN | UNSUPPORTED (no grammar) | M |
| 12 | Constraint `:extends`/`:initial`/`:final` | CERTAIN | UNSUPPORTED | S–M |
| 13 | `dist` catch-all `default :/ expr` | CERTAIN | UNSUPPORTED (isolated cleanly: base dist fine, `default:/` errors) | S |
| 14 | Covergroup `extends` in a subclass | CERTAIN | UNSUPPORTED by grammar inspection | M |
| 15 | `$timeunit`/`$timeprecision` system functions | CERTAIN | needs a dedicated probe (keyword-collision risk); tentatively UNSUPPORTED | S |
| 16 | `$stacktrace` standardized (task + string function) | CERTAIN | task form ALREADY IMPLEMENTED (R21, comment updated); string-function form open | doc + S |
| 17 | Preprocessor boolean `` `ifdef (A && B) `` (syntax 22-5) | CERTAIN | UNSUPPORTED (parenthesized-boolean form) | M |
| 18 | `weak_reference#(T)` | CERTAIN | UNSUPPORTED; needs GC/refcount hooks | L |
| 19 | `rand real` | CERTAIN | rejected at the single 18.4 choke point (clean relax site); real-valued solving itself is the work | L |
| 20 | Tolerance range operators `[a +/- b]`, `[a +%- b]` | CERTAIN | UNSUPPORTED by grammar inspection | S–M |
| 21 | Relational/equality results formally sized 1-bit | CERTAIN (clarification) | already conformant ($bits probes = 1) | N/A |

## Paired clause-19 checkpoint (2026-08-26)

Shared constructor/bin-topology behavior is recorded in the
[2017 matrix](matrices/ieee1800_2017_clause_matrix.md). The edition-specific
retention rule and its bounded evidence are detailed below.

The automatic-cross-bin edition delta is now directly audited. IEEE 1800-2017
19.6.1 p.572 requires retention of the nonintersecting automatic remainder and
its 19.7 Table 19-1 pp.578–579 has no retention option. IEEE 1800-2023 19.6.1
p.600 makes that behavior the default, and 19.7 Table 19-1 p.606 defines
`cross_retain_auto_bins` with default 1. When false, the presence of any
explicit cross bin removes every automatic bin. Syntax 19-4 pp.597–598 uses
`bins_keyword` for a cross-bin declaration, and Syntax 19-2 p.582 defines that
keyword as `bins`, `ignore_bins`, or `illegal_bins`; the presence rule therefore
includes all three. Applying it when a selector is empty is the direct
implementation consequence of “presence,” not a separate LRM example.

The option is instance-specific, not static. The construction-time option
assignment rule is on p.607; Table 19-2 p.608 permits it on a covergroup as the
default for crosses and on a cross as an override, but not on a coverpoint.
The implicit structures in 19.10 pp.613–614 put it in covergroup and cross
`option` and in no `type_option`. One p.607 sentence says “covergroup or
coverpoint definition”; that conflicts with both the table and the structures
and is recorded as an apparent editorial typo. The implementation follows the
table and structures.

The current compiler verifies constant covergroup defaults, constant
cross-local values, invalid coverpoint/`type_option` placement, and the 2017
edition rejection. Constructor/per-instance nonconstant expressions remain
open: the current `opt_uint` path diagnoses them and uses a default instead of
evaluating them per constructed object. The runtime presence mechanism covers
normal, ignore, and illegal records. The focused retention reducer pins an
ordinary explicit bin, a no-explicit-bin control, inherited covergroup defaults
on fixed and dynamic crosses, cross-local disable and enable overrides, and
empty ignore/illegal selectors. Procedural-write and repeated-assignment
evidence remains to be added.

This remains bounded clause-19 support. The matrix owns common coverage
limitations; the 2023-only real/tolerance surface remains open. Historical
application counts are preserved in the [survey archive](session_logs/2026-09-14_edition_survey_history.md);
[CURRENT_WORK](CURRENT_WORK.md) links later evidence.

## Shared rules with paired evidence

These records cover shared rules in bounded 2017/2023 subsets. The 2017 matrix
owns common implementation scope, tests, and residual gaps. Paired tests do
not establish complete clause or edition qualification.

| Dated topic | Canonical record |
| --- | --- |
| Paired clauses 7 and 10 checkpoint (2026-08-26) | [Scope and evidence](matrices/ieee1800_2017_clause_matrix.md#2026-08-26-clauses-7-and-10-associative-pattern-refinement) |
| 2026-08-27 clauses 6.16 and 11.4.12.2 | [Scope and evidence](matrices/ieee1800_2017_clause_matrix.md#2026-08-27-clauses-616-and-114122-typed-string-concatenation) |
| 2026-08-27 clause 12.7.1 | [Scope and evidence](matrices/ieee1800_2017_clause_matrix.md#2026-08-27-clause-12-declaring-for-loop-refinement) |
| 2026-08-27 clause 23.11 | [Scope and evidence](matrices/ieee1800_2017_clause_matrix.md#2026-08-27-clause-2311-bind-target-instance-paths) |
| 2026-09-01 clauses 8.19 and 19.5 | [Scope and evidence](matrices/ieee1800_2017_clause_matrix.md#2026-09-01-clauses-819-and-195-constructor-order-subset) |
| 2026-08-30 clauses 7.10.1, 9.4.2, 23.6, and 25.9 | [Scope and evidence](matrices/ieee1800_2017_clause_matrix.md#2026-08-30-clauses-7101-942-236-and-259-refinement) |
| 2026-08-28 clauses 6.24, 7.6, 7.10.5, and 13.3–13.5 | [Scope and evidence](matrices/ieee1800_2017_clause_matrix.md#2026-08-28-clauses-624-76-7105-and-133135-positional-container-refinement) |
| 2026-09-01 clauses 8.13, 9.2.2.2.1, 13.4, 13.5, and 25.9 | [Scope and evidence](matrices/ieee1800_2017_clause_matrix.md#2026-09-01-clauses-813-92221-134-135-and-259-virtual-interface-functions) |
| 2026-09-02 clauses 6.22, 7.4-7.10, 13.5, 15.4.5-15.4.9, and 25.5/25.7/25.9 | [Scope and evidence](matrices/ieee1800_2017_clause_matrix.md#2026-09-02-clauses-622-74-710-135-1545-1549-and-255257259-refinement) |
| 2026-09-04 clauses 5.6.1, 8.20, 18.6.2-18.6.3, and 18.11 — root randomize callbacks | [Scope and evidence](matrices/ieee1800_2017_clause_matrix.md#2026-09-04-dynamic-root-randomization-callbacks) |
| 2026-09-04 clauses 18.6.2-18.6.3, 18.8 and 18.11 — enabled member callbacks | [Scope and evidence](matrices/ieee1800_2017_clause_matrix.md#2026-09-04-enabled-random-member-callback-increment) |
| 2026-09-23 clause 18.12 — exact-or-bounded-size local integral queue scope randomization | [Shared scope and paired evidence](matrices/ieee1800_2017_clause_matrix.md#september-23-exact-or-bounded-size-scope-queue-randomization) |

Associative-array assignment patterns do not implement the separate 2023
associative-array-typed parameter feature in the scoping table.

## Explicitly unverified (do not implement without direct LRM citation)

Enhanced `disable` semantics; string↔real conversion changes beyond
`rand real`; Preponed-region clarifications; `$countdrivers`-family
additions; interface class changes; constraint implication changes
beyond items 12–13. Each was searched for and NOT found in either
source — treat as possibly-not-real until the 2023 LRM text is audited
directly. This warning is about the items, not a reason to postpone the wider
2023 campaign.

## Historical 2026-07-29 scoping order (non-normative)

`ROADMAP.md` controls current priority. This list is retained to explain the
original survey ordering, not to postpone first-class 2023 work.

1. `$stacktrace` task-form documentation was aligned at the R21 checkpoint;
   the 2023 string-function form remains open
2. Array `map()` (elaboration-only on the existing dispatcher)
3. `dist default :/`
4. Named locator index binding
5. Triple-quoted strings (pure lexer)
6. `ref static` (scheduler-adjacent; fits the M6B NBA expertise)
7. Class-declaration hardening cluster (items 9–12, shared territory)
8. Restricted type parameters + `type(this)` (items 4–5)
9. Assoc parameters, soft unions, `ifdef` booleans (3, 6, 17)
10. `rand real` (defer: solver-level)
11. `weak_reference#(T)` (defer: GC infrastructure)

## Clause numbering and later evidence

Global constraints are clause 18.5.9 in 2017 and 18.5.8 in 2023; foreach is
18.5.8.1 in 2017 and 18.5.7.1 in 2023. Later paired campaign increments are
recorded once in the [2017 matrix](matrices/ieee1800_2017_clause_matrix.md).
The [L64 final record](session_logs/2026-09-14_constraint_function_presolve.md#final-seven-gate-qualification)
claims no edition-specific semantic difference and keeps clause 18 PARTIAL.
Older "global constraints remain open" statements describe their dated scope,
not a blanket claim that later joint-solver subsets are absent.

The [archived survey](session_logs/2026-09-14_edition_survey_history.md) retains
the full earlier narratives and qualification history. Add new edition deltas
here; keep common fix narratives and exact test counts in their owning records.

## L68 paired array-update evidence (2026-09-14)

The indexing/default rules consulted for this fix are 2023 7.4.5 and
2017 7.4.6; no behavior difference is claimed. Shared implementation scope and
paired evidence are linked from the [2017 matrix L68 refinement](matrices/ieee1800_2017_clause_matrix.md#l68--packed-select-updates-within-fixed-array-words).

## 2026-09-14 shared L65–L74 evidence

The selected compiler fixes exercise common rules in paired 2017/2023 regressions. Shared scope and evidence belong to the [2017 matrix refinement](matrices/ieee1800_2017_clause_matrix.md#l65l74-qualification-refinement--2026-09-14); this adds no edition-specific language claim.

## 2026-09-14 shared L75–L84 evidence

The string-storage and constant-evaluation fixes exercise common rules in paired 2017/2023 tests. Shared scope and qualification belong to the [2017 matrix refinement](matrices/ieee1800_2017_clause_matrix.md#l75l84-qualification-refinement--2026-09-14). No edition-specific change or separate full-2023 UVM qualification is claimed.

## L85 shared ordered-distribution evidence

2023 distribution is clause 18.5.3; its excluded-range mass clarification differs
from 2017 18.5.4 wording. L85 supports the common fully feasible-range subset
and rejects unsupported fibers before drawing, without claiming that edition
difference implemented. Shared scope and paired evidence belong to the
[2017 matrix L85 entry](matrices/ieee1800_2017_clause_matrix.md#l85--joint-ordered-distributions).

## L87 shared selected-element ordering evidence

The paired fixed integral-element tests exercise the common ordering semantics
of 2017 18.5.10 and 2023 18.5.9. Shared scope/evidence belong to the
[2017 matrix L87 entry](matrices/ieee1800_2017_clause_matrix.md#l87--joint-selected-element-ordering); this does not add real or dynamic-container ordering support.

## L88 shared dynamic-array ordering evidence

The 2023 array sizing and ordering clauses (18.4, 18.5.7.2, 18.5.8/18.5.9) share the bounded implementation recorded in the [2017 matrix L88 entry](matrices/ieee1800_2017_clause_matrix.md#l88--joint-dynamic-array-selected-element-ordering). Separate edition regressions are linked there; no queue or associative-array ordering extension is implied.

## L89 shared queue ordering evidence

The 2023 clauses18.4 and18.5.8/18.5.9 share the bounded implementation in the [2017 matrix L89 entry](matrices/ieee1800_2017_clause_matrix.md#l89--joint-queue-selected-element-ordering), with separate edition regressions. No full queue or randomization conformance is claimed.

## L86 shared multiclock delay-window evidence

The 2023 sequence, implication, clock-flow and assertion-action clauses16.7,16.12.7,16.13 and16.14 share the bounded implementation in the [2017 matrix L86 entry](matrices/ieee1800_2017_clause_matrix.md#l86--multiclock-bounded-delay-window-antecedents). Separate edition regressions retain the shared semantics; repetition and broader multi-domain properties remain separate.

## L91 shared finite repetition evidence

The 2023 repetition, implication and nondegeneracy clauses share the bounded implementation in the [2017 matrix L91 entry](matrices/ieee1800_2017_clause_matrix.md#l91--finite-boolean-multiclock-repetition), with separate edition regressions and shared evidence.

## L90 shared enum selection evidence

The 2023 enum, increment/decrement and packed-select clauses share the implementation in the [2017 matrix L90 entry](matrices/ieee1800_2017_clause_matrix.md#l90--enum-container-packed-selects), with separate edition regressions.

## L92 shared assertion-control evidence

The 2023 assertion-control semantics share the implementation in the [2017 matrix L92 entry](matrices/ieee1800_2017_clause_matrix.md#l92--fixed-multiclock-assertion-control), with separate edition regressions.

L93 uses the same 6.16.11–6.16.15 and 13.4.3 requirements in 2023; [paired evidence](session_logs/2026-09-15_constant_string_formatting_validation.json) records edition-specific tests.

L95 applies the same 6.16.2 and 13.4.3 requirements in both editions; [paired evidence](session_logs/2026-09-15_constant_string_putc_validation.json) records the scoped implementation.

L94 uses the shared repetition, empty-composition and nondegeneracy requirements in 2023; [paired evidence](session_logs/2026-09-15_multiclock_grouped_repetition_validation.json) records separate edition executions.

The L85–L95 subsets share the [local qualification checkpoint](matrices/ieee1800_2017_clause_matrix.md#l85l95-local-qualification-checkpoint). Separate edition-focused results remain above; the full UVM gate used `-g2012`.

L96 shares the 13.4.3 input-only constant-function rule; [paired evidence](session_logs/2026-09-15_constant_function_formal_legality_validation.json) records separate edition checks.

L98 shares the 13.4.3 generated-declaration restriction; [paired evidence](session_logs/2026-09-15_generated_constant_function_legality_validation.json) records both editions.

L97 applies the shared repetition and empty-composition requirements; [paired evidence](session_logs/2026-09-15_nested_finite_grouped_repetition_validation.json) records edition-specific validation.

L99 uses the shared string-variable and constant-function requirements; [paired evidence](session_logs/2026-09-15_fixed_string_array_methods_validation.json) records separate edition executions.

L100 shares the multiclock sequence/implication requirements; [paired evidence](session_logs/2026-09-15_finite_multiclock_consequences_validation.json) records separate edition executions.

L102 shares the sequence-property and clock-flow rules; [paired evidence](session_logs/2026-09-15_plain_multiclock_consequences_validation.json) records separate edition execution.

L101 follows the shared 6.16,11.4.2,13.4.3 rules; [paired evidence](session_logs/2026-09-15_constant_array_character_increment_validation.json) records separate edition executions.

L103 follows the shared 16.9.2,16.13.1,16.13.2 rules; [paired evidence](session_logs/2026-09-15_plain_multiclock_ranged_prefix_validation.json) records separate edition executions.

L104 shares the equality sizing rules; [paired evidence](session_logs/2026-09-15_constant_mixed_equality_validation.json) records both editions.

L105 shares the constant-function locality restriction; [paired evidence](session_logs/2026-09-15_nonlocal_constant_function_values_validation.json) records both editions.

L96–L105 share the [local qualification checkpoint](matrices/ieee1800_2017_clause_matrix.md#l96l105-local-qualification-checkpoint). Paired focused evidence remains edition-specific; the full UVM gate used its existing2012 mode.

Grouped clocked implication consequents follow the shared 16.13 / Annex A.2.10
rules; [paired evidence](session_logs/2026-09-20_grouped_clocked_consequent.md) records both editions.

Masked runtime memory writes follow the shared 7.4.6, 11.5 and 10.4 rules; [paired evidence](session_logs/2026-09-20_masked_memory_synthesis.json) records both editions.

Variable fixed-array row assignments use shared 7.4.6, 7.6 and 10.4 rules; [paired evidence](session_logs/2026-09-20_variable_row_assignment.json) records the edition runs and limits.

State-selected fixed-array constraint evidence is [shared here](session_logs/2026-09-21_state_selected_fixed_array_constraints.json).
Indexing/slicing and Table 7-1 move from 2017 7.4.6 to 2023 7.4.5;
constraint guards move from 18.5.13 to 18.5.12. Earlier records citing
7.4.6 for both editions should be read with that clause-number correction.

Reset-only synthesis follows the shared9.2/10.4 semantics; [paired evidence](session_logs/2026-09-21_reset_only_synthesis.json) records both editions and remaining scope.

Integral constraint casts use shared 6.24, 11.6, 11.8.2 and 18.3 semantics;
[shared scope and evidence](matrices/ieee1800_2017_clause_matrix.md#september-21-integral-constraint-casts-and-coupled-distributions)
records separate 2017/2023 runs. Distribution and solve-before references
move from 2017 18.5.4/18.5.10 to 2023 18.5.3/18.5.9. No broader edition
qualification is implied by the focused checkpoint.

Procedural assignment synthesis follows shared clause 10.4 semantics;
invalid fixed-array indexing uses 2023 7.4.5 versus 2017 7.4.6.
[Shared scope and paired-edition evidence](matrices/ieee1800_2017_clause_matrix.md#september-21-procedural-synthesis-and-full-width-array-indices)
records the current PARTIAL implementation and pending broad qualification.

The [September 21 local batch qualification](session_logs/2026-09-21_compiler_batch_qualification.json) records the completed regression gates for the documented batch subsets at `8ab943352`. Earlier pending-gate notes describe their dated checkpoints. Overall language and UVM support remain PARTIAL; publication CI is pending.

### September21 shared fixes

The scope UNKNOWN failure path and long fixed antecedent repairs have paired
2023 runtime evidence alongside2017. See the shared
[scope record](session_logs/2026-09-21_scope_solver_unknown_fix.json) and
[SVA record](session_logs/2026-09-21_long_fixed_antecedent_fix.json) for semantics,
revision scope and limits. No edition-wide completion or broad qualification
is established by these focused checks.

The [object-method constraint evidence](session_logs/2026-09-21_constraint_object_method_receiver.json) pairs 2023 clause18.5.11 with 2017 clause18.5.12. This is shared implementation evidence with separate generation modes, not full clause qualification.

The [inline caller-object method evidence](session_logs/2026-09-22_inline_caller_object_method.json) pairs 2023 clauses 18.5.11/18.7 with 2017 clauses 18.5.12/18.7 using identical expected output; no edition difference was observed. PR322's capture was superseded by PR323's guarded inline state-function path. The paired tests pass on the [locally qualified follow-up source](session_logs/2026-09-23_pr322_branch_reconciliation.json); CI is separate.

The [bare enum-name evidence](session_logs/2026-09-21_enum_bare_name_type.json) checks shared clauses5.13/6.19 separately under 2017 and2023 modes.

Paired 2023 evidence shares the [self-package cast](session_logs/2026-09-21_self_package_type_cast.json) and [signed coverage range](session_logs/2026-09-21_signed_cover_range_resolution.json) implementation records with2017; broad edition qualification remains pending.

2026-09-21: packed-VPI selected-element behavior has separate 2023 runs in the [shared integration evidence](session_logs/2026-09-21_packed_vpi_integration.json). No edition-specific rule change is asserted; whole-clause status remains partial.

The [joint cyclic-ordering evidence](session_logs/2026-09-21_joint_ordered_randc.json) covers both editions: 2023 clauses18.4.2/18.5.9 correspond to2017 clauses18.4.2/18.5.10. This is shared subset evidence, with broad qualification pending.

## September 21 paired application foundation evidence

The [shared implementation checkpoint](matrices/ieee1800_2017_clause_matrix.md#september-21-application-foundation-focused-checkpoint) includes explicit 2023 focused runs. The distribution and ordering references are 18.5.3 and 18.5.9 in this edition; cyclic-variable rules remain 18.4.2. This records paired evidence rather than new edition differences or full qualification.

The [shared event runtime repair record](session_logs/2026-09-21_event_runtime_regression_repair.json) includes separate 2023 runs for activation, NBA/Re-NBA, startup, and callback cases. No edition-specific semantic difference is asserted.

The [shared fixed struct-member array checkpoint](matrices/ieee1800_2017_clause_matrix.md#september-21-fixed-struct-member-array-constraints) includes separate 2023 runs; iterative constraints are 18.5.7.1 in this edition. No edition-specific semantic difference or full-clause qualification is asserted.

The [descendant automatic VIF event checkpoint](matrices/ieee1800_2017_clause_matrix.md#september-21-descendant-automatic-vif-event-initialization) includes paired 2023 runtime and negative tests under §§6.21,8.6,9.3.2. No edition difference is asserted; broader qualification remains pending.

#### 2026-09-21: §18.5.3 large distribution range evidence

The paired large-range tests retain original declared range mass after hard exclusions, as specified explicitly in 2023. See [shared revision-scoped evidence](session_logs/2026-09-21_exact_large_dist_focus.json) for implementation boundaries and passing local gates; the 2017 record does not assume identical normative wording.

#### 2026-09-21: §9.4.2 synchronous mixed event evidence

The [shared mixed-event subset](matrices/ieee1800_2017_clause_matrix.md#september-21-synchronous-mixed-event-dependencies) has separate 2023 semantic and cancellation regressions. No edition-specific difference or full-clause qualification is asserted; required local gates pass in the linked revision-scoped evidence.

#### 2026-09-21: §9.4.2 whole-function class event evidence

The [shared class-method event subset](matrices/ieee1800_2017_clause_matrix.md#september-21-whole-function-class-event-dependencies) includes separate 2023 execution and negative tests. No edition-specific difference is asserted; limits and qualification status remain in the shared evidence.

#### 2026-09-21: §9.4.2 compound class-property event lists

The [shared event-list subset](matrices/ieee1800_2017_clause_matrix.md#september-21-compound-class-property-event-lists) has separate 2023 tests. Current validation and limitations are recorded in its shared evidence; no edition difference or full-clause qualification is asserted.

### 2026-09-22 — caller-owned integral collection constraints

The 2023 §18.7 / §18.5.7.1 subset shares implementation with the [2017 scope and evidence](matrices/ieee1800_2017_clause_matrix.md#2026-09-22--caller-owned-integral-collection-constraints). Paired 2023 tests have the same observed behavior; [qualification status](session_logs/2026-09-22_caller_queue_foreach_focus.json) remains scoped; required local gates pass.

The 2023 §18.5.11 inline state-function candidate has separate generation-mode tests but shares the [2017 implementation scope](matrices/ieee1800_2017_clause_matrix.md#2026-09-23--inline-constraint-state-function-calls). This edition explicitly prohibits `inout` formals and requires side-effect-free behavior. [Focused evidence](session_logs/2026-09-23_inline_state_function_focus.json) does not establish full-clause qualification.

The scalar caller-state X/Z repair uses the shared 18.3 rule in both editions;
the [2017 scope](matrices/ieee1800_2017_clause_matrix.md#september-23-scalar-caller-state-xz-constraints)
and [paired evidence](session_logs/2026-09-23_constraint_state_xz_port.json)
record the tested 2023 cases without a broader qualification claim.

The opt-in `-gcommercial-unsafe` container conversion is likewise a shared
implementation extension under the strict §7.6 default. Its limits and
revision-scoped evidence are recorded in the [2017 matrix](matrices/ieee1800_2017_clause_matrix.md);
separate 2017/2023 focused checks are included, while full-suite and OpenTitan
DV qualification remain unclaimed.

The 2023 §§16.9.2.1/16.12.7 rules for empty repetition and separate
nonoverlapping consequent attempts do not change the [bounded 2017
implementation scope](matrices/ieee1800_2017_clause_matrix.md#september-23-parameter-valued-sva-consequent-repetition).
Separate `-g2023` runtime, boundary, and invalid-bound results are in the
[shared evidence](session_logs/2026-09-23_caliptra_param_consequent_repeat_focus.json);
no full SVA or application qualification follows from them.

The one-step named-sequence antecedent follow-up shares the 2017 §§16.8 and
16.12.7 lowering. Separate `-g2023` executable and pinned ECC formal-bind
checks are in the [shared revision-scoped record](session_logs/2026-09-23_caliptra_named_sequence_antecedent.json);
multi-step symbolic-consequent compositions remain unsupported.

The fixed-linear overlap and assertion-VPI correction uses the same
§§16.12.7/16.14.1 and §39.4.2 rules in 2023 as in 2017. Separate `-g2023`
runtime and boundary checks are included in the [shared 2017 scope and
revision-scoped evidence](matrices/ieee1800_2017_clause_matrix.md#september-23-fixed-linear-sva-overlap-verdicts-and-vpi-identity).
