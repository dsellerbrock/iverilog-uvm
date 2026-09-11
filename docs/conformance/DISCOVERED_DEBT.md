# Discovered debt (parking lot)

This file exists so that finding a defect while working a different
`.ai/ACTIVE_WORK.yaml` ticket never becomes an excuse to widen that ticket.

**Recording an unrelated discovery completes the active agent's
responsibility for it during the current ticket.** Do not fix it, do not
investigate it further, do not expand scope to cover it. Record it below and
return to the active work item.

Triage (promoting an entry here into `docs/conformance/BLOCKERS.md`, or
opening a new `.ai/ACTIVE_WORK.yaml` ticket for it) is a separate activity
done outside any single targeted-fix run.

## Entry format

```markdown
### DD-<NNN> — <short observation>

- **Discovered while working:** <active blocker ID, or "governance
  bootstrap" / other non-blocker task>
- **Observation:** <what was seen>
- **File/function:** <path:line or symbol, if known>
- **Possible clause:** <IEEE clause if applicable, else N/A>
- **Evidence:** <how it was noticed — log excerpt, source read, etc.>
- **Reproducer status:** none / sketched / confirmed
- **Triage status:** untriaged / promoted to BLOCKERS.md as <ID> / declined (why)
```

---

No entries yet. This governance-bootstrap pass did not investigate
implementation code for defects (that would itself be an audit, which is
out of scope here) — nothing was discovered during this ticket that
requires parking. Use the format above for the next agent's discoveries.


### DD-001 — joint active-randc prepass and enumeration-cap interaction

- **Discovered while working:** Z01A
- **Observation:** Source review found a randc draw before complete component enumeration. A draw-dependent over-cap failure could condition successful calls on the selected value; not reproduced or claimed as a confirmed defect.
- **File/function:** vvp/vvp_z3.cc, z3_solve_pass_ randc prepass and exact_joint component enumeration.
- **Possible clause:** IEEE 1800-2017 18.4.2 / global constraint distributions; exact applicability needs triage.
- **Evidence:** Independent Z01A source review; ordered active-randc is explicitly excluded/rejected by Z01A.
- **Reproducer status:** sketched
- **Triage status:** untriaged


### DD-002 — associative member foreach loses string key type

- **Discovered while working:** L01
- **Observation:** foreach(boxes[selector].values[key]) with class member values[string] declares key as int and iterates zero entries. Same output and int key declaration with retained pre-L01 compiler and campaign runtime; not caused by the selected-prefix fix.
- **File/function:** pform_make_foreach_declarations / foreach_index_type_t unindexed member type resolution.
- **Possible clause:** IEEE 1800-2017/2023 12.7.3 implicit index type.
- **Evidence:** evidence/campaign-20260908/l01/typed*.sv, .vvp and logs; old compiler from preserved string-array-param-after253 worktree, a diagnostic comparison rather than a campaign qualification gate.
- **Reproducer status:** confirmed
- **Triage status:** resolved within the reviewed, locally validated L05 selected-member index-type scope; no repair included in L01. Broader container/header validation remains separate.

### DD-003 — Boolean event-expression driver discards automatic activation context

- Active blocker: L02. Record-only; not a regression from L02.
- Observation: simultaneous task activations using posedge (value[2] | 1'b0)
  both report transition time 2 instead of 2,3.
- Mechanism: vvp/logic.cc vvp_fun_boolean_ receives no retained context and
  vvp_fun_or::run_run sends its result with context 0; input storage is shared.
- Authority: IEEE 1800-2017/2023 6.21 and 9.4.2; expression event transition
  must use the invocation's value.
- Evidence: u01-loop/history-expression-preexisting.sv, history-baseline.log,
  history-baseline.vvp; fresh e0dab7221 compiler rebuilt into baseline-tools
  with original frame selection. Identical 2,2 failure on baseline and L02.
- Reproducer status: resolved within reviewed locally validated L03 Boolean
  functor family and supported input chains. Other expression families remain
  unqualified; no general expression-correctness claim.

### DD-004 — Unchanged partial write can manufacture a default-bit negedge

- Active blocker: L02; record-only, not introduced by frame selection.
- Observation: default bit vector 0, unchanged value[2:1]=0 at t1 wakes
  negedge value[0], although the intended first negedge is at t3.
- Mechanism: vvp_fun_signal4_aa::reset_instance emits no initial sample;
  recv_vec4_pv sends even an unchanged vector, exposing probe history X.
- Authority: IEEE 1800-2017/2023 6.8 and 9.4.2.
- Evidence: u01-loop/default-negedge.sv and baseline/candidate logs, both
  fail at t1. Original e0dab7221 compiler frame layout also fails with the
  candidate runtime; native probe path has no ancestor history to seed.
- Reproducer status: resolved within L04 reviewed locally validated automatic integral default publication. Broader types and derived Boolean contexts remain unqualified.

### DD-005 — Non-fanout assertion paths omit vacuous user pass actions

- Active blocker: S03; record-only outside the endpoint aggregation path.
- Observation: `tests/sva_recursive_consequent_test.sv` executes17 enabled
  starts; the fixed negated consequence has one nonvacuous success and one
  failure, but reports only1pass rather than16 including vacuity. Existing
  until/eventual controls similarly count only nonvacuous successes.
- Mechanism: unchanged non-endpoint NFA/legacy implication handling suppresses
  vacuous pass dispatch. S03 repairs only the split endpoint parent path.
- Authority: IEEE1800-2017/2023 16.12.7; a no-match antecedent succeeds.
- Evidence: campaign-20260908/s03/recursive-red-2017.log and2023.log;
  old baseline test already expects1pass, and the unaffected source path
  omits its vacuous action. Nested/throughout parent paths now report17.
- Reproducer status: observed in both editions; triage pending. Do not infer
  general vacuity qualification from the S03 endpoint-path controls.

### DD-006 — nested parameterized sequence alias does not expand

- **Discovered while working:** S04.
- **Observation:** Pair(x,y) defined as x ##2 y works when reused directly with distinct actuals in OR/AND antecedents. Wrapping Pair(a,b) and Pair(c,d) in named Left/Right aliases instead reports No function named Pair during elaboration.
- **File/function:** pform.cc sequence splicing / parameter-window antecedent normalization; causal triage pending.
- **Possible clause:** IEEE 1800-2017/2023 sequence declarations and argument binding; exact clause pending triage.
- **Evidence:** evidence/campaign-20260908/s04/window-nested-alias.sv and window-nested-alias.log. Same four errors with compiler rebuilt from validated61ca5f336: window-nested-baseline.log. Current source/build restored afterwards; installed candidate tools unchanged during running gates.
- **Reproducer status:** confirmed before S04; direct parameterized reuse is a passing control.
- **Triage status:** resolved within S07 reviewed locally validated bare-alias recursive expansion scope; full dependency-graph validation and broader parameterized declaration lookup remain unqualified.

### DD-007 — symbolic repetition still reports consequent endpoint verdicts

- **Discovered while working:** S04 oracle review.
- **Observation:** Symbolic ranged/unbounded antecedent lowering retains per-endpoint consequent pass/fail actions, rather than aggregating one parent assertion verdict. S03 repaired the NFA parent model, not this separate symbolic engine. S04 only repairs previously missing vacuity for ages that never matched.
- **File/function:** pform.cc sva_parameter_repeat_try_assertion_ r_pass_req/r_fail_req and endpoint counts.
- **Possible clause:** IEEE 1800-2017/2023 16.12.7 and 16.14.1.
- **Evidence:** Existing validated sv_assert_repeat_parameter_override and sv_assert_repeat_parameter_smoke tests explicitly expected multiple endpoint actions before S04. Independent S04 review derived their new totals by adding vacuity; these remain compatibility checks, not per-attempt standards qualification. No new regression inferred from those totals.
- **Reproducer status:** existing regression stimuli retained; parent-verdict reducer needs a deliberate selection boundary.
- **Triage status:** resolved within S05 locally validated fixed ##0/##1 symbolic repetition scope. Broader symbolic consequent-delay overrides remain DD-008 and are not covered by this qualification.

### DD-008 — symbolic consequent delay override uses the default

- **Discovered while working:** S05 boundary reducer construction.
- **Observation:** `a[*LO:HI] |-> ##D q` with defaults LO1/HI2/D0 and instance D1 passes at the second tick instead of awaiting the final child at tick3; making q false at tick3 produces no failure. Explicit literal ##1 is a passing control in the S05 paired reducers.
- **File/function:** pform.cc cycle-delay normalization and symbolic repetition probe; causal triage pending.
- **Possible clause:** IEEE1800-2017/2023 6.20.2,16.9,16.12.7; exact delay-normalization cause unverified.
- **Evidence:** campaign-20260908/s05/parameter-delay-override.sv and .log; current candidate produces EARLY1/0 then1/0. First observed before the S05 parent edit; no retained pre-S05 isolated reducer result, so baseline comparison remains required.
- **Reproducer status:** reduced current failure; literal-delay control passes.
- **Triage status:** resolved within the reviewed, locally validated S06 single named parameter/localparam delay scope. Broader delay-expression syntax, composed/multiclock shapes, formal lookup and maximal-width arithmetic remain unqualified.


### DD-009 — Invalid foreach header selector accepts an implicit string key

- **Discovered while working:** L05
- **Observation:** foreach(boxes[key].values[key]) where boxes is fixed-size
  and values is string-keyed compiles despite the implicit key being string.
  The attempted outer-key positive interpretation was withdrawn after IEEE
  12.7.1/12.7.3 review; both Slang editions reject the string selector.
- **File/function:** Selected target expression/index type validation; not
  isolated to a specific lower-level check yet.
- **Possible clause:** IEEE1800-2017/2023 7.4.2,12.7.1,12.7.3.
- **Evidence:** campaign-20260908/l05/shadow-invalid-positive.sv and design
  review. Existing runtime target binding was preserved, not changed to
  make this invalid positive case pass.
- **Reproducer status:** Candidate acceptance observed; exact diagnostic
  reducer and pre-existing validation mechanism remain to be isolated.
- **Triage status:** record-only; no repair or invalid-header qualification
  is included in L05's legal selected-member index-type increment.

### DD-010 — Uninstantiated merged covergroup type enters overall denominator

- **Discovered while working:** V06 final scope-control review.
- **Observation:** One fully covered instantiated type plus a declared but
  uninstantiated merged type produces overall50 rather than100 percent.
- **File/function:** vvp/class_type.cc type_coverage/registry eligibility and
  vvp/vthread.cc of_COVGRP_GET_ALL; exact correction not yet selected.
- **Possible clause:** IEEE1800-2017/2023 19.9,19.11,19.11.3; complete eligibility
  semantics require review at selection.
- **Evidence:** campaign-20260908/v06/uninstantiated-type.sv and candidate/v05
  logs. Both candidate and saved validated V05 runtime reproduce50 vs100.
  For V05 compatibility only the new item-type-weight tags were removed from
  emitted bytecode; every item/type weight in this reducer is1.
- **Reproducer status:** Pre-existing runtime failure established on V05;
  no source repair or broad application qualification inferred.
- **Triage status:** record-only during V06. V06 function-scope test instantiates
  all intended groups before checking their weighted aggregate; its bin/type
  weight assertions remain explicit and independently checked.

- **DD-010 resolution:** V07 locally validates the shared population guard with
  paired lifecycle controls and full required local gates. Never-instantiated
  types are excluded; zero-weight retired merged instances remain represented.
  Remote CI and broader coverage qualification remain separate.


### DD-011 — UVM release-matrix compile frontiers

- **Discovered while working:** U02 user-requested release acquisition/probes.
- **Evidence:** `docs/conformance/uvm_release_matrix.md` and local
  `third_party/uvm-releases/results-pv87b5yu/results.json`; unmodified releases,
  compiler/runtime implementation03caa64c8, actual-g2012.
- **Observed:** Legacy1.x/2017 libraries encounter member-delay syntax (1.0p1
  also reports process class lookup);2020.1.0/1.1 encounter nested resource
  queue type/assignment errors;2020.3.2 rejects default-initialized unpacked
  struct queue `accesses` in uvm_reg_map.svh2058. Later diagnostics may cascade.
- **Classification:** Reproduced compile gaps, not yet reduced/standards-classified.
  Do not label nonstandard library syntax a mandatory IEEE compiler defect.
- **Triage:** Record-only during U02; select and ground one causal mechanism
  before any semantic fix. No archived library or application source patched.


- **L08 candidate follow-up:** Original2020.1.0/1.1 now compile at47e6c87b3, but both are RUNTIME_FAIL in results-gizcr5j0 (complete=true,baseline_valid=true). Runtime logs report unresolved uvm_re_match/uvm_glob_to_re DPI symbols followed by command-line UVM errors and BUILDERR. Record-only pending L08 validation; release-specific DPI loading/ABI and runtime semantics are not qualified. No library edits.


### DD-012 — L06 mixed-array and class-qualified declaration boundaries

- **Discovered while working:** L06 expanded initialization controls.
- **Evidence:** evidence/campaign-20260908/l06/class-qualified-module-declaration.sv
  and queue-of-fixed-array.sv plus compile logs; no fixes included.
- **Observed:** Module-level class-qualified declarations hit parser errors;
  the supported procedural class-qualified form is covered positively. Queues
  of fixed-array elements hit the existing netuarray_t unsupported boundary.
- **Triage:** Record-only. Permanent array boundary tests guard against wrong
  dimension classification but do not qualify those legal unimplemented shapes.

### DD-013 — Last-element queue lvalue crashes elaboration

- **Discovered while working:** L06 officialUVM2020.3.2 replay after queue-default fix.
- **Evidence:** UVM uvm_field_op.svh112 assigns msg_queue[$]; minimal
  evidence/campaign-20260908/l06/queue-last-lvalue.sv creates stringq, pushes
  one element and assigns q[$]. Expected replacement of the last element.
- **Observed:** Saved validated03caa64c8 compiler and L06 candidate both abort
  at elab_lval.cc1335 use_sel==SEL_NONE in2017/2023. Four logs preserve proof.
- **Triage:** Proven preexisting next-blocker candidate; not caused by L06,
  not repaired in its patch. UVM2020.3.2 is still COMPILE_FAIL/unqualified.

- **L07 follow-up:** Direct queue-variable element assignment fixed and locally validated at `9a1b6beb3`. Unmodified2020.3.2 now passes the release smoke. Class-property/root-member last-index forms remain outside the resolved scope.

### DD-014 — Terminal process kill loses descendant reachability

- **Discovered while working:** U01 teardown source tracing; record-only.
- **Observation:** `of_PROCESS_KILL` returns immediately when the process has no
  owner or already reports FINISHED/KILLED. Thread reaping reparents detached
  children. This appears unable to kill live descendants through a retained
  handle to a terminated parent.
- **File/function:** `vvp/vthread.cc`, `of_PROCESS_KILL`, `vthread_reap`.
- **Possible clause:** IEEE 1800-2023 9.7 explicitly requires killing live
  descendants even when the target is FINISHED/KILLED. The 2017 wording differs
  and needs separate qualification; do not infer identical edition requirements.
- **Evidence:** Current source at validated semantic revision `9a1b6beb3` and
  local primary LRM text; no attribution to U01's intermittent warnings.
- **Reproducer status:** none.
- **Triage status:** untriaged; no implementation authorized by this entry.

### DD-015 — Function-valued UVM core-state wait diagnostic woke early

- **Discovered while working:** U01 post-report observer construction.
- **Observation:** An added diagnostic top using
  `wait (get_core_state() == UVM_CORE_FINISHED)` continued at time zero and
  stopped the application at 1 ns. This invalidated the observer attempt; it
  is not application qualification or proof of a compiler defect.
- **File/function:** `uvm-core/src/base/uvm_globals.svh`, `get_core_state`;
  evidence `u01-after-l07/teardown_observer_wait_attempt.sv` and
  `teardown-observer.log` preserve the attempt.
- **Possible clause:** Wait expression evaluation and function dependencies;
  exact applicable semantics and cause remain to be established.
- **Reproducer status:** diagnostic observation only; not minimized.
- **Triage status:** untriaged, record-only. U01 observer now uses a bounded
  explicit time after the known smoke completion and verifies log ordering.

### DD-016 — Regex edge cases during legacy ABI comparison

- **Discovered during:** U04 read-only legacy/modern regex comparison, before U05 prerequisite selection.
- **Evidence:** Modern uvm-core/src/dpi/uvm_regex.cc uvm_re_comp strips slash brackets without the legacy len>1 guard; the single-slash input appears to underflow re_len-2. Source-only, not yet reduced; do not claim a runtime defect without evidence. Legacy2020.1 glob_to_re bracketed-input branch also falls through into the tail rather than preserving input, unlike modern conversion.
- **Disposition:** Record-only; original vendor code unchanged. U04 must define explicit regex/empty/slash/bracket/error expectations before any ABI delegation; upstream behavior is not automatically normative.

### DD-017 — Original UVM2020.1 smoke exits before intended phase checks

- **Discovered during:** U04 original-release replay.
- **Evidence:** results-9mvpk_8f complete=true,baseline_valid=true; both original2020.1 releases compile0/runtime0, no unresolved DPI symbols or command-line UVM errors, but finish at time0 without required smoke completion marker. Direct legacy ABI tests pass4/4 across both releases/editions.
- **Disposition:** Record-only during U04; still RUNTIME_FAIL. Establish whether the intended run-phase traffic/checking executes and reduce the causal mechanism after the current semantic baseline is validated. No warning waivers or application edits.

U06 closes the recursive-input cause after full validation at aad6fe22b.
Original2020.1.0/1.1 now pass their unchanged smoke; full qualification remains separate.

### DD018 — Nested argument output copy-out selects staged caller scope

Discovered under U06. Evidence-only copyout_control.sv and
copyout-baseline.log/copyout-candidate.log in evidence/campaign-20260908/u06
show identical failures on validated aa172f5 runtime and U06 candidate.
A recursive method passes get_child(output seen) as an argument; seen is
an automatic caller local. Generated copy-out stores through the staged
outer callee frame instead of the caller frame. Both runs fail the output
assertion when input assertions are removed to isolate this behavior.
IEEE 1800-2017/2023 13.5 argument passing is the applicable cluster; exact
copy-out correction remains untriaged. Symbols: draw_copy_out_function_argument,
scoped write-context selection. Original smoke has no such output actual.
Record-only, not a U06 regression or a qualified subcase; preserve reducer
for deliberate selection after validating the input-context increment.

DD018 resolved by L09 at 3c44fd13b after required local validation.
Caller actual context and formal source context are now selected separately.

### DD019 — Scalar output into fixed-array class property element

L09 probe fixed_property_output.sv (evidence/campaign-20260908/l09) produces
"Skipping indexed property copy-out" on both validated U06 target and L09
candidate. Existing emitter supports certain container-valued property
elements but not this scalar fixed-array slot. Compile baseline diagnostic
is preserved in fixed-property-baseline-compile.log. Legal output lvalue
classification belongs to IEEE2017/2023 13.5 and class array properties;
implementation remains open. Record-only during L09; no warning waiver or
claim of fixed-array property-element output support.


### DD020 — Scalar output actuals evaluated before call and on return

L10 index-side-effect control fails on candidate because scalar output actuals
are copied in before function execution. Existing function_port_is_container_output_
only suppresses container/fixed-array output input evaluation. The same issue
applies to plain fixed-array scalar actuals on validated L09, independent of
L10 property stores. IEEE2017/2023 13.5 return copying; must preserve automatic
formal defaults and static output persistence. Selected prerequisite L11; L10
patch and reducers preserved under evidence/campaign-20260908/l10.

L10 receiver().slots[...] syntax probe was rejected by parser; preserved in
receiver_syntax_probe.sv. Not required for nested env.box receiver coverage;
record-only syntax frontier, no parser changes under L10.

DD020 resolved by L11 at b32df9a29 after all required local gates.


L10 conversion probes found ordinary string/integral assignments are permissively
accepted by the existing frontend despite6.16 requiring explicit casts. Preserved
`evidence/campaign-20260908/l10/string_assignment_control.sv`; broader assignment
diagnostic debt is record-only. L10 now rejects the fixed-property output
mismatch so its new typed stores cannot execute a mismatched load opcode.

DD019 resolved by L10 at051aeee8e after validatedL11 prerequisite and all required local gates.


### DD021 — UVM1.2 frontiers after member-delay parsing

U07 candidate original1.2 probe `third_party/uvm-releases/results-sv_woyjp`
gets past #setting.offset but fails elaboration: uvm_printer.svh1172 reports
an unsupported index on struct member val, and uvm_traversal.svh284-285 reports
hierarchical references to automatically allocated compiled_regex in visit.
The upstream declaration is explicitly `static chandle compiled_regex`;
reduce lifetime handling and hierarchical lookup rather than assuming the diagnostic is correct.
A uvm_sequence_base.svh1255 pick_sequence constraint item is also reported
unrepresentable and ignored. These remain separate semantic/diagnostic
frontiers; no UVM pass or waiver. Source trees unchanged; record-only during
U07, reduce/classify at a later coordinator boundary.

### DD022 — Original UVM 2017.0.9 smoke runtime timeout

U07 full release sweep `third_party/uvm-releases/results-4r1diuop`
compiles unchanged 2017.0.9 successfully, then its runtime times out after
300.059 seconds with an empty log. The earlier baseline rejected member-delay
syntax before runtime. Source hash and exact commands are preserved in results.json.
No causal runtime diagnosis yet; timeout is not proof of a scheduler defect.
2017.1.0 and 2017.1.1 now pass all smoke checks. Record-only during U07;
reduce and classify at a later coordination boundary. Full release remains open.

### DD023 — Unknown ordinary string index behavior

During L12 control testing, an ordinary string `s="@abc"` read at integer
X or Z index returns character64 for both `s[i]` and `s.getc(i)`. Negative
and length indices return0. The runtime string select reads an integer word
without its unknown flag. Evidence `evidence/campaign-20260908/l12/bounds_control.sv`.
Needs standards classification; not claimed qualified and record-only for L12.

### DD024 — String character selection loses signed byte type

L12 high-bit control shows ordinary and proposed member indexing widen0xff to255, while getc/byte cast yield-1. Both-edition6.16 and6.11.3 require signed byte. Selected as prerequisite L13; L12 partial work preserved and source restored before new baseline. Prior9baa5a9c3 gates passed, but reopened after narrow two-state parameter index2 returned0 instead of the third byte. Corrected by849a779ea with source-signed resize and separate signed int cast; all required gates pass. L12 may resume.

### DD025 — Class string-property character index uses property slot

L13 control `c.s[1]` with `c.s="abc"` aborts in class_type.cc get_string
array_size assertion on both saved L10 compiler and L13 candidate. Index0
returns whole string instead of character. Exact reducer `evidence/l13/class_control.sv`
and L12 byte_type probe retained. Distinct property dispatch defect, not
introduced by signed-byte typing; record-only, no class-property character
qualification claimed by L13.

### DD026 — Constant function string argument character result unknown

L13 `constant_probe.sv` contains automatic int function get_value(input string s)
returning s[0], evaluated for a localparam. Both saved L10 and L13 candidates
produce X for that constant-function result; direct typed parameter selection
is a distinct L13 width issue now in scope. Evidence/l13/constant_probe_results.json.
Record-only for constant-function argument/evaluation classification; no
constant-function string qualification claim.

DD023 follow-up during resumed L12: with "abcde" and a four-state integer
index ending in1x, ordinary s[idx] and initial L12 member path returned'a',
while getc(idx) returned'c'. Both editions6.16/getc(int) and6.11.2 require
per-bit two-state conversion. L12 now uses the existing int2/32 cast for its
new member path; ordinary string index lowering remains a separate proven
gap. Evidence/l12/index_conversion.sv. No ordinary-selector fix included.

### DD027 — Original UVM1.1d compiles but does not pass smoke

L12 candidatea85a256b1 removes the member-string elaboration frontier. Original1.1d now compiles with ignored-constraint and object-expression null-fallback warnings, then runtime exits0 but fails the smoke qualification checks. Evidence third_party/uvm-releases/results-qb7873zh/1.1d/{compile,runtime}.log. Runtime reports missing DPI symbol uvm_dpi_regcomp, four command-line regex UVM_ERRORs and one BUILDERR UVM_FATAL, then exits0 before smoke completion. Exit0 is not a smoke pass. Record-only during L12 required validation.

DD021 follow-up: L12 candidate removes original1.2 printer string-index errors. Four remaining compilation errors at uvm_traversal.svh284-285 concern compiled_regex in visit, plus the existing ignored pick_sequence constraint warning. Original1.1a now reaches fork/join_any-in-function and void-cast-of-void diagnostics; standards legality must be verified before selecting changes. No library edits or qualification claims.

### DD028 — Original UVM1.2 smoke runtime produces no output before timeout

L14 candidate69ff60cc6 removes all four visit.compiled_regex reference errors. Original1.2 compiles0 in0.635s, then runtime times out after300.061s with empty runtime.log (return-9). Evidence third_party/uvm-releases/results-f9qr050b/1.2 and results.json. Ignored pick_sequence constraint and newly reached object-codegen null-fallback warnings remain visible. No relationship to the already known2017.0.9 timeout is proven. Select and reduce after L14 required gates; do not infer startup, scheduler, DPI or initialization cause from an empty log alone.

### DD029 — General class method visibility fallback gaps

U08 review observed local base methods still accessible when no enclosing homonym exists, and through explicit class qualification. Existing method_from_name and later call fallbacks do not enforce complete method access control. U08 is bounded to inherited lexical precedence over enclosing homonyms; it retains qualifier metadata and prevents a package-selected statement call being re-resolved to a local base method. General no-homonym/explicit-qualified access checks remain separate qualification debt, not a completed8.18 feature.

### DD030 — Original UVM1.2 reaches missing legacy regex DPI

U08 development replay results-pqt3anxi removes the root-construction recursion and starts release_test, then reports missing uvm_dpi_regcomp, five command-line regex UVM_ERRORs and one BUILDERR UVM_FATAL. Result RUNTIME_FAIL, not smoke/application pass. Original source tree unchanged. Pinned1.2 src/dpi/uvm_svcmd_dpi.c already defines uvm_dpi_regcomp/regexec/regfree using POSIX REG_NOSUB|REG_EXTENDED; current fork umbrella includes the modern source, which lacks those exported entry points. User requested investigation. Preserve legacy strict regex semantics, allocation/free behavior and error reporting when selecting DPI work after U08 validation; do not simply alias to the modern glob-retry wrapper.


DD027/DD030 resolution (U09,19e7f5592): cached-regex exports and callback-aware
error reporting now pass focused original1.1d/1.2 checks in both editions.
Full required local gates pass. Both original releases pass smoke in
results-n2m35ki0 with unchanged source fingerprints. Other compile-time
constraint/codegen warnings and full application qualification remain open.

### DD031 — OpenTitan original1.2 macro expansion frontier

U10 replay uses explicit original1.2 root and records src hash
885ba9f74652494aa132aaaa26c43e9f210f94cdf5a8d3a87064993ec9b35dc0.
Pinned7a3ad34 debug crossbar compile exits74; first diagnostics are missing
argument list for uvm_print_aa_string_int at dv_base_env_cfg.sv112/114,
followed by parser cascades. No simulation or traffic ran.
Evidence evidence/campaign-20260908/u10/result.json and matrix-compile.log.
Record-only during U10 harness qualification; macro source/expansion and both
LRM editions require investigation before selecting any compiler change.

DD031 resolution (L15,aa356ab4d): complete pasted function-like names now expand
correctly under both editions and all required local gates pass. Fresh original1.2
OpenTitan replay removes the macro errors and cascades with unchanged UVM source
hash; compilation now exits3 at the distinct const-handle assignment frontier.

### DD032 — Mutable member assignment through a const class handle rejected

After validated L15, original1.2 OpenTitan debug crossbar compile fails three
times at dv_base_test.sv92: uvm_top.enable_print_topology = print_topology.
The diagnostic says assignment to const signal uvm_top is not allowed, although
the target is a mutable member of its referenced object. Evidence
evidence/campaign-20260908/l15/opentitan/result.json and matrix-compile.log;
source hash885ba9f74652494aa132aaaa26c43e9f210f94cdf5a8d3a87064993ec9b35dc0.
No simulation ran. Record-only during L15 closure; verify both editions and
reduce before selecting a const-handle elaboration fix.

### DD033 — Explicit package-qualified member compound assignment parser gap

L16 development positive fixture used const_handle_pkg::shared.value += 2 and
both editions rejected its statement syntax before elaboration. Imported
shared.value += 2 works and is the selected const-handle test. Preserved
evidence/l16/development.json; explicit qualified compound assignment is
record-only and not part of L16's bounded direct handle const check.

### DD034 — Existing class-member lookup/const-chain limitations

L16 independent source review confirmed the existing class-member walker can
warn and discard an unknown property write, and rejects traversal through an
intermediate const class-handle property even when the leaf is mutable.
L16 enables only direct scalar const-handle variables with existing writable
members; it does not qualify unknown-member diagnostics or const property
chains. These source-inspection findings need dedicated reducers before
implementation; no correctness claim for those paths.

DD032 resolution (L16,5ba60567f): mutable member writes through scalar const
class-handle variables pass both editions and full required gates. Original1.2
OpenTitan const-handle errors are removed. Replay runs normally with
152requests/288scoreboard items and zero UVM warnings/errors/fatals, but overall
DEBT remains because five compile-time null-substitution diagnostics persist.

### DD035 — Integral compound updates of UVM register item array members emit null

Validated L16 original1.2 OpenTitan replay reports five draw_eval_object
null-fallback warnings: uvm_reg.svh2501 (rw.value[0] &= ~wo_mask),2173
(rw.value[0] &= ((1 << m_n_bits)-1)), uvm_reg_field.svh1483,
uvm_reg_map.svh2109 (rw.value[val_idx] |= shifted data), and
uvm_reg_predictor.svh192 (reg_item.value[0] |= shifted data).
These integral selected-element operations should not take object-RHS
evaluation. Evidence evidence/campaign-20260908/l16/opentitan/{result.json,
matrix/runtime/lowrisc_dv_top_darjeeling_xbar_dbg_sim_0.1/matrix-compile.log}.
Runtime0/pass banner/zero UVM severities does not waive compile-time semantic
debt. Reduce and trace a concrete selected-element compound assignment before
selecting an implementation change; full UVM/application qualification open.

### DD036 — Compound operands prematurely converted to destination width/state

During L17 focused review, byte property >>=32'd256 reaches VVP as an8bit
zero shift count; /=32'd256 also reaches division with zero divisor, whose
unknown result was masked by the two-state destination. netmisc.cc
elab_and_eval destination casting loses width/state before target lowering.
Four-state RHS into two-state compound target must retain X until the final
result conversion. Preserve l17/focus.vvp,focus.log,partial.patch. Separate
prerequisite selection required after L18; not repaired by target width logic.
