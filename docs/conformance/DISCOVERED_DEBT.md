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

DD035 resolution: L17 d8e974913 implements integral whole-element dynamic-array
property compound updates after validated operand/receiver prerequisites. All
required gates pass; fresh original1.2 debug-crossbar smoke reports PASS with
all five substitution warnings absent. Full container/UVM qualification remains open.

### DD036 — Compound operands prematurely converted to destination width/state

During L17 focused review, byte property >>=32'd256 reaches VVP as an8bit
zero shift count; /=32'd256 also reaches division with zero divisor, whose
unknown result was masked by the two-state destination. netmisc.cc
elab_and_eval destination casting loses width/state before target lowering.
Four-state RHS into two-state compound target must retain X until the final
result conversion. Preserve l17/focus.vvp,focus.log,partial.patch. Separate
prerequisite selection required after L18; not repaired by target width logic.

L18 review note: associative compound expansion in elaborate.cc independently
reads the old get_signed flag. Existing source-inspection limitation, no
new reducer or qualification claim; outside scalar-property L18 scope.

DD036 L20 review boundary: existing associative front-end expansion builds
its binary expression at destination width before the compressed target
helper. Migrating the target's associative callers does not qualify that
separate expansion; preserve as residual width debt requiring its own reducer.
L20 claims the ordinary compressed vector paths and permanent tested shapes.

DD036 associative expression width/sign/state scope resolved by L31 at0a4e7d639
after allrequiredlocalgates. Declared element signedness and binary context now
precede extension, with final assignment conversion at store. Mixed unsigned,
wide arithmetic, self-determined shifts, state and local/property controls pass.
This does not qualify all associative compound semantics: preexisting key/receiver
reevaluation in the expansion remains a separate unqualified scope.

### DD037 — Captured class mutation notification undoes handle rebinding

L17 resumed receiver test and standalone scalar-property reducer show
notify_mutated_object_root_ sending captured root_obj back to root_net after
RHS rebinds it. Original object updates correctly but h reverts to old handle.
Evidence l17/receiver-debug and l21/red; vvp/vthread.cc19414. Selected as
L21 prerequisite at deliberate suspension boundary; no value-aggregate or
static-overlay correctness claim beyond tested contexts.

### DD038 — Legacy 1.1b/c vendor-only recording macro

At L17/L22 selection, unchanged1.1b/c macros/uvm_object_defines.svh defines
uvm_record_attribute only for QUESTA/VCS/INCA, but generic payload calls it
unconditionally. Current compiler warns undefined macro then parser recovery
asserts. Do not define a commercial-vendor macro or empty recording operation
to claim support. Recording compatibility and parser robustness require separate
assessment; original sources unchanged. Evidence results-3d_bbaiu compile logs.

DD038 design review at30b803071: parser recovery is now normal rejection
(L29), while the missing recording API remains. Independent source review rejects
an adapter that concatenates $typename with %p and calls m_set_attribute:
%p uses decimal/%g/string formatting rather than a lossless typed encoding;
the direct attribute macro has no lexical recorder argument; base uvm_recorder
bypasses the attribute macro and may record literal description text. These are
reasons not to use formatting as typed serialization, not a claim that every
%p formatting choice violates its own IEEE contract.

The original typed-value/no-artificial-width-limit recording objective remains
mandatory. Proposed native backend decomposition, to select only after L31
validation: (1) real handle ownership/lifecycle and inspectable stream/begin/
link/end/free events; (2) typed value capture preserving schema, widths, four-state
bits, real precision, strings and object identity/cycles; (3) deterministic
legacy-recorder installation and original1.1b/c integration. No macro no-op or
text-only substitute. Parent recording support stays incomplete until its full
contract is implemented and qualified.

First prerequisite should use an explicitly instantiated native-compatible
recorder before any global installation. Preserve upstream sources and actual
handle allocation. Upstream handles/m_handles are static, but file descriptors
and filenames are per recorder; native ownership must add owner/kind/lifecycle,
not reuse check_handle_kind as an ownership oracle. Avoid shared-default-filename
collisions. Failed superclass allocations return0 or-1 and must not register.
Ended-but-unfreed handles stay linkable; cross-owner links are legal. Component
begin/end can select different current recorders, unlike transaction.m_recorder;
route by original ownership. Arbitrary custom recorder integer namespaces can
collide, so native compatibility needs an explicit registration contract, never
silent adoption. A later initial block is not a deterministic default installer;
user static initializers and explicit custom recorder selection must be preserved.
Use an already-compilable original legacy release for initial lifecycle coverage;
keep1.1b/c compile reducers intact until the actual attribute API is available.
Evidence: independent recording_design_review, source anchors
uvm_recorder.svh40-41/247-365,uvm_object_globals.svh666,
uvm_component.svh2597-2760,uvm_transaction.svh667-671/776-784,
uvm_object.svh1294-1313 in original1.1b. Read-only review; no implementation
selected or changed while L31 is awaiting validation. Cross-model review skipped
in this automated continuation.

U14 concrete API review: use native lifecycle operations through the existing
context-DPI umbrella. Preserve explicit begin/end time as unsigned64, separate
from event occurrence time. Transaction-kind queries must see globally registered
transactions (including ended/unfreed) because component2649 uses that query
before linking its handle to the transaction's separately owned handle. Fiber
queries must require owner identity to invalidate stale component stream caches.
Mutation ownership stays separate. Child links are parent-to-child; caller may
own the right endpoint (transaction743/component2645), so a source-owner-only
link rule is incorrect. Preserve direction and both owners plus issuing recorder.

Native state/journal is authoritative; do not claim atomic commits across native
and superclass text logs. Validate before existing-handle mutations, reject
re-registration of retained ended handles, retain ended handles for links, and
specify live-transaction free behavior (upstream allows it). Journal write/flush
failure poisons the owner; later operations cannot report successful continuation.
If superclass allocation precedes failed native registration, explicitly undo
its membership when possible and fail the operation. New journal creation must
be exclusive, not exists-then-open, and must not collide with superclass text
output before its first open. Per-simulation cleanup must clear registry/callback
state as well as close native-owned streams. Full test must exercise actual
cross-owner begin_child_tr and component/transaction dual recording; manual links
alone would miss both API traps. These findings refine U14 before implementation;
no native source has been changed yet.

### DD039 — Bare class-scoped module variable declarations

During L22 negative-test construction, bare process::state s at module scope
parses as invalid instantiation. Independent ordinary class reducer
`class holder; typedef int state; endclass` followed by module holder::state s
fails the same way, outside the new builtin-specific lookup branch. Local
procedural declarations and typedef aliases work. Record-only general parser
gap; no grammar expansion under L22. Evidence l22/direct-module-state.sv and
ordinary-class-scoped-module.{sv,json}; bare module scope remains unqualified.

DD039 direct complete-class module declaration scope resolved by L30 at34787868e
after all required local gates. Enum identity, packed/unpacked shapes, initializers,
inherited typedefs, concrete aliases and process::state controls pass both editions.
Missing/non-type/incomplete/typeparameter prefixes remain rejected. Arbitrary
nested or parameterized class grammar and complete class qualification remain open.

### DD040 — Nested fork in a function-spawned background process

L22 release sweep now reaches UVM1.0p1 uvm_objection.svh m_forked_drop:
a function contains outer fork/join_none with nested fork/join_any in its
child begin/end. Existing diagnostic rejects inner join_any as function code.
IEEE1800-2023 13.4.4 allows task-legal statements inside function fork/join_none;
2017 wording and actual elaboration context need reducer/trace before selection.
UVM1.1a reports the same frontier. Record-only under L22; no dependent patch
on the unvalidated baseline. Evidence results-p7axbpcu/1.0p1/compile.log.

DD040 resolution: L23 58edf8034 permits blocking joins inside function-spawned
background children, retains direct-function rejection, and passes all required
gates. Original1.0p1/1.1a nested-fork errors removed; no full release pass.

### DD041 — Void function call in dedicated void-cast statement form

L23 original1.0p1/1.1a replay reaches three void'(void_function()) errors
(find_all/get_args). Independent standards review: both editions13.5 Syntax13-3
and AnnexA.6.9 allow void'(function_subroutine_call); A.8.2 does not restrict
return type. 13.4.1 forbids void functions as expressions but does not explicitly
forbid this dedicated statement form; ordinary6.24.1 cast grammar excludes void.
Candidate overly restrictive diagnostic, not established upstream-invalid source.
Permitted-statement reading is an inference needing a scoped ticket/reducer;
no relaxation or implementation during L23. Preserve calls/arguments/restrictions,
never fabricate a value or generalize to task/arbitrary-expression casts.
Evidence results-2hbuhcyt1.0p1/1.1a compile logs and original source.

### DD042 — Pre-1.1d command-line and regex DPI entry points

L24 makes original1.0p1/1.1a compile and start. Both then fail unresolved
DPI symbols dpi_get_next_arg_c/dpi_regcomp, producing four UVM command-line
regex errors (1.1a terminates BUILDERR at time0). 1.0p1 reaches smoke banner but
has errors and unresolved-functor/$cast diagnostics, so remains RUNTIME_FAIL.
Old native ABI must be inspected before reusing newer U09 cached-regex helpers;
no fabricated empty argv/regex match or DPI-disabled bypass. Record-only under
L24. Evidence results-6_pvcxya/{1.0p1,1.1a}/runtime.log.

### DD043 — Release smoke harness misses simulator runtime errors

During U11, original1.0p1 has no missing DPI and reaches its marker with zero
UVM summary counts, but still prints three unresolved-functor placeholder-net
and two failed-$cast runtime error lines already present under L24. The unchanged
smoke_passed helper checks exit/marker/UVM summaries only and incorrectly emits
SMOKE_PASS in results-zyhh1jv9. That raw row is explicitly disqualified; no clean
pass or full implementation claim. Original1.1a is a clean new smoke pass.
Record-only during U11; select a bounded harness-classification ticket at next
coordination boundary, retaining offending logs as negative regression evidence.
No compiler workaround or filtering of errors. 1.0p1 actual semantic gaps remain
separate from fixing the false-positive classifier.

DD043 resolved by U12 at1654dc4c9: fresh results-fm8uvyiv classifies1.0p1
RUNTIME_FAIL;quoted UVM_INFO remains informational. Underlying1.0p1 runtime
errors remain open. No original source or compiler changes.

### DD044 — Generic-seed callback initialization remains after L26 reducer fix

The larger `l26/forward-registry.sv` reducer has two failed casts before L26
and one after the concrete default-identity fix. The remaining failing method
belongs to a specialization keyed with unresolved forwarding from a generic
master, yet a static initialization thread calls it. Original UVM1.0p1 still
has two callback cast diagnostics in results-8054igtp and remains RUNTIME_FAIL.
This is evidence for the next bounded investigation, not yet a complete causal
explanation of both original errors. Keep unresolved generic type identities
distinct; do not equate runtime class names or suppress the cast diagnostics.
The standards say a generic class is not itself a type (both editions8.25).
Record-only during L26; preserve the original trace and failing/passing controls
before deciding the next implementation contract.

DD044 bounded direct/multilevel type-formal forwarding scope resolved by L28
at77cce610b after all required local gates. Both-edition counter/callback
reducers pass; original1.0p1 callback diagnostics are gone and its runtime
smoke passes. No runtime type-name equivalence or error suppression. Nested
type-expression/value-parameter lineage and complete class/UVM qualification
remain open; existing compile constraint/cast limitations are not resolved.

### DD045 — Foreach parser scope carrier recovery remains unqualified

L29 review found that foreach has its own untyped parser scope carriers. L29
repairs procedural begin/fork ownership; it does not redesign foreach recovery.
The nested malformed begin inside foreach rejects normally in both editions
after L29, but discarding the foreach carrier itself is a separate unqualified
robustness case. No independent failing reducer yet; record-only during L29.
Source: parse.y foreach productions; standards scope context12.7.3; do not claim
all parser recovery qualified.


### DD046 — User-requested sweep of all fallback and compile-progress paths

- **Active blocker:** DD046-TRIAGE-1 (see `.ai/ACTIVE_WORK.yaml`) as of
  2026-09-11, after the UVM smoke campaign closed (U15/U16, 15/15
  SMOKE_PASS). First triage pass:
  `evidence/campaign-20260908/dd046/triage-20260911.md`. Two candidates
  examined in `vvp/vpi_cobject.cc`. One (`vpiLineNo`) proved
  architecture-wide and was split out as DD049, not forced into a bounded
  fix. The other (a class string property's VPI write silently dropping
  when reached through a NESTED class-typed property, e.g. `obj.inner.s`)
  was root-caused, reduced (`evidence/campaign-20260908/dd046/c3.sv`), and
  resolved as **L33** (see `docs/conformance/BLOCKERS.md`). Its named
  integral follow-on was resolved as **L34** in the same pass, which also
  found and fixed a second, independent real regression (an array-indexed
  signal base silently mis-resolving) in the shared helper both L33 and
  L34 depend on -- see BLOCKERS.md L33's addendum and L34's own entry.
- **2026-09-11 comprehensive re-triage of the curated table below:** all
  twelve rows were checked against current source (nine with a concrete
  reducer, three by tracing callers/overrides where that settled the
  question without one). Eleven are now dispositioned RESOLVED or
  ALREADY-LOUD -- either fixed by earlier sessions since the table was
  written, already print a diagnostic before falling back (not DD046's
  silent-path concern), already correctly implemented for every legal
  construct tried, or (for `test_value_callback_ready`) a legitimate
  virtual-method default properly overridden wherever real filtering is
  needed. **Caveat, learned the hard way in this same session (L34's
  regression was silent at its actual source and loud only three layers
  downstream, in a generic safety net):** a nearby `cerr`/`fprintf(stderr`
  does not by itself prove a fallback is harmless, and "N reducers all
  came back correct" is *absence of a found defect*, not *proof of
  absence* -- three of the eleven rows (string/object lowering, casts,
  iteration) rest on a handful of reducers each, not exhaustive coverage,
  and are recorded here as such rather than as closed proofs. The table
  cells below record exactly what was tried for each; treat the "RESOLVED"
  label as "no defect found under this session's search," not "cannot
  contain one."
  **Lost expression typing** (`netmisc.cc`'s `elab_and_eval`, the silent
  empty-string/0.0-real/null substitution for "unresolved parameterized
  helper/container method paths that lose argument typing") was the
  twelfth row and the only one with zero loud diagnostics anywhere on its
  path. It was NOT closed by tracing a caller or a hand-written reducer --
  instead, temporary `getenv`-gated probes were added at all 7 silent
  stub sites (both `elab_and_eval` overloads), the compiler rebuilt, and
  the probe armed across two full corpora: the 357-test UVM smoke/
  regression suite (357/357 passed, 0 probe hits) and the complete
  ~5000-test legacy ivtest suite (4981/4976/0F/2NI/3EF -- the exact clean
  baseline, confirming the instrumented build introduced zero
  regressions; 0 probe hits). The instrumentation was then fully reverted
  (`git diff` on `netmisc.cc` shows no residual change) and the clean
  binary rebuilt/reinstalled. Per this pass's own calibration: an empirical
  sweep of ~5300 tests finding zero hits is stronger evidence than any
  other row's hand-picked reducers, but is still not proof the branch is
  unreachable by SOME construct neither corpus exercises -- recorded as
  such, not as a closed proof.
  **That caution proved warranted within the hour:** before moving on, a
  hand-built sanity construct (`real r; string s; r = s;`) was compiled
  with the same probe armed specifically to confirm the instrumentation
  COULD fire at all -- and it fired immediately, on the single most
  ordinary construct imaginable, not an exotic parameterized-method edge
  case. The REAL-target stub silently substitutes `0.0` for a well-typed
  STRING source with no exclusion, unlike its BOOL/LOGIC/vectorable
  sibling branch (which already excludes STRING, per R30's identical
  fix for a vector target). Root-caused against IEEE 1800-2017/2023
  6.16 (no string-to-real conversion is defined; the naive alternative
  of falling through to the existing real-cast codegen was traced and
  confirmed to also be wrong -- it would bit-reinterpret the string's
  packed bytes as an integer) and fixed as a hard error, closed as
  **L35** in `docs/conformance/BLOCKERS.md`. The lesson generalizes: an
  empirical sweep finding zero hits is only as trustworthy as the last
  time anyone confirmed the probe can fire at all -- always fire-test
  the instrumentation on a hand-built positive case before trusting its
  silence on a corpus. The `elab_expr.cc:8297` stub-callers thread
  (left open in the prior pass) was also traced to completion: 6 of 7
  callers already warn; the 7th is a deliberate silent placeholder for
  dead generic-template-body elaboration, tagged and consumed downstream
  exactly like the `in_unspecialized_param_class` case above -- correctly
  designed, not a defect. All twelve curated-table rows are now fully
  dispositioned; DD046-TRIAGE-2 is closed. Incidentally found along the
  way (both passes): `find()` on a plain (non-class-property) fixed-size
  array of non-integral elements is loudly rejected at elaboration
  (`elab_expr.cc:16554-16562`, "sorry: ... not yet implemented") -- a
  real, known feature gap, but loud, not silent, so not itself a DD046
  target; recorded here for completeness. `.ai/ACTIVE_WORK.yaml` carries
  the next-selection detail for DD046 beyond the curated table (mining
  the raw ~12,850-line fallback inventory, or shifting to the user's
  third priority phase).
- **Scope:** User explicitly expanded the request to sweep ALL fallbacks.
  Include parser/name/type resolution, elaboration, code generation, simulator,
  DPI/VPI, other compiler targets and qualification harnesses. Include silent
  constant/no-op substitutions, even without a fallback warning.
- **Evidence revision:** 3d60cb54a (compiler candidate0a4e7d639).
- **Inventory:** `evidence/campaign-20260908/fallback-tracked-candidates.tsv`
  and `.json` outside the checkout retain the file/line candidates and scanned
  file manifest. 608 tracked C/C++/header/grammar/Python/shell files scanned;
  12849 matching lines, with overlapping tags: fallback494, stub609,
  degradation2245, constant-return9652. These are search hits, NOT defect counts.
  Tests, third_party/vendor, skills, graph artifacts and untracked generated
  sources are excluded from this implementation inventory. Pinned UVM diagnostics
  remain independent application evidence.
- **Search vocabulary:** fallback/fall-back; stub/placeholder/compile-progress;
  ignored/silently/approximation/unsupported/not-enforced/noop/dummy/fabricated/
  dropped/forced-to/substitute; and literal zero/one/true/false/null/empty returns.
  Repeat against the selected revision and trace unnamed equivalent paths.

Source-confirmed candidates (reachability by legal source and exact semantic
loss still require reducers; comments and diagnostic wording are not an oracle):

| Area | Source anchors at evidence revision | Observed implementation | Qualification needed |
| --- | --- | --- | --- |
| Lost expression typing | netmisc.cc:1899 (STRING stub), 1905-1928 (REAL stub, FIXED as L35), 1845/2334/2400 (CLASS/NULL stubs), 2365 (STRING stub, 2nd overload) | **Re-triaged (2026-09-11), one real defect found and fixed as L35 after the initial "empirically unreached" disposition was challenged.** (Line numbers here are post-L35-fix current; the REAL-stub sites shifted by the fix itself, so this cell is re-anchored rather than left pointing at pre-fix locations.) These sites are the ONLY genuinely silent branches found in this whole DD046 sweep (no `cerr` anywhere on the path, unlike every sibling row). Temporary `getenv`-gated probes at all 7 stub sites (both `elab_and_eval` overloads) found zero hits across the 357-test UVM suite and the ~5000-test ivtest suite -- but per an advisor review, a probe that never fires and one that's never reached look identical, so a hand-written sanity reducer (`real r; string s; r = s;`) was built to confirm the instrumentation actually could fire before trusting that negative result. **It fired immediately** -- the REAL-target branch silently substituted `0.0` for ANY mismatched `tmp` type including a well-typed STRING, with no exclusion for the well-typed case unlike its BOOL/LOGIC/vectorable sibling branch (which already excludes STRING, per R30's fix for the identical defect shape on a vector target). Root-caused, spec-grounded (IEEE 1800-2017/2023 6.16 defines no string-to-real conversion; confirmed the naive fallthrough alternative -- `cast_to_real()`'s vec4-bitpattern-reinterpretation codegen -- is not spec-correct either), and fixed: closed as **L35** in `docs/conformance/BLOCKERS.md` (hard error, not a stub, matching the R32 class-handle/aggregate precedent). The STRING-target stubs (`1899`, `2365`) and the CLASS/NULL-target stubs (`1845`, `2334`, `2400`) were probed but never fired and were NOT touched -- they remain exactly the "empirically unreached across ~5300 tests, not proof of absence" disposition the initial pass gave, now demonstrated to need the same fire-test-first discipline before being trusted again. One further gap noted but not fixed: the second `elab_and_eval` overload's BOOL/LOGIC/vectorable branch (`netmisc.cc:2392-2398`, was `2352-2358` pre-fix) lacks the STRING exclusion its sibling (first overload, `1922-1924`) already has -- checked whether it's actually reachable: `netqueue_t : netdarray_t`, so the well-typed-aggregate hard error a few lines above already catches queue sources the same as fixed arrays, leaving only a genuinely VOID/NO_TYPE (unresolved-generic) `tmp` able to reach it -- the same "requires an actual unresolved-generic scenario" wall every other row in this sweep hit. Not sized as a promising next reducer target for that reason. | L35 (real=string) is closed. The STRING-target and CLASS/NULL-target stub branches remain open -- re-open with a fire-tested probe (confirm it CAN trigger on a hand-built construct before trusting a corpus sweep's silence) or a direct reducer. The second overload's un-excluded vectorable branch is very likely unreachable by the same aggregate-hard-error reasoning that already covers queues; not worth pursuing without new evidence. |
| Unresolved methods/functions | elab_expr.cc:8297; elaborate.cc:14061,14072 | **Re-triaged (2026-09-11), resolved.** Traced all 7 call sites of `elaborate_compile_progress_expr_method_stub_`. 6 of 7 already call `warn_compile_progress_stub_fired_` before returning the stub. The 7th (`elab_expr.cc:16388`, reached only via `should_defer_type_parameter_expr_call_`) is silent by design: it fires exclusively while elaborating a generic/unspecialized parameterized-class method body before real specialization (guarded by `is_deferred_type_parameter_expr_receiver_`, which explicitly excludes real built-ins like `randomize`/mailbox/semaphore/covergroup methods and any class with a resolvable method scope), and the resulting stub is tagged via `mark_deferred_type_parameter_stub()` so downstream consumers (e.g. the enum-assignment path at `elab_expr.cc:3334`, and `inherit_deferred_type_parameter_stub` propagation in `dup_expr.cc`/`pad_to_width.cc`/`netmisc.cc`) can recognize it as a placeholder from dead template-body elaboration that never actually executes -- the same deliberate "shape-check only" pattern already established for the `in_unspecialized_param_class` case in the Lost-expression-typing row above and the `initialize`/`m_initialize` cases in `elaborate.cc:14061`. Correctly designed, not a defect. | None -- deliberate and consistent with the codebase's established generic-body-elaboration pattern. |
| Casts | elab_expr.cc:18184 | **CLOSED as L37 (2026-09-11).** The prior re-triage stopped one branch short: the non-packed "unchanged-passthrough" fallback this row named was not a passthrough at all for a bit-stream cast to an unpacked struct (`s_t'(v)`, legal per IEEE 1800-2017/2023 6.24.3) -- it crashed the compiler (`Assertion failed: (net), function ivl_expr_value, t-dll-api.cc:1059`). Fixed by converting the crash into a clean `sorry: bit-stream cast ... not yet implemented` diagnostic (full bit-stream casting is a feature, not a fallback fix, and was explicitly scoped out per advisor review). Packed-target casts (the case this row's original reducers tested) remain correct and unaffected. See BLOCKERS.md L37. | None -- fixed. |
| Constraints | parse.y:18467; original1.0p1 pick_sequence compile diagnostic | **Re-triaged (2026-09-11).** Already loud (a suppressed-after-first `cerr` warning: "pkg::func(...) with-clause is parsed but not enforced ... constraints are silently dropped"). Scoped deliberately: the grammar comment states other package-function with-clauses "retain their compile-progress diagnostic" -- only `std::randomize(...) with {...}` gets real enforcement via `set_with_constraints`. No legal SystemVerilog construct calls an arbitrary `pkg::func(...)` with a `with` clause outside the randomize family (18.7), so this branch may not be reachable by standard code at all; not attempted with a reducer this pass. | Loud already; only worth a reproducer if a real randomize-family variant (not std::randomize itself) is found routing through this branch. |
| Events and waits | elaborate.cc:19847,20322,20458,20629,20775 | **Re-triaged (2026-09-11).** All five sites already print a `cerr` warning before skipping/no-opping (unresolvable event expr, scope-as-event, class-property event expr, empty event set, unelaborable wait condition, no event sources) -- none is silent. Not attempted with a reducer; the loud diagnostics already satisfy DD046's "not silent" bar for every cited line. | Loud already at every cited site. |
| Unresolved methods/functions | elab_expr.cc:8297; elaborate.cc:14061,14072 | **Re-triaged (2026-09-11).** `elaborate.cc:14061`'s `silent_noop` cases (`rand_mode`, `copy`/`do_copy`/`print`/`record`, `initialize`/`m_initialize`) are deliberate, individually justified by in-code Phase63b/B3-B4 comments citing specific known-safe UVM dead-spec patterns (a verified-safe deferred-init race, not an oversight) -- re-litigating these without new contrary evidence isn't productive. `elaborate.cc:14072`'s general unknown-task case is loud. `elab_expr.cc:8297`'s constant-stub expression method (`elaborate_compile_progress_expr_method_stub_`) was not traced to its call site(s) this pass to confirm whether callers already warn; unexamined. | The `elab_expr.cc:8297` stub's callers are the one open thread here; everything else is either deliberate-and-justified or already loud. |
| Iteration | elaborate.cc:22119 | **Re-triaged again (2026-09-11), $low/$high sub-candidate investigated further and BLOCKED (2026-09-13).** Still no reproducer reaching the original `elaborate.cc:22119` branch (fourth attempt: too-many-index-variables `foreach(assoc[k,j])` over a 1D associative array of structs, `evidence/campaign-20260908/other8-audited/iter2_toomany_idx.sv`). That attempt's own byproduct -- the construct compiles clean and then at runtime prints `function $low()/$high() argument object code is 615; using 0/-1 fallback` with the loop body never executing -- was pursued as a possible compile-time-validation gap: IEEE 1800-2017 12.7.3 states "The number of loop variables shall not be greater than the number of dimensions of the array variable," and `pt_t assoc[string]` is declared with one dimension while the reducer supplies two loop variables (`k, j`), which read as explicitly illegal. **But independent cross-check contradicts this reading**: `slang --std 1800-2017` (oss-cad-suite build) accepts the identical reducer with "Build succeeded: 0 errors, 0 warnings" -- no diagnostic at all. Per campaign policy slang is a comparison signal, not the normative oracle, so its silence doesn't prove the construct is legal -- but it does mean my own single reading of "dimensions" for an associative array whose value type is a struct is not solid enough to justify a NEW rejection in Icarus (adding a compile-time error here risks tightening Icarus stricter than a commercial-grade-target comparison tool, exactly the kind of move the campaign's correctness bar warns against making off one interpretation). Not re-derivable from a second reading of the same clause; would need either a second independent tool's datapoint (e.g. a licensed commercial simulator) or an LRM passage that explicitly addresses associative-array-of-struct dimensionality to break the tie. The runtime `$low()`/`$high()` "object code 615" fallback itself remains unexplained on its own terms (does it happen to coincide with whatever slang does internally for the same construct, i.e. some form of degenerate single-pass handling? untested) and is left as its own unresolved thread, separate from the "is this a missing rejection" question. | Re-open elaborate.cc:22119 if a nested-container shape reaching it is found. The `$low()`/`$high()` "object code 615" candidate is BLOCKED pending a tie-breaking oracle (a second real tool's verdict, or a more precise LRM citation on associative-array-of-struct dimensionality) -- do not add a compile-time rejection based on the 12.7.3 reading alone, it's contradicted by slang's acceptance. |
| Membership | tgt-vvp/eval_vec4.c:1937 | **CLOSED as L38 (2026-09-11).** The prior re-triage checked the plain-signal and class-property cases of the queue/darray arm immediately above the loud fallback, and both were real implementations -- but missed a third case in that SAME arm: a QUEUE-valued expression that is neither a plain signal nor a class property (e.g. a function call returning a queue) silently forced membership to `0` with no diagnostic. Root cause: the arm's own comment named "Queue/darray" but its condition only tested `IVL_VT_DARRAY`, never `IVL_VT_QUEUE` -- a missing-enum-value oversight. Fixed with the one-line addition. See BLOCKERS.md L38. | None -- fixed. |
| Increment/decrement | tgt-vvp/eval_vec4.c:2354 (now ~2351) | **RESOLVED (2026-09-11 re-triage).** `draw_unary_inc_dec`'s switch handles `IVL_EX_SIGNAL`/`IVL_EX_SELECT`/`IVL_EX_PROPERTY` with real codegen; only a genuinely unhandled expr type reaches the `default:` fallback, which itself prints a loud `sorry:` before the read-only fallback. Reducers for the two legal lvalue shapes a table reader would suspect (queue element `q[0]++`, associative-array element `assoc["k"]++`) both compute correctly (`evidence/campaign-20260908/dd046/c14_incdec.sv`) -- neither reaches `draw_unary_inc_dec` at all, so this candidate is not reachable by the constructs it looked like it should cover. | None -- already loud where reachable, and the obvious legal reproducers don't reach it |
| Array locators | tgt-vvp/eval_object.c:2584,2622 (elaboration gate: elab_expr.cc:16554-16562) | **CLOSED as L36 (2026-09-11).** The prior re-triage's own framing was the bug: it treated the plain-signal "loud `sorry:` at elaboration" as evidence the row was resolved, without checking whether that `sorry:` was firing on ILLEGAL input. It was not -- IEEE 1800-2017/2023 7.12.1 places no restriction on element type or declared base for array locator methods, and the rejection fired on both non-BOOL/LOGIC elements and non-zero-based declared ranges for plain fixed-array signals. Fixed by unconditionally materializing any fixed array (direct-signal or property) into a `netdarray_t` temp, matching the sibling `make_array_unique_expr_` pattern, and widening the supported-element-type gate to BOOL/LOGIC/REAL/STRING/CLASS. See BLOCKERS.md L36. | None -- fixed. Multidimensional fixed arrays remain a genuine, correctly-loud `sorry` (subarray iteration unimplemented). |
| String/object lowering | tgt-vvp/eval_string.c:249; tgt-vvp/eval_object.c:1197,1282 | **Partially re-triaged (2026-09-11); further narrowed with structural evidence (2026-09-15).** `eval_object.c`'s two select/null fallbacks (1197, ~1280) are already loud (`fprintf(stderr, "Warning: ...")` before the `%null`), not silent. `eval_string.c:249`'s "select on an unsupported base type -> empty string" fallback IS silent (no diagnostic) and remains genuinely open in principle, but is now backed by a much stronger unreachability case than "five failed reproducers": (1) five prior attempts (ternary-selected string, string-concat select, bare function-call-result select, string-method-result select, queue-of-strings element select) each hit an earlier parser/elaboration rejection or resolved through an already-working path; (2) two MORE attempts this pass (a queue/darray-of-string concatenation then select -- `{qa,qb}[i]` -- and a mixed real-string-variable-plus-literal concatenation then select -- `{stringvar,"x"}[0]`) both also hit earlier, *different* rejections (the first is now L118's new `error:`, confirmed independently illegal via slang; the second hits `PEPostSelect::test_width`'s own pre-existing `!type_is_vectorable(base_->expr_type())` guard, "A postfix select requires a packed integral expression"); (3) tracing `PEPostSelect::test_width` directly (elab_expr.cc:13096) shows it ALREADY gates every select base to `type_is_vectorable` before elaboration ever runs -- a STRING-typed concat base (real string operand present) is rejected there, and a QUEUE/DARRAY-typed concat base is now rejected by L118's separate operand-type check (added because `PEConcat::test_width_`'s own crude expr-type computation doesn't detect queue/darray operands as non-vectorable, the one gap that let L118's reducer through). The two grammar-legal shapes that can reach `PEPostSelect`/produce an `IVL_EX_SELECT` at all -- `hierarchical_identifier select` (fully covered by the SIGNAL/ARRAY/PROPERTY branches earlier in `string_ex_select`) and `concatenation [ [ range_expression ] ]` (now shown to be gated to vectorable-only at elaboration, and a vectorable result is handled by `string_ex_select`'s own BOOL/LOGIC branch at the top, before ever reaching line 249) -- are both now accounted for. This is not a formal proof, but it is elaboration-level structural coverage, not just failed-reproducer accumulation; treat this branch as very likely dead code reachable only through a shape not yet identified. | Re-open only if a specific reproducer is found for the `eval_string.c:249` branch -- given the structural coverage above, that would most likely mean a shape that reaches `IVL_EX_SELECT` through neither `PEIdent` nor `PEPostSelect` (e.g. a different PExpr subtype's `elaborate_lval`/`elaborate_expr` also constructing a `NetESelect`), not another attempt at a concatenation or identifier select. |
| Missing executable targets | tgt-vvp/vvp_process.c:808 | **Re-triaged (2026-09-11).** `emit_td_stub_definitions()` is a defensive bookkeeping safety net (emit an empty label for any thread-destination referenced but never defined, so a stray forward reference can't produce a dangling jump) rather than a feature-implementation fallback; not traced further this pass to find a legal construct that leaves a genuine reference unresolved. | Unclear this represents user-visible incorrect behavior; would need a concrete case where a legally-reachable TD reference has no definition. |
| Simulator/VPI | vvp/compile.cc:1148; vvp/vpi_callback.cc:217 | **Re-triaged (2026-09-11), both resolved.** `compile.cc:1148`'s placeholder-net path is already loud (`unresolved_warn_once`) and is the generic safety net that ANY malformed functor reference trips -- it is literally the mechanism whose output ("unresolved functor stub"/"created placeholder net") was the observed symptom of the real L34 regression this session found and fixed; it did its job correctly. `vpi_callback.cc:217`'s `test_value_callback_ready()` "stub" is a legitimate virtual-method default (always-ready is correct for a plain full-value-change callback) properly overridden by `value_part_callback`/`array_word_part_callback`/`runtime_array_word_value_callback` wherever real bit/word-range filtering is actually needed -- traced all overrides and call sites; this is correct OOP design, not a defect. | None -- both already resolved (one already loud+working-as-intended, one already correctly designed). |
| Qualification fallback | .github/uvm_test.sh:139 | Already understood at DD046's original writing: this row's own "Qualification needed" column already states the correct handling (keep real-DPI/no-DPI evidence separate). Not re-examined this pass; harness-flavored, not a compiler-semantics candidate. | Low priority; the existing disposition already looks correct. |
| Chained container index + string select | elab_expr.cc: `apply_trailing_container_indices_` (~2499) | **CLOSED as L39 (2026-09-11).** New row -- found (not in the original DD046 table) while auditing container-indexing paths. `obj.q[0][1]` (a class-property queue-of-strings, element-select then byte-select) hit `sorry: this index does not select a queue or associative-array class-property value`, even though both a bare `string_var[1]` and a class-property queue-of-queues `obj.q[0][0]` already worked independently via the identical `NetESelect` shape -- the shared indexing loop dispatched on `netvector_t`/`netarray_t` for the intermediate type but had no `netstring_t` branch. Fixed by adding one, reusing the existing `elab_assoc_index` helper. See BLOCKERS.md L39. | None -- fixed. |
| Class-handle rvalue degrade inside a real specialization | netmisc.cc `class_rval_degrade_ok` (~1644-1750) | **CLOSED as L40 (2026-09-11).** New row -- found while auditing the STRING/CLASS `netmisc.cc` stub candidates for a genuine unresolved-generic reproducer. A specialized parameterized class (`container#(obj_c)`) whose own method assigns a class-handle-typed value (via its type parameter `T`) to a `string` local variable silently produced `""` with ZERO diagnostic, because the guard's `in_class_scope` check is coarse (true for any class body, dead template-seed or real specialization alike). A first wholesale-narrowing attempt (swap `in_class_scope` for `in_unspecialized_param_class` outright) broke `uvm_vreg::allocate()`'s ordinary `this.mem = mam.get_memory();` -- instrumentation traced this to a THIRD scenario: `uvm_vreg.svh`/`uvm_mem_mam.svh`'s circular forward-declaration collapses the target to `cast_type==IVL_VT_BOOL` (the same mechanism as the documented LOGIC forward-ref case, just 2-state). Fixed correctly with a narrow additional carve-out (`in_real_specialized_param_class`, the logical complement of `in_unspecialized_param_class` within a parameterized class body) that hard-errors only a real specialization, leaving `in_class_scope`'s broad permissiveness -- BOOL collapse included -- completely untouched. See BLOCKERS.md L40. | None -- fixed. |
| Integral class-property read as a string | vvp/class_type.cc:536 (`class_property_t::get_string` base-class default) | **CLOSED as L42 (2026-09-13).** Found incidentally while building the L40 "must stay silent" reducer. Reading an ORDINARY integral class property back as a `string` from inside its own class method warned and returned `""` instead of the IEEE 1800-2017/2023 6.16 packed-byte value a plain (non-property) variable already got. Root cause confirmed: `property_atom<T>` (int/byte/shortint/longint properties) and `property_logic` (4-state vector properties) never overrode `get_string`/`set_string`, falling to the base class's "unsupported" stub -- NOT a decimal/itoa formatting gap as first guessed, but a missing byte-packing conversion (confirmed against the LRM: "values of integral type can be assigned to a string variable... zero-filled on the left"). Fixed by extracting the exact conversion the existing `%pushv/str` vvp opcode already used for plain variables into a shared `vector4_to_packed_string()` helper, and adding `get_string`/`set_string` overrides to both classes that reuse it (plus a shared `pack_string_into_vec4_()` for the write direction, mirroring `%cast/vec4/str`'s right-justify/truncate/zero-fill semantics). `property_bit` (2-state `bit` vectors) turned out unaffected -- it already worked, apparently routing through the same materialization as `property_atom<T>` for common widths. See BLOCKERS.md L42. | None -- fixed. |

- **Triage:** OPEN, semantic classification pending. Ordinary allocation
  fallbacks, generated DPI bridge stubs, valid empty-container results and
  error-recovery paths are not automatically defects. Inspect the surrounding
  control flow and terminal diagnostic status. Source-confirmed substitution
  does not yet prove a legal reproducer reaches it.
- **Completion rule:** Every candidate must be classified as valid behavior,
  unreachable/superseded with evidence, explicit unsupported/qualification gap,
  or a reproduced semantic defect. All legal behavior-changing fallbacks need
  standards-grounded implementation and permanent regressions; warning removal,
  an unsupported error, or a smoke pass alone cannot close that obligation.
  Keyword coverage is not semantic exhaustiveness; review default branches,
  early returns, ignored statuses and synthesized values by requirement cluster.


DD046 first reachability check: a fixed-size real array `find with (item > 1.5)`
is rejected with compile exit1 in both2017/2023 before code generation:
"find() on fixed-size arrays of non-integral elements is not yet implemented."
The fallback in eval_object.c is therefore not reached by this reducer. Record
this case as an explicit unsupported legal feature, not observed fabricated
runtime results. Evidence: `evidence/campaign-20260908/fallback-reducers/`
`fixed-real-find.sv` and `fixed-real-find.json`. Other routes remain unqualified.


DD038 prerequisite U14 locally validated at729edce3c with test/CI79885f484:
explicit original1.1d lifecycle recorder, native owner/handle registry, retained
exclusive file descriptors, cross-owner links and allocation rollback are real
and regression-tested. Full local gates pass (BLOCKERS U14). Typed attribute
capture and deterministic default installation remain mandatory and OPEN;
original1.1b/c still fail the missing macro. No parent completion claim.


### DD047 — String literal with a high-bit byte fails to load as a vector operand

- **Active blocker:** L32; record-only.
- **Observation:** `x = "\301B";` into `reg [15:0]` and `y = "\377";` into
  `reg [7:0]` compile with exit 0 in both 2017 and 2023, but vvp refuses to load:
  `numeric operand out of range` (`%pushi/vec4 18446744073709535554, 0, 16`).
  Expected: x=c142, y=ff.
- **File/function:** `tgt-vvp/eval_vec4.c` `draw_string_vec4`:
  `tmp |= (unsigned long)*p` on a plain `char`, which is signed on this ARM64 host,
  so bytes of 0x80 and above sign-extend.
- **Possible clause:** IEEE 1800-2017/2023 5.9 (literal operands are unsigned
  integer constants of 8-bit values).
- **Evidence:** `evidence/campaign-20260908/l32/dd-hibit-assign.v` and `.log`.
  Not introduced by L32 (`ab54351c3` touches only `vvp/vpi_const.cc` among
  implementation files). Upstream master still has the same loop.
- **Triage:** OPEN; reproduced; candidate for the next selection.

L32 note: upstream master `vvp/vpi_const.cc` still has the pre-L32 literal
`vpiVectorVal` loop. Upstream `ivtest/ivltests/swrite.v` still has the endian
probe that depended on it. An upstream report is a separate, unfiled action.


### DD048 — __vpiVThrStrStack has no vpiVectorVal path; vpiSize unit differs from __vpiStringConst

- **Active blocker:** U15; record-only (worked around, not fixed).
- **Observation:** A systf string argument that is not a bare literal --
  a `string` variable, an enum `.name()` result, a function-call result, or a
  runtime concatenation -- is represented by `__vpiVThrStrStack`
  (vvp/vpi_vthr_vector.cc), which rejects `vpiVectorVal`
  (`vvp error: get 9 not supported by vpiConstant (String)`, unconditional
  stderr, format returns `vpiSuppressVal`) even though `vpiType`/`vpiConstType`
  report `vpiConstant`/`vpiStringConst` identically to a real literal (a
  `__vpiStringConst`, vvp/vpi_const.cc, L32-fixed). The two classes also
  report `vpiSize` in different units for the same property code:
  `__vpiStringConst` returns bits (`value_len_*8`); `__vpiVThrStrStack`
  returns characters (`val.size()`). A 5-character enum `.name()` reports
  `vpiSize==5`, not 40.
- **File/function:** `vvp/vpi_vthr_vector.cc` `__vpiVThrStrStack::vpi_get_value`
  (no `vpiVectorVal` case) and `__vpiVThrStrStack::vpi_get` (`vpiSize`).
- **Consequence for U15:** `$ivl_uvm_record_attribute`'s string encoder
  (uvm_dpi/uvm_recording.cc) cannot use `vpiType`/`vpiConstType` to select a
  byte-exact read path, since both classes present identically at that level.
  It instead reads `vpiStringVal` first and compares the result's length
  against `vpiSize` under both possible unit conventions (`*8` and as-is);
  only a mismatch (reachable in practice only via a true literal whose value
  contains an embedded NUL, which `__vpiStringConst`'s own `vpiStringVal`
  branch alters rather than truncates) triggers a `vpiVectorVal` retry. This
  keeps the common non-literal path silent and correct and confines the
  byte-exact/embedded-NUL path to where it is actually reachable, but it does
  not give `__vpiVThrStrStack` a lossless path: a genuinely NUL-containing
  runtime string expression (e.g. a literal fragment concatenated into a
  variable at runtime) cannot be captured exactly and is reported as a loud
  failure rather than silently truncated.
- **Evidence:** `evidence/campaign-20260908/u15/se2.sv`/`se2.c` (direct
  probe), `expression-string-args-20260911.log` (pre-fix failure),
  `expression-string-args-fixed-20260911.log` (post-fix). Permanent
  regression: `tests/uvm_releases/recording_attribute.sv` `string_enum_name`/
  `string_func_result`/`string_concat` cases plus the harness's
  `"vvp error: get" not in output` assertion.
- **Triage:** OPEN; reproduced; candidate for a future selection. Giving
  `__vpiVThrStrStack` a `vpiVectorVal` path (and reconciling the `vpiSize`
  unit inconsistency generally, not only for this one caller) is a separate,
  non-trivial VPI runtime change, out of U15's scope.


### DD049 — vpiLineNo/vpiFile never captured for signals, part-selects or class variables

- **Active blocker:** DD046 triage; record-only.
- **Observation:** `vpi_get(vpiLineNo, handle)` returns a hardcoded `0` for
  every ordinary signal/net/reg (`__vpiSignal`, `vvp/vpi_signal.cc:552`),
  every part/bit select (`__vpiPV`, `vvp/vpi_signal.cc:1415`), and every
  class variable (`__vpiCobjectVar`, `vvp/vpi_cobject.cc:201`) -- all three
  sites carry the identical `// Not implemented for now!` comment. `struct
  __vpiSignal` (vvp/vpi_priv.h) has no file/line storage field at all: the
  value was never captured, not merely left unwired to an existing field.
- **Possible clause:** IEEE1800-2017 37.3.3: "Most objects have... vpiLineNo
  [and] vpiFile... applicable to every object that corresponds to some
  object within the source code," with an explicit exception list that does
  not include signals, part-selects, or class variables -- so this is
  normatively required for these kinds, not optional.
- **Reachability:** trivial; any `vpi_get(vpiLineNo, ...)` on an affected
  handle observes it.
- **Scope:** architecture-wide, not a bounded single-function fix. A correct
  fix needs new file/line plumbing from elaboration through netlist
  compilation into vvp bytecode/VPI object creation, for every affected
  object kind (not fully enumerated -- these three classes were the ones
  examined; other classes were not checked for the same pattern).
- **Evidence:** `evidence/campaign-20260908/dd046/triage-20260911.md`
  (Candidate 1).
- **Triage:** OPEN; reproduced; too large for one bounded DD046 increment.
  A future selection should scope it explicitly as its own multi-part
  feature (which object kinds, what elaboration-to-vvp plumbing) rather than
  a single reducer-sized fix.

### DD-018 — Procedural package import after a local declaration (L43)

- **Current status (2026-09-14):** IMPLEMENTED with focused validation; L43 implements
  the legal declaration-prefix case with invalid-placement safeguards.
- **Correction to the L41 assessment:** the archived reducers declared
  `function foo_t get_val()` before importing `foo_t` inside the body. Their
  syntax failure occurred at the return type, before the import. With an `int`
  return type, a leading import already works. An import after `int dummy;`
  instead reaches an existing statement-context production and fails with
  `What kind of statement? 5PNoop` during elaboration.
- **Root cause:** package lookup is already installed by
  `pform_package_import`; the fallback statement production creates an
  unelaboratable `PNoop` for a declaration. A one-line null replacement was
  rejected in review because it also accepts illegal conditional/late imports
  and crashes when an attribute is bound through the null statement.
- **Grammar investigation:** the old +222 reduce/reduce jump is reproduced
  by duplicating the already-present `block_item_decl` import alternative.
  Bison state 1230 contains two identical completed productions and all 222
  extra conflicts. This is not evidence of a DPI-import collision. Scratch
  reports: `evidence/dd018-assessment/{baseline,duplicate}.output`.
- **Normative basis:** both IEEE 1800-2017 and 1800-2023 A.2.1.3,
  A.2.6-A.2.8 and 26.3. Imports belong in declaration prefixes, not arbitrary
  statement positions. The earlier A.6.3 citation was imprecise; the
  `block_item_declaration` production is in A.2.8.
- **Evidence:** corrected reducers and pre-fix six-error regression logs in
  `evidence/dd018-assessment/`. Permanent positive source:
  `ivtest/ivltests/sv_procedural_package_import.v`.

### DD-019 — Packed mixed-driver compound assignment aborts (PRINCE)

- **Discovered during:** L43; independent assessment only, not active implementation.
- **Observation:** freshly compiled unmodified OpenTitan `prim_prince_sim`
  aborts in `vvp_fun_concat::recv_vec4_pv`: port 0 expects 256 bits, receives
  384. Compiler/target/runtime hashes were unchanged during this replay.
- **Reducer:** `evidence/opentitan-runtime-assessment/packed_compound_drivers.sv`.
  A six-word packed array has word 0 assigned in `always_comb`, with `^= 0`
  following the ordinary assignment; other words are continuously driven.
  The plain-assignment control passes. Compound form reproduces the exact abort.
- **Root-cause hypothesis:** ordinary assignments use `%force/vec4/off` for
  a signal lowered to an unresolved net, while `put_vec_to_lval` emits
  `%store/vec4` for the compound form. The runtime store reaches the concat
  network with the full packed width. Investigate target write routing,
  not a width-clamping workaround in the concat runtime.
- **Normative basis to verify at activation:** IEEE 1800-2017/2023 6.5
  (independent packed elements may have different kinds of drivers), 11.4.1
  (compound assignment equivalence and single index evaluation).
- **Status:** L44 implemented with focused validation. Full PRINCE success is unproven;
  missing native DPI dependencies may expose a later independent failure.

### DD-020 — Unresolved task calls compile and continue after a warning

- **Discovered during:** L44, independent next-blocker assessment.
- **Observation:** the OpenTitan synchronizer test calls mode/interval setter
  tasks absent from the pinned `prim_cdc_rand_delay` implementation. The
  compiler ignores all six enables instead of rejecting the unresolved calls.
  That application cannot serve as clean simulator qualification evidence.
- **Reducer:** `evidence/unresolved-task-assessment/missing_task.sv` calls an
  undeclared task and prints a marker afterward. Both 2017 and 2023 compile
  with exit 0 and execute the marker. `results.json` records both runs.
- **Location:** `PCallTask` elaboration in `elaborate.cc`, including the
  SystemVerilog-only bare unknown-task warning/no-op branch near line 14069;
  qualified/class paths contain related fallbacks requiring separate assessment.
- **Expected:** an unresolved enable cannot be treated as a successful call.
  IEEE 1800-2017/2023 13.3 and 23.8.1 govern task calls and lookup.
- **Status:** L45 implements the bare unqualified-call diagnostic. Qualified
  and class fallback paths remain OPEN and must not be mistaken for semantics.
  The synchronizer's reset-time queue mismatch itself remains untriaged; the
  missing setters are not claimed to be its root cause.
- **Post-L48 assessment:** `missing_package_task.sv` calls a missing task in an
  existing package; `missing_hier_task.sv` calls a missing task in an existing
  module instance. Both compile and execute `CONTINUED` in both editions.
  `evidence/unresolved-task-assessment/qualified-results.json` records all four
  runs. Package and hierarchical fallback branches remain distinct next fixes;
  preserve valid forward declarations and class method dispatch when correcting
  them. No implementation or qualification is claimed yet.

DD-020 qualified-call follow-up: `qualified-shadow-function-results.json`
records an explicit missing package call from a class compiling and continuing
in both editions despite a same-named class method. Valid package void/nonvoid
functions and hierarchical void functions retain their side effects in the
positive control. These form the next bounded elaboration checks.

Indexed hierarchy follow-up: `indexed_hier_task_valid.sv` calls a real task in
`child dut[1:0]`. Both editions discard `dut[1].bump()` and leave both counters
zero (`indexed-hier-task-results.json`). This is an execution defect for a
valid call, distinct from missing-call diagnostics. The early indexed-object
fallback bypasses ordinary hierarchical task lookup. Scope/object separation
must preserve valid object-array methods when fixing module/generate calls.

L51 implements downward package-qualified task/function statement lookup,
including valid self-qualified forward tasks and exported subroutines. Missing
members no longer fall back to compilation-unit task/function shadows or
warning/no-op paths. IEEE 23.7.1 requires this downward-only resolution.
Legacy 4/4 and JSON 8/8 pass; hierarchical and class fallback debt remains open.

L52 resolves fixed indexed hierarchy through the ordinary task/function path
and rejects missing members on proven indexed scopes. Module/generate tasks,
copy-out, delays, void functions and object-array controls pass (legacy 5/5,
JSON 10/10). Unknown/out-of-range/over-wide instance selections are diagnosed;
legal negative indices including INT_MIN pass. Unindexed missing hierarchical
tasks and class fallback paths remain OPEN. Full batch qualification is pending.

### DD-021 — Dynamic subpart of a disjoint mixed-driver element is rejected

- **Discovered during:** L44 boundary validation.
- **Observation:** a fixed packed element written procedurally through a dynamic
  subpart, with a different fixed element continuously driven, is rejected as
  also continuously assigned before target emission.
- **Authority:** IEEE 1800-2017/2023 6.5 permits disjoint static prefixes to have
  different driver kinds; dynamic selection inside a fixed element does not
  make the entire containing array the longest static prefix.
- **Status:** OPEN. L44 covers the accepted static mixed-driver route only.
  Do not register this legal source as an expected language-error regression.

### DD-022 — Packed subpart writes escape the selected element

- **Discovered during:** DD-021 prerequisite assessment alongside L45.
- **Reducer:** `evidence/dynamic-mixed-driver-assessment/subpart_bounds.sv`;
  `logic [1:0][7:0] words = 16'ha520` followed by a procedural
  `words[0][pos +: 4] = 4'hf`, with `pos=8`, changes the upper element:
  observed `16'haf20`, expected unchanged `16'ha520`. Both editions fail
  the runtime assertion; `bounds-results.json` records the results.
- **Authority:** IEEE 1800-2017/2023 11.5.1: wholly out-of-range part-select
  writes have no effect; partially out-of-range writes affect in-range bits only.
- **Root-cause evidence:** `normalize_variable_part_base` flattens a subpart
  offset into the full packed signal. `NetAssign_::set_part` retains the flat
  base and width, without the selected element's bounds. The runtime therefore
  treats the adjacent element as in range.
- **Read counterpart:** `subpart_read_bounds.sv` reads `5` from the neighboring
  element instead of `x` in both editions (`read-bounds-results.json`).
- **Status:** OPEN prerequisite to DD-021. Do not merely relax mixed-driver
  rejection while writes can escape the static prefix into continuous drivers.
  Assess ordinary, compound and nonblocking write paths plus read semantics,
  partial overlaps, index single evaluation, ascending/descending declarations
  and unknown indexes before choosing the shared correction.

- **L46 bounded implementation:** read-only indexed `+:`/`-:` selects with a
  fixed packed prefix will retain the selected carrier as nested `NetESelect`
  nodes. Write semantics remain OPEN regardless of read-focused test results.
- **Write design checkpoint:** preserve canonical selected-carrier bounds through
  `NetAssign_`, `dup_lval`, target lvalue transport and synthesis. Consumers include
  VVP blocking/compound/NBA paths, procedural sensitivity/write analysis,
  `synth2.cc`, and VHDL/Verilog source targets. Reuse interval intersection logic;
  do not duplicate index evaluation or silently drop partial in-range writes.
- **Additional boundary:** `prefix-bounds.sv` reads `3` instead of `x` from
  `words[0][3][0+:4]` when the middle declared dimension is `[2:0]`.
  `prefix-results.json` records the 2023 failure. Constant prefix flattening
  also lacks per-dimension bounds checks; L46's valid-prefix read scope does
  not qualify this case.
- **L48 focused read correction:** final-dimension indexed reads preserve every
  packed prefix as a nested selection, including dynamic and unknown prefixes.
  Focused tests cover both editions, unpacked-word suffixes, two-state results,
  wide indices, single evaluation, and unchanged subarray selection. Legacy 2/2,
  JSON 4/4, L46 neighbor 2/2, and null/synthesis checks pass. Packed writes remain
  OPEN and broad qualification remains pending.
- **L49 synthesis baseline:** `write-synthesis-runtime.sv` synthesizes the
  combinational DUT with `-S` and simulates it under a retained testbench.
  Both editions return `a7e0` instead of `a5e0` for a partial write into the
  low packed element. `write-synthesis-red-results.json` records the failures.
  A target compile-only smoke cannot establish correct write semantics.

### DD-023 — Wide constant one-dimensional select aliases in formatting arguments

- **Discovered during:** L46 wide-index review.
- **Reducer:** `evidence/dynamic-mixed-driver-assessment/one-dimensional-wide.sv`.
  Formatting `value[64'h1_0000_0000+:4]` for an eight-bit value produces `0101`
  instead of `xxxx`, while the dynamic-base version produces `xxxx` after L46.
  Both editions fail the string-result assertion. Assignment context does not
  reproduce this case, so do not claim all constant reads are affected.
- **Authority:** IEEE 1800-2017/2023 11.5.1.
- **Evidence:** `one-dimensional-wide-results.json`. The analogous nested packed
  read passes both modes (`nested-wide-format-results.json`).
- **Status:** L47 focused value/callback correction implemented. Constant
  normalization and VPI base transport both required correction; direct VPI
  read/write and parent-value callback checks pass both editions. Full metadata
  and index-only callback triggers remain unqualified.


DD-022 follow-up evidence: `prefix-boundary-results.json` shows both editions
reading neighboring bits for an out-of-range or X middle prefix, while evaluating
the final index function once. `prefix-outside.sv` and `prefix-unknown.sv` are the
next read-side reproducers; neither is qualified by L46/L47.

DD-022 write-side preparation: `write-boundary-results.json` contains six failing
checks across both editions. Blocking and nonblocking writes to `words[0][6+:4]`
change `a520` into `a7e0` instead of `a5e0`; compound XOR produces `a6e0`, also
changing the adjacent element. Sources are `write-blocking.sv`,
`write-compound.sv` and `write-nonblocking.sv` in the same evidence directory.
The read fixes do not qualify these assignment paths.

L49 focused write correction preserves carrier bounds for defined, valid fixed
packed prefixes across blocking, compound, NBA and synthesis. Legacy 4/4,
JSON 8/8 and a root 228-case boundary matrix per edition pass. Constant compound
and unpacked-array routes have permanent review regression assertions. Dynamic
and invalid write prefixes, unsupported source-target translations and broad
qualification remain OPEN; DD-021 is not relaxed by this increment.

### DD-024 — Empty implicit sensitivity crashes synthesis

- **Discovered during:** L49 constant-write validation. A reducer with no RHS
  reads did not isolate packed-carrier synthesis.
- **Reducer:** `evidence/dynamic-mixed-driver-assessment/synthesis-empty-sensitivity.sv`
  contains a one-dimensional output assigned a constant in `always @*`.
  With `-S -tnull`, both editions warn that the block will never trigger, then
  crash with exit 139. `synthesis-empty-sensitivity-results.json` records this.
- **Scope:** independent of packed-carrier metadata; this reducer has no packed
  subpart selection. Whether it predates L49 has not been verified against a
  prior binary. Do not count the crash as a packed-write qualification failure
  after replacing that test with a DUT that actually reads an input.
- **Expected:** preserve the semantics of an event wait with no triggering
  signals, or report an explicit synthesis limitation. Never infer a constant
  driver merely because the unreachable assignment contains a constant.
  IEEE 1800-2017/2023 9.4.2.2 governs implicit event controls; compare the distinct
  time-zero execution rule for `always_comb` in 9.2.2.2.
- **Status:** L50 fixes null-body dereferences in asynchronous classification
  and legacy synthesis tokenization. Focused legacy 2/2 and JSON 4/4 pass,
  preserving dormant X output, time-zero always_comb execution and ordinary
  retriggering. Forced synthesis still rejects explicitly. Broad qualification
  remains pending.


L43–L52 batch qualification checkpoint (`c686a4781`, 2026-09-14): all local
broad gates pass after correcting null AST actions, selector name handling,
sensitivity selection kinds, declared two-state read casts and VPI array-word
signedness. This supersedes the broad-pending notes for L43–L52 above; DD-024
is locally qualified within its stated empty-wait scope. The broader DD-020,
DD-021 and DD-022 obligations remain open.

Next DD-020 evidence: `unindexed-hier-frozen-candidate.json` still observes
`dut.missing()` compiling successfully in both editions. Valid module/package
forward tasks and indexed object methods pass the accompanying controls.

Next DD-022 evidence:
`evidence/dynamic-mixed-driver-assessment/invalid-prefix-writes/results.json`
records constant OOB and X prefixes leaking blocking, compound and NBA writes
in both editions (six cases per edition). Final-index and RHS functions each
execute once. A correction must preserve that evaluation while preventing
invalid stores; classifying dynamic prefixes as constant-invalid is incorrect.

L53 focused follow-up closes the proven non-class/non-package unindexed
hierarchy receiver case: missing tasks are diagnosed after existing resolution
attempts. Legacy13/13 and JSON24/24 pass with forward-call effects and inherited
method controls. Unresolved receivers and broader object-method fallbacks
remain open; full batch qualification is pending.

L54 focused correction suppresses indexed writes through proven-invalid
constant packed prefixes in the common lvalue path. Blocking, compound, NBA
and unpacked-word controls preserve evaluation counts and unchanged storage;
legacy4/4, JSON8/8 and independent ordinary/synthesized runtime checks pass.
A 128-bit prefix probe passes with existing host-width warnings. Dynamic
prefixes remain open. DD-021 still reproduces on the L53 baseline in
`dynamic-after-l53-results.json`: a dynamic subpart of words[0] is rejected
when words[1] has the disjoint continuous driver. The next implementation must
reuse exact static-prefix bounds rather than relax driver conflicts globally.

L55 focused DD-021 correction checks the driven mask of a proven valid fixed
packed carrier before permitting a dynamic final subpart write. The permanent
positive exercises blocking, compound and delayed NBA, partial low/high and
both directions, unknown/OOB bases, continuous neighbor updates and evaluation
counts. Actual same-carrier overlap remains a compile error. Legacy7/7 and
JSON14/14 pass. The earlier unpacked whole-word conflict guard and unproven
prefix cases remain open; this is not full mixed-driver completion.

DD-022 next runtime-prefix evidence:
`evidence/dynamic-mixed-driver-assessment/dynamic-prefix-next/results.json`
records six failures per edition on the L55 focused binary. An invalid middle
index aliases an adjacent element; a valid dynamic prefix with a partial final
select spills into adjacent bits. Blocking, compound and NBA all fail, while
each prefix, final-index and RHS function executes once. Runtime per-dimension
validation and selected-element clipping must preserve those evaluation counts.

L56 baseline expands DD-022 coverage with an independently calculated 378-case
matrix over signed 128-bit prefix/final indices, including huge values, X/Z,
ascending and negative ranges, both selection directions and three assignment
forms. The L55 binary fails 65 checks per edition. A separate clocked NBA DUT
has 36 cases and fails eight in each ordinary/synthesized run, in both editions.
`l56/root-red-results.json` and `l56/root-synth-red-results.json` record stable
compiler hashes before/after. These are failing baseline evidence, not passing
qualification. Expected bit placement is calculated from each declared range,
without using the compiler's flattened-index expressions.

DD-020 next unresolved-receiver matrix on the L55 binary:
`evidence/unresolved-task-assessment/after-l55/results.json` records
`missing_receiver.run()`, `missing_receiver[0].run()`, `dut.missing.run()` and
`obj.missing.run()` compiling and completing with ignored-call warnings in
both editions. `absent[0].clear()` and `absent.copy()` compile and complete
without a diagnostic. Direct missing methods on resolved scalar/indexed class
objects already reject; valid object and forward hierarchy calls retain their
observed counter effects. Binary hashes are stable across this assessment.
The relevant fallback paths are `PCallTask::elaborate_usr`'s indexed-object
fallback and its unresolved dotted-call branches. A correction must preserve
valid deferred type-parameter resolution and built-in methods while preventing
invalid executable calls from becoming empty blocks. IEEE 1800-2017/2023
13.3 and 23.8.1 govern task declarations/calls and name resolution.

L56 sibling-route baseline: `l56/root-bit-element-red-results.json` records
34 failures per edition across 108 dynamic bit/whole-element assignment cases.
These share the flattened-prefix defect with indexed part-select writes.
The independent `root_dynamic_sensitivity.sv` control passes ordinary and
synthesized execution in both editions before L56. Moving prefix expressions
out of the final base must preserve their contribution to `NetAssign_` input
sensitivity; changing only the outer or middle index must retrigger `always @*`.

L56 first executable WIP uses the existing checked-property-index runtime
helper for packed prefixes, with per-dimension orientation and stride. Original
blocking invalid-prefix/spill reproducers pass, but the independent matrix on
`ae60f63f...` finds four blocking failures per edition: descending `-:4` with
base 1 on [7:0], and equivalent negative ranges. Expected partial-low writes
are suppressed. `collapse_packed_member_indices` constructs its width adjustment
as an unsigned PENumber, so the negative relative offset is treated as a wide
unsigned value. Compound and NBA consumers are not yet connected and remain
red (126 cases each per edition). `l56/root-slice1-results.json` records this
partial implementation evidence; it is not a qualification checkpoint.

L56 blocking correction now passes all 126 indexed-write blocking cases per
edition on installed `649fbf7c...` (stable before/after hashes in
`root-blocking-fixed-results.json`). Compound and NBA remain WIP-red.
Consumer review found constant-function assignment evaluation ignoring dynamic
carrier metadata: `root_const_function.sv` gives valid=0xF instead of
0x0F0000000000, with partial and invalid selections also wrong in both editions.
`root-const-function-slice1-results.json` records the evidence. Required
consumers also include precise output/driver analysis: a constant relative
base must not be interpreted as a constant absolute destination when its
carrier is dynamic. These are L56 integration obligations, not waived gaps.

L56 compound review corrected a whole-signal old-value read to nested carrier
and relative selections. `root_compound_old_value.sv` now passes both editions:
partial high/low and descending selects propagate X through four-state +=,
while two-state old-value conversion produces the expected numeric result.
`root-compound-old-value-results.json` records stable compiler/target/runtime
hashes. This arithmetic probe is necessary because bitwise XOR alone cannot
expose an out-of-carrier old-value read. `root_nba_capture.sv` is the pending
independent delay/capture/partial-update oracle; no result is claimed yet.

L56 pure-packed checkpoint: `root-packed-complete-results.json` records all
378 indexed-write cases passing in each edition, with stable compiler, VVP
target and runtime hashes. `root-nba-capture-results.json` additionally proves
captured dynamic indices/RHS values and disjoint delayed partial updates in
both editions. Whole-feature qualification is still pending.

The separate fixed unpacked-word matrix has 504 cases per edition and remains
red before its consumers are connected (`root-array-before-consumer-results.json`,
installed ivl 3f7515fe...). Packed-prefix function counts are zero in those
paths, although the word, final-index and RHS functions execute. The matrix
checks valid, OOB, X and 128-bit overflow word indices, every packed dimension,
and all three assignment forms against independently calculated storage.
The clocking prefix probe still emits its existing focused unsupported
runtime-clockvar diagnostic; no clocking-support claim is made.

L56 fixed-array consumer checkpoint: `root-array-connected-results.json`
records all 504 cases passing in each edition with stable compiler/target/runtime
hashes. Blocking, compound and NBA now consume the checked carrier while
preserving word validity independently. This supersedes the WIP-red array
checkpoint above. Constant-function evaluation, synthesis, precise analysis,
source-target handling and permanent regression packaging remain pending;
L56 is not yet integrated or fully focused-qualified.

L56 constant evaluator checkpoint: independent dynamic-prefix, static-carrier
and compound logic/bit fixtures pass both editions (six runs in
`l56/root-const-review-results.json`, stable compiler hash). Static high/OOB
writes previously corrupted adjacent bits (`root-const-static-before-results.json`)
and are now clipped. Invalid carrier suppression occurs after final-index
evaluation; exact index conversion and partial-offset arithmetic were reviewed.
The postincrement side-effect fixture cannot yet qualify this behavior because
of the separate constant-expression evaluation defect below.

### DD-025 — Postincrement expressions fail constant-function evaluation

- **Discovered during:** L56 compile-time index side-effect testing.
- **Reducer:** `evidence/dynamic-mixed-driver-assessment/l56/const-postinc_expression.sv`
  uses only local scalar integers: `i=0; j=i++; return 10*i+j;` in a constant
  function. Both editions reject its localparam invocation with an inability
  to evaluate the parameter. The corresponding statement `i++; return i;`
  compiles and produces the expected result in both editions.
- **Evidence:** `l56/const-postinc-isolation-results.json`. No packed arrays or
  dynamic carrier metadata are involved in these isolated reducers.
- **Expected:** expression postincrement returns the old value and increments
  the local variable once during constant-function evaluation. Track IEEE
  1800-2017 and 2023 compatibility separately.
- **Status:** OPEN. Increment/decrement uses `NetEUnary`, whose constant
  evaluator currently evaluates an operand as a value without updating its
  local l-value. Assignment expressions use `NetEAssignExpr` and separately
  lack a dedicated constant-function evaluator. Do not count
  `root_const_index_effects.sv` as a passing L56 side-effect check while this
  prerequisite remains unsupported.

### L56 pre-integration review checkpoint — 2026-09-14

L56 remains unintegrated. Fourteen fresh ordinary/synthesized sensitivity,
clocked-write, and constant-function controls pass with stable installed hashes
(`l56/root-freeze-consumer-results.json`). Two expanded checks require correction:

- The checked-index synthesis lowering asserts on 128-bit signed and unsigned
  inputs (`expr_synth.cc:164`). Ten synthesized runs fail across descending,
  ascending, and negative packed ranges; all ten ordinary controls pass.
  See `l56/root-wide-synthesis-results.json` and `root_wide_synth_shape*.sv`.
- Fixed unpacked-array word elaboration treats a constant `[7:4]` tail as one
  bit: `words[1][0][7:4]=4'hf` stores `16'h0080` instead of `16'h00f0` in
  both editions. See `l56/root-array-constant-part-results.json` and
  `root_array_constant_part.sv`.

Both are active L56 review findings, assigned to the existing implementation
agent; neither is deferred as accepted behavior. Broad qualification remains
at the previous batch baseline.

A third L56 review control covers a statically invalid unpacked word rather
than the runtime word expressions in the 504-case matrix. Blocking and NBA
preserve both selector calls and the RHS call, while compound assignment
skips both selector calls (`0/0/1` rather than `1/1/1`) in both editions.
`l56/root-invalid-constant-word-results.json` records all six runs. The
static-word compound read path requires the same one-time selector evaluation
as the other L56 routes; correction is assigned to the same worker.

The final part-select can also select packed elements larger than one bit.
`words[oi][mi+:2]` on `[1:0][2:0][7:0]` passes the valid `mi=0` control but
spills into the adjacent outer element at `oi=0, mi=2`: actual
`000012340000`, expected `000000340000`, in both editions. Evidence:
`l56/root-nonleaf-indexed-part-results.json`. This remains an L56 bounds
review finding; the checked carrier must cover the selected packed dimension,
with offsets and widths scaled by its remaining element width.

### L56 corrected review — 2026-09-14

All four pre-integration findings above are corrected in the installed
candidate. `l56/root-corrected-review-results.json` passes 32/32 paired
ordinary/synthesized runs, including the 108-case nonleaf matrix.
`l56/root-corrected-regression-results.json` passes 18/18 runs, including
the original 378 packed, 108 bit/whole-element, and 504 array-word cases
per edition. Installed compiler/target/runtime hashes remain stable.
Neighbor checks pass 11/11 legacy and 19/19 JSON, including negative
mixed-driver tests and checked-property-index controls. These results
supersede the review failures above for this candidate; the historical
failure logs are retained. DD-025 remains separate and open. Full-suite
qualification still belongs to the previous batch until the next broad gate.

### DD-025 expanded baseline — 2026-09-14 after L56

`evidence/constant-assignment-expression-assessment/baseline-results.json`
records 15 forms in both IEEE modes: pre/post increment and decrement,
plain assignment, arithmetic/bitwise compound assignments, and shifts.
All 30 runtime controls pass exact final-local and expression-result checks;
all 30 constant-function invocations fail elaboration. Compiler/target/runtime
hashes are stable across the sweep. The functions use local scalar integers,
with sequenced statements, avoiding unspecified ordering between competing
side effects in one expression. This confirms two missing evaluator routes:
`NetEUnary::evaluate_function` for increment/decrement and `NetEAssignExpr`
(inherited `NetESFunc::evaluate_function`) for assignment expressions.

Authority checked in local IEEE texts: 2017 11.4.1/11.4.2 and 13.4.3,
2023 11.3/11.4.1/11.4.2 and 13.4.3. The assignment-expression result must
reflect the destination type; prefix/postfix forms must return the proper
new/old value while changing the local variable exactly once. Existing
statement assignment evaluation provides a candidate shared implementation,
but no DD-025 compiler change has been made during L57.

### DD-020 L57 receiver review — 2026-09-14

The first installed L57 candidate rejects ordinary missing receiver calls,
but name-based UVM/TLM and constraint-mode fallbacks still accept invalid
receivers or missing methods. The paired root probe accepts 16/24 invalid
calls: `absent.reset`, `absent[0].get_fields`, missing constraint-mode
receivers/constraints, `atomic.put`, and missing `mirror`/`m.write` methods.
The other eight controls reject. Evidence:
`evidence/unresolved-task-assessment/l57-root/named-escape-baseline.json`,
with stable compiler hash `0a7819c74fdaf4022a6ae7d57d41ecc232f07376a9d0bd9649e4a19a476c0b16`.

These are active L57 review findings, not retained exceptions for familiar
method names. Valid direct/indexed/nested methods with those same names and
named constraint-mode updates have independent exact-effect controls ready
for the corrected build. No UVM source changes or broad-suite claims follow
from this focused receiver review.

L57 second-candidate review passes all 28 named-receiver and exact-effect
controls plus the 20-case original paired receiver corpus. A further typed
receiver probe finds the remaining untyped collection-name fallback:
`obj.member.delete/push_back/push_front/insert` accepts an integer member
without diagnostics (eight paired wrong passes), while `pop_back` rejects.
`l57-root/scalar-member-escape-results.json` records this finding. Removal
of `is_multi_hop_collection_task_stub_candidate_` is assigned to the existing
worker; a valid class-owned queue control checks contents and method effects.

L57 final review supersedes the receiver and scalar-member failures above:
`l57-root/final-results.json` passes 40/40 paired outcomes with stable hashes,
and `specialization-neighbor-results.json` passes 12/12, including concrete
specialized task effects and invalid default specialization rejection.
Permanent focus passes 9 legacy and 10 JSON tests. All name-only receiver
stubs identified in L57 are removed; unspecialized type-parameter deferral
remains separate from concrete call execution. Broad/application qualification
remains pending at the feature-batch gate.

### DD-026 — Two-state assignment expression retains unknown bits at runtime

- **Discovered while working:** L58 independent destination-conversion controls.
- **Reducer:** `evidence/constant-assignment-expression-assessment/root-boundaries/bit_assign_x-runtime.sv`.
  Local `bit[3:0] i,j; j=(i=4'bx101);` should produce `{i,j}=8'h55` after
  conversion to the destination type, but yields unknown bits in both modes.
- **Control:** ordinary statements `i=4'bx101; j=i;` pass exact `55` checks
  at runtime and in constant functions, four paired runs recorded in
  `bit-statement-control-results.json`.
- **Evidence:** `root-boundaries/baseline-results.json`, stable compiler hash.
- **Authority:** IEEE 1800-2017/2023 11.3 assignment-expression destination-type
  conversion and 6.11 two-state integral types.
- **Status:** OPEN. This is a runtime expression-conversion defect. L58's
  constant evaluator must implement the correct two-state semantics, not
  copy this runtime behavior. No runtime source edit has been made during
  the independent assessment.

L58 boundary baseline adds 12 forms across runtime/constant evaluation and
both editions: 22/24 runtime checks pass (the two DD-026 failures above),
4/24 constant checks pass (short-circuit controls whose mutation operand is
not evaluated). Narrow wrap, signed arithmetic/shift, 128-bit values,
four-state increment, real inc/dec, and a chosen ternary branch provide
independent exact-result tests. Evidence is under
`evidence/constant-assignment-expression-assessment/root-boundaries/`.

### DD-027 — Runtime increment of a fixed-array element crashes VVP

- **Discovered while working:** L58 indexed-local constant-function controls.
- **Reducer:** `evidence/constant-assignment-expression-assessment/root-boundaries/array_index_post-runtime.sv`.
  A function initializes `a[0]=5`, `a[1]=7`, `idx=0`, then evaluates
  `j=a[idx++]++`. It must leave `idx=1`, `a[0]=6`, `a[1]=7`, and `j=5`.
- **Evidence:** `array-index-baseline-results.json`: both IEEE modes compile
  successfully and VVP terminates with signal 11. The paired constant form
  is an active L58 candidate review case and currently produces an incorrect
  value; that evaluator failure is not the same runtime crash.
- **Possible source:** `tgt-vvp/eval_vec4.c:draw_unary_inc_dec` distinguishes
  signals/selects/properties but requires review of fixed-array word addressing.
- **Authority:** IEEE 1800-2017/2023 11.4.2 and 7.4.6; the index expression
  must retain its single evaluation and postfix must return the old element.
- **Status:** OPEN. Runtime repair is separate from L58 constant evaluation;
  no runtime change was made during this assessment.

L58 current corrected candidate passes 68/68 independent paired constant
runs in `evidence/constant-assignment-expression-assessment/root-current-results.json`,
with stable compiler/target/runtime hashes. This includes typed defaults,
independent invocations, indexed-local postfix effects, and the previously
blocked L56 packed-carrier side-effect oracle. The reversed increment
candidate failure is corrected. Invalid/X/wide array-index no-store behavior
is still under review, including preservation of evaluator failure instead
of silently substituting a default. DD-026 and DD-027 runtime defects remain
separately open; these constant-function passes do not close either.


DD-026 runtime-only confirmation: a delayed module-level expression
`returned=(stored=input_value)` with `bit [3:0] stored` and runtime
`logic [3:0] input_value=4'bx101` produces stored X / returned 0X in both
editions, instead of 5 / 05. This excludes constant-function folding as a
mask. Evidence: `evidence/runtime-assignment-conversion-assessment/baseline-results.json`.

DD-027 expanded runtime baseline: 32 paired runs cover all four pre/post
increment/decrement forms on int, bit, logic, and real fixed arrays. All 24
integral runs crash with signal 11; the eight real runs fail exact effects,
leave the index unchanged, and report an unresolved-functor placeholder.
The real path directly loads/stores a scalar signal label and omits the
array index. Evidence: `evidence/runtime-array-increment-assessment/baseline-results.json`;
all three installed binary hashes remain stable across the baseline.


### DD-025 L58 final review — 2026-09-14

**Focused fix validated; broad batch qualification pending.** Local scalar
assignment expressions and integral/real local increment/decrement now
preserve mutation and expression results during constant evaluation.
Invalid indexed increments return typed signed defaults and suppress stores;
failed index evaluation remains an error. Final independent outcomes are
80/80, permanent legacy 4/4 and JSON 6/6, existing constant-function neighbors
18/18. See `session_logs/2026-09-14_l58_constant_expression_effects.md`.
Eight independent constant-result runtime checks retain DD-027 startup
warnings from uncalled array-function bodies. No clean runtime claim is
made for those forms. DD-026 and DD-027 remain open.


DD-026 L59 independent operator/width baseline: 96 paired cases cover
plain assignment and eleven compound forms on bit[7:0], signed byte,
signed int, and bit[127:0]. Dynamic mixed X/Z input is checked against
manually derived converted storage and 128-bit expression results; 8 pass
and 88 fail on the frozen L58 target. Evidence:
`evidence/runtime-assignment-conversion-assessment/operator-matrix/baseline-results.json`.

M4C-22 is reopened to PARTIAL while the L58 constant-evaluation and L59
runtime-conversion corrections await the next batch qualification. Its
original destination-conversion claim was too broad for the X/Z cases.


### DD-026 L59 final review — 2026-09-14

**Focused fix validated; broad batch qualification pending.** Runtime
assignment-expression code generation now applies the existing two-state
conversion before copying the result for storage and return. This corrects
plain, arithmetic, bitwise, and shift compounds through one common path.
The independent 96-case matrix now passes with exact clean output, compared
with 8/96 before the fix. Eight paired existing expression/negative/constant
neighbors pass; permanent legacy 2/2 and JSON 4/4 pass. See the L59 session
log. DD-027 runtime array increment remains separate and open.


DD-027 L60 boundary baseline adds 108 semantic cases per edition across
bit[7:0], logic[7:0], and real elements; ascending/nonzero/negative ranges;
preincrement and postdecrement; valid, out-of-range, X/Z, and signed
128-bit indices. It pins selector evaluation once and unchanged neighboring
elements. All 24 runs compile, but 16 integral runs crash with signal 11
and eight real runs abort with signal 6 before completing the cases.
Evidence: `evidence/runtime-array-increment-assessment/boundaries/baseline-results.json`.
These are failing baselines, not completed runtime coverage.


### DD-028 — Property increment expressions return without updating storage

- **Discovered during:** L60 adjacent property-path review.
- **Reducers:** `evidence/runtime-property-increment-assessment/scalar.sv`
  and `array.sv`. A scalar `c.a++` returns 5 but fails to update 5 to 6.
  A fixed-array property `c.a[index++]++` evaluates the index once and returns
  the old value, but also omits the element update.
- **Evidence:** `baseline-results.json` records four clean compilations and
  four exact-result failures across IEEE 2017 and 2023, with stable installed
  hashes. Emitted scalar bytecode contains property reads but no increment
  or subsequent property store. The same `prop_word` read-only fallback
  exists in `0c85d32a8:tgt-vvp/eval_vec4.c`, before L60 edits.
- **Expected:** IEEE 1800-2017/2023 11.4.2 requires increment/decrement to
  update the operand and return the appropriate old/new value. A read-only
  substitution does not implement this operation.
- **Status:** OPEN. Queued for L61 after the active fixed-array runtime repair.
  This is distinct from local fixed-array signal storage in DD-027.

DD-028 expanded matrix: int/logic/real, scalar/fixed-array properties, and
all four pre/post ++/-- forms produce 48 failing paired runs: 32 integral
wrong-result exits and 16 real runtime aborts after clean compilation.
Stable-hash evidence: `evidence/runtime-property-increment-assessment/matrix/baseline-results.json`.


### DD-029 — Wide fixed string-array reads alias a valid element

- **Discovered during:** L60 shared array load/store review.
- **Reducers:** `evidence/runtime-string-array-index-assessment/read-32.sv`
  and `read-100.sv`. A two-element string array indexed by unsigned 128-bit
  values `1<<32` or `1<<100` returns element zero instead of the empty string.
- **Evidence:** `baseline-results.json`: four clean compilations followed by
  four exact runtime failures, stable hashes, both IEEE editions.
- **Source:** `of_LOAD_STRA` narrows the index to unsigned and recognizes only
  the unknown flag value, not the separate overflow flag value. This is the
  string-read counterpart of the integral/real bounds work in L60.
- **Expected:** IEEE 1800-2017/2023 7.4.6 typed invalid-index read behavior;
  the result is the element type's default, without reading a valid element.
- **Status:** OPEN. Queued after DD-028; the active L60 shared store fix does
  not by itself repair string reads.

L60 review remains open: literal out-of-range array-element increments are
folded as rvalue defaults before unary elaboration, then rejected as constant
operands (six paired int/logic/real compile failures). Dynamic invalid-index
checks pass, but do not establish literal-index support. Readonly const-array
increment validation also required correction before integration.


### DD-030 — Matching-width packed-select increment crashes at runtime

- **Discovered during:** L60 operand-reconstruction boundary review.
- **Reducers:** `evidence/runtime-selected-increment-assessment/matching-width/`.
  `logic result; result=a[index++]++;` and a four-bit result assigned from
  `a[3:0]++` compile cleanly, then abort in `vvp_vector4_t::add` on a width
  assertion. Four paired runs fail with signal 6.
- **Correction to earlier assessment:** the eight earlier widened-result
  probes were rejected as unsupported vector slices. That evidence does not
  prove all packed-select increment forms are diagnosed: matching result
  widths reach the backend path, which uses the whole carrier width.
- **Expected:** IEEE 1800-2017/2023 11.4.2 selected-lvalue update with the
  selected width, correct prefix/postfix result, and untouched carrier bits.
- **Status:** OPEN. Separate from L60 whole unpacked-array elements. Queued
  after the silent-result DD-028 and DD-029 defects.


### DD-027 L60 final review — 2026-09-14

**Focused fix validated; broad batch qualification pending.** Whole fixed
unpacked-array element pre/post ++/-- now captures the index once and uses
array storage. Native bounds and all invalid-index flags are checked before
narrowing addresses. Const updates are rejected, while literal-invalid
operands preserve typed defaults and suppress stores. Final independent
94/94 outcomes plus six constant/runtime literal-X checks pass; ten existing
neighbors and permanent legacy 4/4, JSON 8/8 pass. The original index converter
is retained: the defect was in its consumers' treatment of overflow flags.
See `session_logs/2026-09-14_l60_runtime_array_increment.md` for exact scope,
known compile warnings, and hashes. DD-028/029/030 remain separate and open.


DD-028 L61 receiver-form assessment: `handles[select_receiver()].property`
with once-only receiver selection already works for scalar int properties
(two paired passes), while indexed property elements omit updates (two
failures) and real expression receivers abort during compilation (two
failures). Evidence: `evidence/runtime-property-increment-assessment/capture-indexed/baseline-results.json`.
Direct signal receivers and expression receivers must both be covered;
passing one does not qualify the other. Separate function-return/member
syntax probes stopped at parsing and have no established grammar disposition;
they are not counted as proven runtime defects or L61 requirements.

### DD-028 L61 frozen review — 2026-09-14

Scalar and fixed-array whole-property pre/post increment/decrement now use
property storage for integral and real operands. Receiver capture precedes
index evaluation; invalid slots yield typed defaults and suppress only the
store. Unsupported property destination shapes produce a target error.
Root frozen replay passes 114/114 paired outcomes, including the 48 original
failures, 48 boundary runs, six receiver controls, six alias-notification runs,
and six const restrictions/const-handle controls. Evidence:
`evidence/runtime-property-increment-assessment/root-frozen/results.json`.
Permanent legacy 2/2, JSON 4/4, and 21 neighboring checks pass. This is focused
validation pending batch qualification, not closure of packed-select DD-030.

DD-029 next: the expanded signed/unsigned 128-bit string-array read matrix
has eight failing paired runs (40 semantic cases per edition), including
nonzero/negative declared ranges and indices above 32, 63, and 100 bits.
Evidence: `evidence/runtime-string-array-index-assessment/matrix/baseline-results.json`.

### DD-029 L62 first-candidate review — 2026-09-14

The runtime consumer now rejects wide native addresses before narrowing and
recognizes all invalid-index flags. Root replay at runtime SHA `65baa472`
passes 16/20 runs, but four module/automatic paired unsigned-128 cases still
alias element -1 in a declared [-1:1] array when the source index is all ones.
The source index is a large positive unsigned value; normalization appears to
wrap it into a valid coordinate before the runtime bounds check. This remains
under investigation, not qualified or waived. Evidence:
`evidence/runtime-string-array-index-assessment/root-candidate/results.json`.

### DD-029 L62 normalized candidate — 2026-09-14

Independent sibling probes establish that unsigned all-ones normalization also
aliased integral and real array reads. The shared normalizer now zero-extends
unsigned source indices before signed canonical arithmetic, following the
existing packed-offset representation. Root replay passes 36/36 paired runs:
original reproducers, module/automatic range matrices, int/logic/real/string
read controls, and invalid-store neighbor preservation. Stable hashes are in
`evidence/runtime-string-array-index-assessment/root-normalized/results.json`.
Permanent regressions, final freeze, and broad batch qualification remain pending.

L62 frozen review:68/68 root cases, permanentlegacy1/1 JSON2/2, fourneighbors.
Direct two-state element comparison also verifies conversion after generic
vector array load, before any assignment can hide X. Source reviewed; batch
qualification remains pending. Evidence `root-final/results.json`.

### DD-031 — Real/string array-return element stores take scalar return path

Status: OPEN, observed during L53–L62 batch repair review.
Legal automatic functions returning typedef unpacked arrays and assigning
individual result elements in a loop abort compilation for real and string
elements: store_real_to_lval at stmt_assign.c2654 and
show_stmt_assign_sig_string at stmt_assign.c2773 assert dimensions==0.
The scalar return-value special case precedes fixed-array element handling.
Integral and logic variants compile but reproduce the separately diagnosed
stale flag4 on the first returned element. Whole-array pattern results in the
existing sv_uarray_func_return test do not cover these element assignments.
Paired2017/2023 evidence: `evidence/batch-20260914-l53-l62/qualification/return-types/baseline-results.json`.
Do not claim full typed array-return support from whole-pattern tests alone.

DD-031 follow-up: real array-return compound assignments also abort in both
editions. Constant and dynamic selectors reach get_real_from_lval assertions
at stmt_assign.c2564 and c2579 respectively. put_real_to_lval also unconditionally
routes return signals through scalar `%ret/real`, so removing the read asserts
alone would not be sufficient. Reuse the existing array load/store paths for
array return storage, retaining the scalar return path only for scalar values.
Evidence: `evidence/batch-20260914-l53-l62/qualification/return-types/compound-baseline.json`.

DD-031 L66: real/string return-array element reads and writes, including real compound updates, are implemented with focused validation. Scalar return handling is now restricted to scalar signals; array paths preserve typed storage. Root28/28 paired outcomes, permanent8/8 per harness, neighbors4/4. See session_logs/2026-09-14_typed_array_return_elements.md. Broad qualification remains at the next batch checkpoint.

DD-030 update: L67 implements the scalar packed-signal and return-slot subset with focused evidence. Broader selected receivers remain open. Current operational scope is in BLOCKERS L67; measured outcomes are in session_logs/2026-09-14_packed_select_increment.md. Earlier reproductions and oracle corrections remain preserved.


### DD-032 — Fixed multiclock assertions start attempts while disabled

- **Discovered during:** L91 consequent compatibility review, 2026-09-15.
- **State:** REPRODUCED; record-only, not part of the active L91 patch.
- **Evidence:** `evidence/batch-20260914-after-l84/l91-review/fixed-control-baseline.json`
  records eight paired runtime failures and the installed compiler hash.
  Both a fixed Boolean consequent and `good[*1:2]` start another attempt
  after `$assertoff(0)` or `$assertkill(0)` at time 11. The source clock ticks
  at 10 and 30; the destination ticks at 15 and 35. Off should allow only
  the pending first attempt to finish; kill should allow neither.
- **Observed:** Off produces two passes, and kill produces one pass at 35,
  in both editions. These failures predate the unbuilt L91 source patch.
- **Authority:** IEEE 1800-2017/2023 assertion control semantics: Off prevents
  new attempts; Kill also discards pending attempts. Verify the appropriate
  control-task and VPI assertion-control clauses when selecting this fix.
- **Source hypothesis:** The fixed multiclock source pipeline starts with an
  unconditional gate; the L86 ranged pipeline has an enabled-state gate.
  A fix must gate new starts while preserving pending attempts for Off,
  and retain kill/restart, coincident clocks, and action scheduling.

DD032 is resolved for the fixed-pipeline control subset by [L92](session_logs/2026-09-15_fixed_multiclock_assertion_control.md); original failing records remain preserved. Broad qualification is pending.

## L99 adjacent VPI output observations — 2026-09-15

During L99 boundary testing, selected real fixed-array `$sscanf` outputs arrived as nonassignable constants, and selected integral outputs with negative/nonzero declared bounds appeared to use an unnormalized word index. These observations are unqualified, require baseline reproduction and IEEE21.3/VPI address review, and are not part of L99 completion. Evidence: `evidence/batch-20260915-after-l95/next-string-array-method-assessment/L99-IMPLEMENTATION.md`. No new implementation is authorized by this record.

### L101 discovery — const local fixed-string-array initializer

During L101, a constant local fixed-string-array aggregate initializer crashed before the character update. This is a separate unqualified initializer defect, not evidence against selected-character reads or the implemented update path. Evidence: `evidence/batch-20260915-after-l95/l101-l102-first-direct.json` and the L101 assessment reducers. Possible scope: declaration/aggregate initialization under clauses6.16 and10.9; standards and minimal root cause require triage. Status: recorded, not selected. L101 readonly regression uses a module const receiver and pins its write rejection.

### DD-033 — Package-scope fixed unpacked-array `parameter` with a keyed assignment-pattern value (2026-09-16)

Found compiling real, unmodified Caliptra formal-verification source
directly (`src/sha256/formal/properties/fv_sha256_core_pkg.sv`, line 26):
```systemverilog
typedef bit unsigned [31:0] a_unsigned_32_64 [63:0];
parameter a_unsigned_32_64 K = '{0:'h428A2F98, 1:'h71374491, ... 63:'hC67178F2};
```
A package-level (or, by the same code path, module-level) `parameter` of
an explicit fixed-unpacked-array typedef, initialized with a fully-keyed
(every index given) assignment pattern, is rejected with `error: Unable
to evaluate parameter K value: '{...}` (`net_design.cc`, the `switch
(expr->expr_type())` in the parameter-elaboration function). Confirmed
independently: slang accepts the identical construct (minimized to a
4-element `t`/`p` reducer), 0 errors. Two real Caliptra `fv_*_pkg.sv`
files use exactly this pattern for round-constant tables (SHA-256's
64-word K table is one; likely more across the corpus given how common
round-constant tables are in hash/cipher RTL).

**Root cause, level 1 (confirmed, minimal fix known):** the `switch`
dispatches on `expr->expr_type()`, and a fixed-array-of-`bit`/`logic`
constant's elaborated value (`NetEArrayPattern`) reports the ELEMENT's
base type (`IVL_VT_LOGIC`/`IVL_VT_BOOL`), landing in the scalar
LOGIC/BOOL case, which requires `dynamic_cast<NetEConst*>` and rejects
anything else — including a `NetEArrayPattern`. This case already has an
exact precedent one arm away: the `IVL_VT_NO_TYPE` case explicitly
accepts a `NetEArrayPattern` for an **unpacked struct** parameter
(`dynamic_cast<const netstruct_t*>(param_type) && !param_type->packed()
&& dynamic_cast<const NetEArrayPattern*>(expr)`), added for the exact
same reason. The direct mirror for an unpacked **array** parameter
(check `dynamic_cast<const netuarray_t*>(param_type)` instead of
`netstruct_t`, in the LOGIC/BOOL case since that's where an array's
value lands, not NO_TYPE) was implemented, built, and confirmed to
resolve this exact symptom.

**Root cause, level 2 (found, NOT fixed, do not re-attempt the naive
level-1 fix alone):** accepting the value is only half the feature.
`K[0]`-style element selection on the now-accepted array parameter
crashes the compiler: `assert: elab_expr.cc:24133: failed assertion
par_ex` in `PEIdent::elaborate_expr_param_bit_`. That function already
has a documented "defensive fallback" dispatcher —
`if (found_in->is_array_parameter(name)) return
elaborate_expr_param_array_(...);` — specifically for array-typed
parameter element selects, but `is_array_parameter()` (`net_scope.cc`)
returned false for `K` even after the level-1 fix, so control fell
through to the scalar-bit path's `dynamic_cast<NetEConst*>(par)` +
`ivl_assert`, which aborts. `is_array_parameter()` checks the given
scope's *own* `parameters` map (`NetScope::is_array_parameter`); the
reducer that exposed this used `import p::*;` (wildcard package import)
to reach `K`, so the scope resolving the identifier and the scope that
actually registered `K` with `is_array_param=true` (set in
`net_scope.cc:505` from the parameter declaration's `udims`) may not be
the same scope in this path — not traced further. **This is a real
compiler crash, strictly worse than the pre-existing clean error it
would replace — the level-1 fix was reverted rather than landed
half-done.** `net_design.cc` is unmodified; `git diff` confirms clean.

**Closure requirements:** both levels together, not level 1 alone —
landing level 1 without level 2 trades a clean, honest `error:` for an
`assert:` abort on the very next thing real code does with such a
parameter (indexing into a round-constant table). Trace why
`is_array_parameter()` disagrees with `net_scope.cc:505`'s registration
for a package-imported array parameter specifically; confirm the fix
against both a direct-scope and wildcard-imported reference, plus a
positional (non-keyed) assignment pattern and a partially-keyed one with
a default (LRM 10.9's `default:` item), which were not tried this pass.
Status: recorded, not selected.

### DD-034 — Mixing `int` and `logic` assertion-local variable declarations in one property breaks binding (2026-09-16)

Found while building a permanent regression for the L122 comma-
separated multi-identifier local-declaration fix. **Not caused by that
fix** — reproduces with zero commas involved, using only the pre-
existing single-identifier `sva_int_local_declarations` chain grammar
that L122 left untouched:

```systemverilog
property p1;
  int a;
  logic [3:0] z;
  (1'b1, a = 1) ##1 (1'b1, z = a[3:0]) ##1 (z == 4'd1);
endproperty
```
Rejected at elaboration with `error: Unable to bind wire/reg/memory
'a[...]'` — `a` is declared (no parse error) but never actually
materialized as a usable local variable once a `logic`-kind declaration
also appears in the same property. Confirmed independently: slang
accepts the identical construct, 0 errors, 0 warnings.

Two same-kind declarations chained together (`int a; int b;`, or
`logic [5:0] x; logic [2:0] y;`) work fine — the break is specifically
mixing `int`-kind and `logic`-kind declarations within one property's
local-variable section, not chaining itself. Not yet root-caused inside
`pform.cc`'s `sva_local_decl_insert_`/`sva_local_decl_types_`
machinery or whatever downstream step materializes each map entry as a
real wire — the two candidate insertion functions
(`pform_sva_declare_int_local`, `pform_sva_declare_logic_local`) both
write into the same `sva_local_decl_types_` map via the same
`sva_local_decl_insert_` helper, so the divergence is likely in a
later, kind-sensitive consumer of that map, not in insertion itself —
not traced further.

L122's own regression test
(`ivtest/ivltests/sv_assert_property_local_multi_ident_decl.v`)
deliberately avoids mixing kinds to stay in scope. Status: recorded,
not selected.

### DD-035 — Sequence match-item assignment LHS is a bare identifier only, no part-/bit-select (2026-09-16)

Found compiling real, unmodified Caliptra source directly
(`src/ecc/formal/properties/fv_montmultiplier_glue.sv`, line 113):
```systemverilog
property compare_p(prime,idx);
logic [REG_SIZE-1:0] fv_result;
logic [FULL_REG_SIZE-1:0] fv_reg;
    ##0 n_i == prime
    ##0 start_i
    ##DLY_CONCAT
    ##0 (1'b1, fv_reg[RADIX-1:0]    = (ecc_montgomerymultiplier.gen_PE[0].box_i.s_out))
    ##1 (1'b1, fv_reg[2*RADIX-1:RADIX]   = (ecc_montgomerymultiplier.gen_PE[0].box_i.s_out))
    ...
```
A sequence match-item assignment (`(bool, lhs = rhs)`) whose LHS is a
part-select or bit-select of an assertion-local variable — building up
a wide local register RADIX bits at a time across successive match
steps — was rejected with a plain `syntax error`. Reduced to a minimal
7-line case (both part-select `fv_reg[3:0] = ...` and bit-select
`fv_reg[3] = ...` reproduce identically); confirmed independently:
slang (`--std 1800-2017`) accepts the part-select form, 0 errors, 0
warnings. This is ordinary `operator_assignment` LHS syntax (IEEE
1800-2017/2023 A.2.10's `sequence_match_item ::= operator_assignment |
...`, whose `variable_lvalue` production includes `[]`/`[:]` selects
like any other assignment target) — not a special restriction on
local-variable match-items specifically.

**Root cause:** `parse.y`'s `sva_seq_atom` match-item-assignment
alternatives (`'(' expression ',' IDENTIFIER '=' expression ')'` and
the `sva_match_call_list`-suffixed variant) hardcode the LHS as a bare
`IDENTIFIER` token — there is no part-/bit-select alternative at all.
`pform_sva_coerce_local_assignment(loc, name, rhs)` likewise only takes
a plain name, with no notion of a selected sub-range.

**Why this is not a quick grammar patch (do not attempt a naive
fix):** unlike L118-L123 (each a pure grammar gap whose downstream
semantic layer already accepted a general expression), this genuinely
needs new semantics, not just a wider grammar production. The
assertion-local variable model here is "the whole named local holds
one value, replaced wholesale by each match-item assignment we
process" (`sva_local_decl_insert_`, `sva_local_decl_types_`,
`pform_sva_coerce_local_assignment`) — there is no existing concept of
a partial-width write. A grammar-only fix that accepts `fv_reg[3:0] =
rhs` but silently lowers it as a full-width overwrite of `fv_reg`
(dropping the untouched high bits, or worse, misinterpreting `rhs`'s
width against the full local rather than the selected slice) would
satisfy the parser while producing wrong values — exactly the
"manufactured apparent success" the project's correctness bar forbids.
A correct fix needs a real read-modify-write lowering: read the
local's current value, blend the RHS into the selected bit range
(e.g. via a synthesized concatenation/part-replace expression), and
assign that back as the new whole-local value — before the *next*
match-item's read of the local observes it.

**Real corpus impact:** `fv_montmultiplier_glue.sv`'s `compare_p`
property (both instantiations, `compare_concat_prime_p_a` and
`compare_concat_prime_q_a`) is exactly this shape: it assembles
`fv_reg` (a wide accumulator) RADIX bits at a time across 9 match
steps, one part-select write per step, before comparing the fully
assembled value. This is a real, non-contrived formal-verification
pattern (checking a modular multiplier's output against pieces
gathered from ecc_montgomerymultiplier's internal per-PE outputs), not
a synthetic edge case.

**Closure requirements:** design and implement the read-modify-write
lowering described above; extend the `sva_seq_atom` match-item
alternatives with a part-/bit-select LHS production (likely reusing
whatever bit/part-select expression nonterminal ordinary lvalues use
elsewhere in `parse.y`, checked for grammar conflicts the same way as
every fix this session — `bison -y -d --report=state` totals compared
before/after); verify against both a part-select and a bit-select
reducer, plus the real originally-failing Caliptra file; add a
functional (not just compile-success) permanent regression that
actually checks the assembled value is correct, not merely that it
parses. Status: recorded, not selected.

**Follow-up investigation (2026-09-16, still not selected — scope is
larger than first estimated):** traced how `lv_name`/`lv_rhs` (the
`sva_seq_step_t` fields a match-item assignment populates, per
`parse_misc.h`) are actually consumed downstream. They are not read in
one place; `lv_rhs` alone appears at 40+ sites across `pform.cc`,
spanning the entire NFA/automaton sequence-lowering engine (roughly
lines 16800-25200): dependency analysis for which locals a step reads
vs. assigns (`sva_expr_reads_lv_`, ~16600-16650), `$past`-style
history substitution for repeated locals (~18200-18280), automaton
leaf/prefix collapsing rules that special-case "no local-variable
assignment present" (dozens of `!st.lv_rhs`/`!cs.lv_rhs` checks used
as simplification preconditions throughout), and the actual register
synthesis (`sva_make_reg_`, a general-purpose carrier-register
allocator used far beyond just local variables) with per-local storage
in a `lv_rhs_reg` vector **indexed by variable name, not by variable
name *plus selected range*** (`pform.cc` ~17200-17280,
~17620-17622, ~17797-17799 — multiple distinct code-generation paths
that each build the write action, not one choke point).

This confirms the closure requirement above is not just "add a grammar
production and a blend expression in
`pform_sva_coerce_local_assignment`" — the read-modify-write blend
would need to be correct at *every* one of these existing whole-
variable-identity call sites, several of which assume `lv_rhs` is the
complete new value for the named local (not a masked partial value),
and some of which actively pattern-match on `lv_rhs`'s absence/
presence as a simplification trigger for the wider automaton (changing
what "having an lv_rhs" means at one of those sites without touching
the others risks silently breaking already-working whole-variable
match-item assignments elsewhere in the automaton, not just leaving
the new part-select case incorrect). This is closer in scope to a
sub-feature of the SVA automaton-lowering engine than a contained
elaboration fix (compare to L124, which touched one function reusing
existing infrastructure) — it needs a dedicated session with time to
read the whole lowering pipeline before writing any code, not
something to attempt opportunistically alongside other fixes. Status
unchanged: recorded, not selected.

### DD-036 — Unpacked-array range select ("array slice") unsupported as a port-connection actual / continuous-assignment source (2026-09-16, HIGH VALUE: single blocker for `caliptra_top`)

**CLOSED 2026-09-16, superseded by [L124](BLOCKERS.md).** The one open
unknown below (word-vs-pin unit conversion) was resolved by reading
`normalize_variable_unpacked()` and `decode_fixed_uarray_slice_select_()`
directly rather than assuming, and the recommended reuse angle
(`decode_fixed_uarray_slice()` wired into
`PEIdent::elaborate_unpacked_net()`) worked as anticipated. Full root
cause, fix, and validation (including a re-run of the same 106-target
census confirming `ICARUS_GAP: 0`, and direct re-compiles of
`ntt_top`/`caliptra_top` at exit 0) are in L124's `BLOCKERS.md` entry.
Left below verbatim as the original finding record.

Found via a differential Icarus/slang static census over Caliptra's
integration filelists (`evidence/caliptra-census-20260916/`, a patched
copy of the pre-existing `run_census.py` driver — see
[[census-driver-paths-rot]] — pointed at this session's own
`iverilog-uvm-concat-select-20260915` build; 106 manifest targets, 60
PASS, 5 `ICARUS_GAP`). **All five `ICARUS_GAP` targets
(`ntt_masked_mult_reduction_tb`, `ntt_top`, `abr_top`, `caliptra_top`,
`caliptra_top_ss_mode`) trace to the exact same two source sites** —
confirmed by diffing each target's full error set: identical four
lines in every one. This is the single thing currently standing
between Icarus and a clean compile of `caliptra_top`, the full-chip
integration target — directly relevant to mission objective 5.

**Symptom**, from real, unmodified Caliptra source
(`submodules/adams-bridge/src/ntt_top/rtl/ntt_masked_special_adder.sv:102-103`
and `submodules/adams-bridge/src/abr_libs/rtl/abr_masked_add_sub_mod_Boolean.sv:134-135`):
```systemverilog
logic [1:0] r0_c0_delayed [WIDTH:0];   // unpacked array, WIDTH+1 elements
...
abr_masked_MUX #(.WIDTH(WIDTH)) r0_MUX_r0 (
    ...
    .r0(r0_c0_delayed[WIDTH-1:0]),     // range-select WIDTH elements out of WIDTH+1
    .r1(r1_c1[WIDTH-1:0]),
    ...
);
```
`r0_c0_delayed[WIDTH-1:0]` is a **range select on an unpacked array**
(selecting a contiguous WIDTH-element sub-array out of the WIDTH+1
declared elements, itself an unpacked array of the same `[1:0]`
element type), used as a port-connection actual. Rejected with:
```
sorry: Array slices are not yet supported for continuous assignment.
     : Port 1 (r0) of sub is connected to r0_c0_delayed[(WIDTH)-('sd1):'sd0]
```
Minimal 10-line reducer confirms the same rejection in isolation, and
confirms independently via slang (`--std 1800-2017`, 0 errors, 0
warnings) that this is legal. This is an honest, already-correct
`sorry:` diagnostic (not a crash, not a silently-wrong compile) — it
meets the project's non-negotiable bar for unsupported behavior. This
is a genuine **feature gap**, not a defect in already-claimed behavior.

**Root cause, located precisely:** `elab_net.cc:1636-1689`
(`PEIdent`'s unpacked-array select-to-net elaboration, reached while
binding a port-connection actual). The existing code at this exact
site already implements a **"slice view" mechanism** for a *sibling*
case — a partial index that supplies fewer indices than the array has
dimensions (e.g. `arr2d[i]` on a `arr2d[N][M]` 2-D unpacked array,
yielding a 1-D `[M]` sub-array): it computes a contiguous pin range in
the source net (`base_const->value().as_long()`, `slice_dims`), builds
a new `NetNet` of `NetNet::IMPLICIT` type with those dimensions, and
pin-aliases it onto the corresponding contiguous range of the source
net's pins via `connect(view->pin(pin), sr.net->pin(base + pin))` —
then returns that view net to stand in for the port connection. When
that path's shape/type checks don't line up (`shape_ok`, `type_ok`),
or when `name_tail.index` isn't the "fewer-dims-than-declared, each a
plain index" shape it expects, control falls through unconditionally
to the `sorry:` at line 1685.

A single-dimension **range select** (`r0_c0_delayed[WIDTH-1:0]` — same
number of dimensions as declared, but a contiguous *sub-range of
elements within one dimension* rather than a reduced-dimension index)
is a different `name_tail.index` shape than what `indices_to_expressions`
above is built to consume here (a partial list of *whole-dimension*
indices, not a `[hi:lo]` range within the last dimension) — this
appears to be why it never even reaches the `shape_ok`/`type_ok`
checks, going straight to the `sorry:`. **Not yet confirmed empirically
how `name_tail.index` represents a `[hi:lo]` range vs. a plain index**
(needs a debug trace or a read of whatever `index_component_t`/similar
structure `path_.back().index` uses) — that is the next concrete step,
not a full implementation guess.

**Much stronger lead found: the exact machinery this needs already
exists and is already used for three sibling contexts, just not this
one.** `index_component_t` (`pform_types.h:140`) already distinguishes
`SEL_BIT` (plain index) from `SEL_PART`/`SEL_IDX_UP`/`SEL_IDX_DO`
(range/indexed-part-select forms) — confirming `[WIDTH-1:0]` parses to
a genuinely different index shape than the partial-index case the
existing `elab_net.cc:1636` branch handles (its call to
`indices_to_expressions()` explicitly hard-errors "Array cannot be
indexed by a range" if it ever receives a non-`SEL_BIT` component,
confirming that function is scoped to plain indices only).

A **complete, general, already-battle-tested decoder for exactly this
shape already exists**: `decode_fixed_uarray_slice()`
(`netmisc.h:179`, implemented `netmisc.cc:1080` via the static
`decode_fixed_uarray_slice_select_()` helper at `netmisc.cc:940`,
which explicitly handles `SEL_PART`/`SEL_IDX_UP`/`SEL_IDX_DO` with
direction checks and clear diagnostics). It is already wired into
**three** other contexts that all accept exactly this kind of
unpacked-array slice today: function/task argument binding
(`elab_expr.cc:15703`, `PECallFunction::elaborate_arguments_`),
concatenation operands (`elab_expr.cc:5117/5252`), and an lvalue path
(`elab_lval.cc:1509/3696`). Its signature takes a `PExpr*` directly —
`decode_fixed_uarray_slice(des, scope, loc, expr, allow_whole, out,
quiet)` — and returns a `fixed_uarray_slice_t{signal, canonical_base,
count, selected_range, element_type, whole}` (`netmisc.h:170`) on
success (return value `1`).

**Recommended implementation angle** (not yet attempted — the one
remaining unknown below must be resolved first): in
`PEIdent::elaborate_unpacked_net()` (`elab_net.cc:1607`), where the
existing partial-index branch currently falls through unconditionally
to the `sorry:` for any non-partial-index shape, add a new branch that
calls `decode_fixed_uarray_slice(des, scope, *this, this, false,
slice)` before giving up; on success, build a `NetNet::IMPLICIT` view
net sized to `slice.count` elements of `slice.element_type` and
pin-alias it onto the source net's pins starting at the slice's base —
the exact same `NetNet` + `connect()` pattern the existing partial-index
branch already uses just below (`elab_net.cc:1668-1679`), just fed by
`decode_fixed_uarray_slice`'s output instead of
`indices_to_expressions`/`normalize_variable_unpacked`'s.

**One concrete unknown to resolve empirically before writing this,
not to assume:** `fixed_uarray_slice_t::canonical_base` and `::count`
are documented as *word/element* units ("Lowest canonical word in the
slice"), while the existing branch's `connect()` loop indexes
`sr.net->pin(base + pin)` in raw *pin* units via `base` from
`normalize_variable_unpacked()`. Whether one canonical word always
equals exactly one `NetNet` pin for an unpacked array (making the unit
conversion an identity) or needs an explicit element-to-pin-width
multiplication has not been checked against the actual `NetNet`/
`netuarray_t` pin layout — get this wrong and the fix would compile
and elaborate cleanly while silently wiring the wrong bits, exactly
the "manufactured apparent success" the project's correctness bar
forbids. Verify by reading `normalize_variable_unpacked()` (used by
the existing sibling branch) and one of the three existing
`decode_fixed_uarray_slice()` call sites' downstream pin/word handling
before writing a single line of the new branch — this is real,
security-sensitive-precision elaboration work and deserves a full,
dedicated session (with real simulation-correctness testing, not just
compile-success testing, for its regression) rather than a rushed
attempt.

**LRM clause for unpacked array range-select syntax needs to be pinned
down precisely before implementing** (this reducer's slang run used
`--std=1800-2017` and slang accepted it, but confirm the exact clause
— likely under 1800's "select" grammar for array types — rather than
assuming a specific subclause number without checking; per
[[discovered-debt-hypothesis-is-not-diagnosis]], verify against the
LRM text directly before coding).

**Census infrastructure note:** the patched driver copy lives at
`evidence/caliptra-census-20260916/` (`run_census.py` +
`fileset_top.sv`, `IVERILOG` repointed at
`iverilog-uvm-concat-select-20260915/local-install/bin/iverilog`, `OUT`
repointed at its own directory) — do not edit the original
`caliptra-rtl-build/static-census-bd31614/run_census.py` in place (see
[[census-driver-paths-rot]]); copy again into a fresh evidence
directory and repoint `IVERILOG`/`OUT` for any future run, since the
worktree path baked in here will itself rot once this worktree is
retired. Full JSON/markdown results:
`evidence/caliptra-census-20260916/caliptra-static-census.{json,md}`.

**Closure requirements:** find the emission site and its assumptions;
design and implement correct lowering (per-element loop or array-slice
net view, whichever the existing net/PWire representation supports
more directly); confirm the LRM clause; verify against the minimal
reducer, both real originally-failing files, and re-run the census
(expect all 5 `ICARUS_GAP` targets to flip to `PASS` from this single
fix, since they share one root cause); add a functional permanent
regression; re-run the full six-gate suite. Status: recorded, not
selected — high priority given it single-handedly unblocks
`caliptra_top`.

### DD-037 — Crash: `ivl` segfaults on `top_{earlgrey,darjeeling}_chip_sim` (both `uvm` and `runtime` lanes) after ~60 unrelated pre-existing errors (2026-09-16)

Found in the same OpenTitan census scan that led to L127 while
double-checking whether L127's fix also happened to cover this crash
— **it does not; this remains open.** (An earlier verification pass
this session incorrectly reported this as fixed by L127 based on
checking only the first few `hard_errors` entries rather than the
full list, which ends in the crash; corrected here.)

`lowrisc:dv:top_earlgrey_chip_sim:0.1` and `top_darjeeling_chip_sim`
(both the `uvm` and `runtime` lanes for each) segfault
(`returncode: 139`, no `Assertion failed` message — a pure SIGSEGV,
not a controlled `ivl_assert`/`assert()` abort like DD-038 below)
after accumulating roughly 60 diagnostic lines covering many already-
independently-known, unrelated feature gaps (SPI agent task-output
queue/dynamic-array formal mismatches, `foreach` array-target
resolution failures, container slice/index chains, streaming-
concatenation width mismatches, `std::randomize() with` constraint
forms, etc. — this full-chip integration target aggregates essentially
every currently-open DV frontier item at once). The crash itself has
**not been reduced to a minimal case** — with ~60 candidate error
sites contributing to whatever state the crash depends on, isolating
the actual trigger requires either bisecting by removing/stubbing
error conditions one at a time from the real file set, or a targeted
read of whatever code path runs immediately after the last printed
diagnostic (`chip_scoreboard.sv:49`'s `foreach` target-resolution
error) to look for an unguarded null-pointer use analogous to L127's,
but this was not attempted this pass.

**Closure requirements:** reduce to a minimal reproducer (start from
the last diagnostic printed before the crash and work backward, or
build a small file exercising just a `foreach` target-resolution
failure inside a `chip_scoreboard`-shaped class hierarchy to see if
that alone crashes); once reduced, apply the same discipline as
L127 (check for an unguarded null dereference following a reported
elaboration failure). Given the scale of unrelated pre-existing debt
in the same file, this is likely NOT one afternoon's work — plan a
dedicated session. Status: recorded, not selected.

**Follow-up (2026-09-16, same pass, inconclusive):** the real file's
crash trace shows the identical `foreach` target-resolution error
(`chip_scoreboard.sv:49`) printed twice — once under the properly-
named class scope (`chip_env_pkg.chip_scoreboard.process_alerts_for_
cov.$ivl_foreach884`) and again immediately before the crash under an
ANONYMOUS auto-generated scope name (`chip_env_pkg._ivl_1.process_
alerts_for_cov.$ivl_foreach884`, `_ivl_%d` being the generic anonymous-
scope-naming counter in `net_scope.cc` — not specific to `foreach` or
any retry mechanism by itself). This double appearance, with the named
class scope replaced by an anonymous one on the second occurrence,
*resembles* the same "same construct re-processed under a different/
wrong scope" shape as L121/L126 (both of which really were exactly
that), so it was tried as a lead: built a 3-level reducer (`cfg.
chip_vif.alerts_cb.alerts`, a class member holding a virtual-interface-
handle-to-clocking-block, `foreach`'d from within a class method) —
it did NOT crash (5 ordinary errors, clean exit). The real construct
has a 4th level the reducer didn't reproduce (`cfg.chip_vif.alerts_if.
alerts_cb.alerts` — an extra virtual-interface-to-sub-interface hop
before the clocking block), so this is inconclusive, not a
disproof — the extra nesting level may be exactly what matters.

**Second follow-up (2026-09-16, same pass): built the exact 4-level
construct faithfully** (an `alerts_if` interface with a clocking
block, nested as a named instance inside a `chip_if` interface,
referenced through a class member's `virtual chip_if` handle — this is
structurally identical to the real
`hw/top_earlgrey/dv/env/chip_if.sv`/`alerts_if.sv` pair, not an
approximation). This reproduces the **exact same error message** as
the real file character-for-character (`Unable to resolve foreach
target cfg.chip_vif.alerts_if.alerts_cb.alerts in scope ...`) — so the
4-level nesting depth is confirmed NOT the missing ingredient; the
`foreach`-resolution failure itself is fully, faithfully reproduced.
**But it still does not crash alone** (1 clean error, ordinary exit).
This rules out "nesting depth" as the missing piece and narrows the
remaining candidate explanation to the one already suspected: the
crash requires the *same* construct's failure to be processed a
*second* time under a *different* (anonymous, auto-generated) scope —
matching the real crash trace's duplicate error appearance
(`chip_env_pkg.chip_scoreboard....` then `chip_env_pkg._ivl_1....`)
— which single-instantiation reducers structurally cannot exhibit.
Reproducing that would need two elaborated instances of a class
containing this method (e.g. two UVM components both extending a
common base that declares it, or some other path that elaborates the
same method body twice under different scope identities) — not
attempted this pass; this is a concrete, specific next step for
whoever picks this up, not a vague "reduce further." Not pursued
further this pass.

**Third follow-up (2026-09-17): "two elaborated instances of a
class" ruled out.** Extended the 4-level reducer to two `chip_if`
instances (`u_chip_if0`, `u_chip_if1`) each driving its own
`scoreboard` instance (`sb0`, `sb1`), both calling the same
`process_alerts_for_cov()` method. Still does not crash, and — the
decisive part — the `foreach`-resolution error is printed only
**once**, not twice as in the real trace. A class method body
elaborates once as shared code regardless of how many object
instances call it; per-instance elaboration was never going to
duplicate the error under a second scope, and it didn't. This closes
the specific next step the previous follow-up recorded.

Status of the two concrete leads this entry has recorded so far:
- 4-level nesting depth: ruled out (second follow-up above).
- Two elaborated instances of the same class: ruled out (this
  follow-up).

Remaining candidate explanation, unchanged and still untested:
whatever construct actually causes the *same* method body to be
re-elaborated a *second* time under a *different*, anonymous
`_ivl_%d` scope (`net_scope.cc`'s generic anonymous-scope counter,
not specific to `foreach` or any known retry mechanism). No third
hypothesis has been formed — the candidates (`fork`, an unnamed
`begin`, virtual/derived-class method dispatch, some other deferred-
elaboration retry path) are unconfirmed guesses, not evidence-backed
leads, and testing them blind risks burning a session without
converging. Confirms the earlier assessment: this needs a dedicated
session with a fresh angle (most likely: read the code path that runs
immediately after `chip_scoreboard.sv:49`'s diagnostic in the real
file, or trace what actually creates an `_ivl_%d`-named scope during
class-method elaboration, rather than guessing at reducers). Not
pursued further this pass.

### DD-038 — Crash: `ivl` aborts (`ivl_assert`/`assert()` failure in `pform_endgenerate`) on `spid_upload_sim` after cascading syntax errors (2026-09-16)

**CLOSED 2026-09-16, superseded by [L128](BLOCKERS.md).** The
grammar-level root cause identified in this entry's own follow-up
(qualifier-prefixed task/function forms only reachable from
`class_item`, forcing bison panic-mode recovery for the unmatched
`K_static` token at module scope) was confirmed as the true trigger by
empirically patching a local scratch copy of the real file (removing
just the word `static`, crash disappeared entirely) before
implementing the fix. Full root cause, fix, bison-conflict validation,
and real-corpus confirmation (the exact originally-crashing
`spid_upload_sim` target no longer crashes) are in L128's
`BLOCKERS.md` entry. Left below verbatim as the original finding
record.

Found in the same scan as DD-037, also incorrectly reported fixed by
L127 in an earlier pass of this session before the full `hard_errors`
list was checked; corrected here — **this remains open.**

`lowrisc:dv:spid_upload_sim:0.1` (`runtime` lane) aborts (SIGABRT, not
SIGSEGV — a genuine, deliberate `assert()` firing, not a wild pointer
dereference) with:
```
Assertion failed: (pform_cur_generate->scheme_type == PGenerate::GS_CASE_ITEM
  || parent_generate->scheme_type != PGenerate::GS_CASE),
  function pform_endgenerate, file pform.cc, line 2907.
```
after 82 accumulated diagnostic lines, the great majority genuine
`syntax error`/`Invalid module item`/`Invalid module instantiation`
cascades starting at `src/lowrisc_dv_spid_upload_sim_0.1/tb/
spid_upload_tb.sv:186`.

**Follow-up investigation (2026-09-16, same pass): the crash reproduces
standalone from this one file alone**, no other dependencies needed
(`iverilog -g2012 -t null hw/ip/spi_device/pre_dv/tb/spid_upload_tb.sv`
aborts directly) — a much smaller starting point than the full
`spid_upload_sim` fusesoc target.

**The first syntax error's root construct identified, and it is
already-known-invalid, not a new gap:** line 186 is
`static task host();` — a `static` qualifier on an ordinary task
declared directly in a module body (not a class out-of-block method
definition). Confirmed independently with slang: it also rejects this,
with a far more specific diagnostic than Icarus's generic `syntax
error` — `error: qualifiers are not allowed on out-of-block method
definitions [-Wqualifiers-on-out-of-block]`. So Icarus's *rejection* is
correct (matches
[[top-syntax-family-is-often-upstream-invalid]]'s pattern exactly: a
`static task` at module scope, named in that very memory as a
construct worth disproving before assuming it's a real gap) — only the
diagnostic's *quality* (opaque "syntax error" vs. a clear, specific
message) and the *downstream crash* are real problems. `sw()` (line
293) is a second, identical `static task` at module scope, and is what
actually contains the `case (cmd) inside ... endcase` block
(lines 312-375) whose nested `begin...end` case-item bodies are what
the crash trace's line numbers (338-354) fall inside — i.e. the crash
happens while processing *ordinary procedural case-item bodies*, not
anything resembling a real `generate case`. This means the parser's
error-recovery after the `static task sw();` syntax error somehow
routes subsequent processing of this *procedural* `case (cmd) inside`
construct through code paths that manipulate `pform_cur_generate`'s
generate-scheme bookkeeping — plausibly a bison error-recovery state
overlap between ordinary `case_item` and `generate_case_item`
productions once the parser is off its normal path, but this was not
traced past `pform_endgenerate()`'s consuming end (`pform.cc` ~line
2881-2913) to find where a generate scheme's `GS_CASE`/`GS_CASE_ITEM`
gets spuriously pushed in the first place.

**Deliberately not attempted as a quick "guard the assert" patch:**
`pform_endgenerate()`'s assertion at line 2906-2907 protects a real
structural invariant (a generate-case item's containing generate must
itself be tagged `GS_CASE`, or the current scheme must itself be
`GS_CASE_ITEM`) that later code
(`parent_generate->generate_schemes.push_back(pform_cur_generate)` and
whatever eventually walks `generate_schemes`) may rely on. Silently
disabling or loosely guarding this assertion when `error_count > 0`
would stop *this* crash but risks pushing a genuinely-inconsistent
scheme object that a *different*, unguarded downstream traversal then
dereferences unsafely — trading one diagnosable crash for a harder-to-
trace one, or worse, a silently-wrong internal structure that doesn't
crash at all. That is exactly the kind of "manufactured non-crash"
this project's correctness bar forbids trading for safety without
first understanding the invariant fully.

**Closure requirements:** trace the actual parser actions between the
`static task sw();` syntax error's recovery and the crash to find
where/why a `GS_CASE`/`GS_CASE_ITEM`-tagged `PGenerate` gets created
for what is really just an ordinary procedural `case (cmd) inside`
block — likely by adding targeted instrumentation (print
`pform_cur_generate`'s scheme_type transitions) while re-running the
minimal single-file reducer, or by reading the bison error-recovery
states around the `case_item`/`generate_case_item` productions in
`parse.y` directly. Once the actual mis-route is understood, the
correct fix is almost certainly to prevent that mis-route from
happening at all (so `pform_endgenerate()`'s invariant is never
violated), not to weaken the invariant check itself. Separately (lower
priority, since the underlying rejection is already correct): give
`static`/`automatic` qualifiers on a non-class-scope task/function
declaration their own specific diagnostic (matching slang's
"qualifiers are not allowed on out-of-block method definitions")
instead of a generic `syntax error`, improving diagnostic quality even
though the construct stays correctly rejected either way. Status:
recorded, not selected — the standalone single-file reducer
(`hw/ip/spi_device/pre_dv/tb/spid_upload_tb.sv`, no dependencies)
significantly lowers the bar for a future session to pick this up.

### DD-039 — `syntax error` on a chained, un-parenthesized leading cycle delay (`##N ##M seq`) (2026-09-16, fixed 2026-09-17)

Found while validating a DD-035 partial fix against the real
originally-failing Caliptra file (`src/ecc/formal/properties/
fv_montmultiplier_glue.sv`) — **confirmed unrelated to that fix and to
any other change this session** (reproduces identically with the
part-select grammar addition reverted via a stashed rebuild-and-retest).

The first reproducer found looked tangled up with parameterized
properties, a bare-identifier cycle delay, and a match-item assignment
whose RHS was a function call — but further bisection (removing one
ingredient at a time and re-testing after each removal) showed every
one of those was a red herring. The true minimal reproducer has none
of them:
```systemverilog
module t;
  bit clk = 0, b = 0;
  always #5 clk = ~clk;
  default clocking cb @(posedge clk); endclocking
  property p1;
    ##3 ##0 b;      // syntax error
  endproperty
  ap: assert property (p1);
endmodule
```
The discriminating pair: `##3 ##0 b;` is a `syntax error`, while
`##3 (##0 b);` (same delays, parens added around the second one)
compiles cleanly. slang (`--std 1800-2017`) accepts `##3 ##0 b;` with
0 errors, so this is not an upstream-invalid-syntax false alarm (see
[[top-syntax-family-is-often-upstream-invalid]]) — it is a genuine
Icarus grammar gap. Reproduces identically in every `sequence_expr`
context tried: a bare `property`/`sequence` body, the consequent of
`|=>`, and an inline `assert property (...)`. Not related to match-item
assignments at all — the very first minimal-enough reducer already
showed a bare boolean (`##3 ##0 b`) fails the same way a match-item
form does.

**Root cause:** in `parse.y`, `sva_seq_expr`'s
leading-cycle-delay productions (e.g. `K_CYCLE_DELAY sva_cycle_delay_value
sva_seq_atom` at parse.y:8369, and its bounded/unbounded-window siblings
at 8372/8390/8404) all take a trailing `sva_seq_atom`, not a trailing
`sva_seq_expr`. A second, unparenthesized `K_CYCLE_DELAY ...` only
reduces to `sva_seq_expr` (there is no `sva_seq_atom` alternative that
starts with `K_CYCLE_DELAY`), so it can't fill that trailing slot —
only the explicit `'(' sva_seq_expr ')'` `sva_seq_atom` alternative can
convert it back, which is why adding parens works around the gap.
IEEE 1800-2017/2023's `sequence_expr ::= cycle_delay_range
sequence_expr | ...` is right-recursive through the *full*
`sequence_expr`, not just through a delay-atom subset, so the grammar
needs a real production, not just this narrow write-up.

Runtime semantics of the already-accepted parenthesized form were
checked before recording this (per [[discovered-debt-hypothesis-is-not-diagnosis]]):
`pform.cc`'s `pform_sva_single_delay` accumulates (`step.delay_lo +=
value`), not overwrites, and a real clocked runtime check confirmed
`a |=> ##3 (##0 b)` and `a |=> ##5 b` fire identically — so the fix
only needs to close the parse gap, not touch delay-accumulation
semantics.

**Fix:** added a new `sva_seq_lead_delay` nonterminal in `parse.y`
(type `<sva_seq>`, alongside `sva_seq_expr`/`sva_seq_atom`) with ten
alternatives: each of the five leading-delay shapes (`K_CYCLE_DELAY
sva_cycle_delay_value`, the bounded window `[e:e]`, the unbounded
window `[e:$]`, and the `[*]`/`[+]` shorthands), each with a trailing
operand that is either a plain `sva_seq_atom` (base case, identical to
the previous behavior) or another `sva_seq_lead_delay` (the new
recursive case — right recursion through the delay productions
specifically, not through the full `sva_seq_expr`, so `K_until`/
`K_implies`/`K_iff`/`K_within`/`sva_seq_comb_concat` are not pulled
into a leading delay's decision point and existing `##N a until
b`-shaped bindings are untouched). `sva_seq_expr`'s five original
leading-delay productions were replaced with a single `sva_seq_expr :
sva_seq_lead_delay` pass-through, so there is exactly one derivation
per input (no new reduce/reduce ambiguity). Each alternative's action
is bodily identical to its former `sva_seq_expr` counterpart, applying
the delay to the trailing operand's first step — `pform_sva_single_delay`
and the inline window logic both accumulate into that step's existing
`delay_lo`/`delay_hi` rather than overwrite, so a chain of N delays
folds down correctly regardless of chain length, confirmed by the
runtime check below.

Verified via `bison --report=state`: shift/reduce and reduce/reduce
conflict totals (562/1122) are byte-for-byte identical across
`origin/main`, the DD-035 part-select commit, and this fix — zero new
conflicts. All prior reducers in this entry (and their variants —
literal delays, parameter-valued delays, chained-with-a-preceding-atom,
match-item and plain-boolean trailing forms, every `sequence_expr`
context) now compile cleanly; where a *different*, pre-existing
unsupported-semantics diagnostic legitimately still applies (e.g. the
parameter-valued bounded cycle-delay composition sorry), it is reached
honestly instead of masked by a syntax error. Runtime-verified with a
real clocked stimulus (not just `-tnull`) that `a |=> ##2 ##3 b`
behaves identically to `a |=> ##5 b` — both pass or fail together
against the same stimulus, proving the composed delay is exactly 5,
not silently wrong in either direction. Permanent regression:
`ivtest/ivltests/sv_sva_chained_leading_cycle_delay.v`. Status: fixed.

### DD-040 — `foreach` selected-prefix into an ASSOCIATIVE array silently iterates the wrong keys; the selector is dropped, not applied (2026-09-17)

Found via a fresh OpenTitan census against the corrected release pin
(Earlgrey-PROD-M6): `hw/dv/sv/dv_utils/dv_report_catcher.sv:19`,
`foreach (m_changed_sev[id][msg])` over `uvm_severity
m_changed_sev[string][string]`, where `id` is already a local
variable — a `foreach` **selected prefix** (IEEE 1800-2017/2023
12.7.3: an index-bracket identifier already declared in an enclosing
scope acts as a fixed selector, not a fresh loop variable). This form
had never been supported for the UNDOTTED double-bracket shape
(`arr[id][msg]`, no `.member` between the brackets) — only the
DOTTED form (`obj.key[0].member[i]`) had a grammar production. Fixing
the grammar gap surfaced a far more serious, PRE-EXISTING bug in the
shared elaboration path.

**Grammar fix:** added a new `parse.y` alternative to the `foreach`
statement's production list, mirroring the already-existing dotted
"selected-prefix" rule (`K_foreach '(' foreach_array_identifier '[' loop_variables ']'
'.' foreach_array_identifier '[' loop_variables ']' ')'`), minus the
`.foreach_array_identifier` in between. A bare identifier in the first
bracket reduces through `loop_variables` for the same 1-token-lookahead
reason the existing dotted rule's own comment documents (bison cannot
distinguish a length-1 `loop_variables` list from an `expression` with
one token of lookahead). Verified via `bison --report=state`: shift/
reduce and reduce/reduce conflict totals unchanged from baseline — zero
new conflicts.

**Correctness gate added (parse.y, before treating the identifier as a
selector):** the LRM's "already declared in an enclosing scope" clause
is the dividing line between a legal selector and an accidental fresh
loop variable, so a new `pform_wire_visible_in_enclosing_scope()`
helper (`pform.cc`/`pform.h`, walks `LexicalScope::wires_find()` up the
full parent chain — the existing `pform_get_wire_in_scope()` only
checks one level, insufficient here since the selector can be declared
in any scope enclosing the `foreach`, not just the innermost one) now
checks this at parse time. An undeclared identifier in that position
(`foreach (m[k1][k2])` with fresh `k1`) is a real, focused elaboration
error, not a silent pass — confirmed independently: slang
(`--std 1800-2017`) also rejects it, as "use of undeclared identifier
'k1'". Before this gate, Icarus silently accepted it with only a soft
"Unable to bind" warning and undefined runtime behavior.

**The deeper bug (why this stays a `sorry:`, not a real fix):** with
the grammar and undeclared-selector gate both correct, a real
clocked/discriminating-population runtime test (NOT just a compile
check — see [[discovered-debt-hypothesis-is-not-diagnosis]] and
[[parse-y-conflict-totals-are-insufficient]], the same "verify past
the first coincidental pass" discipline) showed that `foreach
(m[id][msg])` — for EITHER a literal constant selector (`m["a"][msg]`)
or a variable one, and regardless of the associative array's key
type — never actually applies the selector at all. Root cause:
`PForeach::elaborate`'s `hier_sig` fast path (`elaborate.cc`) finds
`m` as a plain signal via `des->find_signal()` (which matches on the
base name alone, ignoring the appended selector index entirely) and
calls `elaborate_signal_array_()`, which wraps the WHOLE outer array
in a bare `NetESignal` and hands it straight to
`elaborate_assoc_array_()` — the selector index is simply never
consulted. Confirmed the identical bug is reachable through the
ALREADY-MERGED, previously-shipped "fixed expression" rule too
(`parse.y`'s `'[' expression ']' '[' loop_variables ']'` production,
landed earlier this session under a different item) — this is not a
defect introduced by the new grammar rule, it is a latent gap the new
rule made reachable from a second angle, exactly like DD-039's
chained-delay discovery. Failure mode varies by shape (a string-keyed
outer array with a variable selector iterates the OUTER array's own
keys into the inner loop variable; other combinations silently
iterate zero times) — all wrong, none diagnosed, until this fix.

**Fix scope (deliberately narrow — refuse, don't attempt to
lower):** added a `foreach_target_has_selector_prefix_()` check
(`elaborate.cc`) gating both reachable dispatch sites
(`elaborate_signal_array_` and the parallel `elaborate_foreach_target_expr_`-based
expression route) to refuse with an honest `sorry:` whenever the
**final** path component being iterated carries a non-empty selector
index, rather than attempt the real fix (threading a runtime-evaluated
key expression through `elaborate_assoc_array_`, which `PForeach`'s
current interface does not support and is out of scope for this
session).

**A near-miss worth recording as its own lesson:** the first version
of this gate checked whether ANY component of the target path had a
non-empty index, not just the final one. That misclassified plain,
already-correct dotted class-property `foreach` targets — where an
EARLIER component's index is an ordinary element select (e.g. the
outer foreach's own loop variable indexing into a different, non-target
array along the way) rather than a selector on the array actually
being iterated — as selector-prefixed, and refused them too. UVM's own
`uvm-core/src/base/uvm_phase.svh:1551` uses exactly this shape
(`foreach (successors[s].m_predecessors[pred])` nested inside `foreach
(successors[s])`, where `s` is the outer loop's own variable and
`m_predecessors` — the real target — carries no selector of its own).
The overly-broad gate took UVM regression from 357/0/0 to 0/357/0 in
one local run, since `uvm_phase.svh` is a mandatory dependency of
every UVM test — caught before landing by re-running the full UVM
gate specifically because the mission's local six-gate bar treats any
regression there as disqualifying, not by code review alone. Narrowed
the check to `array_path.back().index` (the component whose type is
actually iterated) before landing; UVM regression is 357/0/0 with the
corrected gate. See `sv_foreach_nested_assoc_no_selector.v` for the
permanent regression protecting this exact shape.

**Closure requirements:** thread a runtime-evaluated selector key
expression through `elaborate_assoc_array_()` so the correct sub-array
is looked up on every loop entry (not baked in once at elaboration
time, since the selector's value can change between separate `foreach`
executions or — per the near-miss case above — across outer-loop
iterations). This does not by itself unblock the OpenTitan UVM/runtime
census jobs that hit `dv_report_catcher.sv`: a `sorry:` still
increments `error_count`, so those cores remain `FAIL`, just with an
honest, specific diagnostic instead of a raw `syntax error`. Status:
recorded, not selected.

Tests: `ivtest/ivltests/sv_foreach_selected_prefix_assoc_fail.v`
(undotted selector into a nested associative array, `sorry:`,
gold-verified), `sv_foreach_undotted_selected_prefix_fail.v`
(undeclared selector identifier, real elaboration error, gold-verified),
`sv_foreach_nested_assoc_no_selector.v` (the UVM-shaped false-positive
protection, real clocked runtime check with a discriminating population
— two outer keys with disjoint inner key sets — not just a compile
check).

### DD-041 — Crash: `ivl_assert` failure evaluating a class-method `localparam` initialized from a bare-name outer-scope parameter (2026-09-17)

Found via the same fresh OpenTitan census (Earlgrey-PROD-M6) that surfaced
DD-040: `hw/dv/sv/entropy_src_xht_agent/seq_lib/entropy_src_xht_base_device_seq.sv:55`,
`localparam int RngWordsPerByte = 8/RNG_BUS_WIDTH;` inside
`test_cnt_hash()`, a method of class `entropy_src_xht_base_device_seq`.
`RNG_BUS_WIDTH` is a plain `parameter int` declared in
`entropy_src_pkg`, reaching this class body's scope via
`entropy_src_xht_agent_pkg`'s package-level `import entropy_src_pkg::*;`
(the class itself does not import anything — the earlier DD-035/DD-039
session already established class-body `import` is correctly illegal,
see [[class-body-import-is-illegal]]; this is a different construct
entirely, an ordinary bare-name reference to an already-visible outer
parameter). Compiling this file aborts:
```
entropy_src_xht_base_device_seq.sv:55: assert: net_design.cc:1518: failed assertion cur->second.ivl_type
Abort trap: 6
```
Both `uvm` and `runtime` lanes of `lowrisc:dv:entropy_src_sim:0.1` hit
this identically (2 census jobs), since the file is compiled into both.

**Minimal standalone reproducer** (no OpenTitan/UVM dependency,
confirmed with `-tnull`):
```systemverilog
package my_agent_pkg;
  parameter int RNG_BUS_WIDTH = 4;
  class C;
    function void f();
      localparam int X = RNG_BUS_WIDTH;
      $display(X);
    endfunction
  endclass
endpackage
module t;
  import my_agent_pkg::*;
  initial begin C c = new; c.f(); end
endmodule
```

**Bisection so far** (each variant isolates one ingredient; all other
ingredients held at the shape above):
- Replacing `RNG_BUS_WIDTH` with the fully qualified
  `my_base_pkg::RNG_BUS_WIDTH` (a separate package, no wildcard
  import) — **does not crash**, prints the correct value. So a bare
  parameter name specifically, not a qualified one, is implicated.
- Moving the exact same `localparam int X = RNG_BUS_WIDTH;` line into
  an ordinary package-scope **function** (not a class method) — **does
  not crash**, prints the correct value. So this is specific to a
  class *method* body, not bare-name outer-parameter resolution in
  general.
- Removing the division (`8/RNG_BUS_WIDTH` → bare `RNG_BUS_WIDTH`) —
  **still crashes**. The division/arithmetic is not required.
- Removing the wildcard import entirely, declaring `RNG_BUS_WIDTH` and
  the class in the *same* package (no cross-package reference at all,
  the name is visible purely through ordinary lexical scoping) — **still
  crashes**. So this is not specific to wildcard-import resolution
  either; it reproduces for any bare-name reference from a class
  method to a parameter declared in an *enclosing* (not class-local)
  scope.
- A bare-name reference to a parameter declared directly at *module*
  scope (not package scope) from that module's own class does not
  reach this crash — it instead hits a pre-existing, unrelated
  "Unable to bind parameter" error (a separate, not-yet-investigated
  gap; class-in-module bare-name outer-parameter visibility may simply
  work differently or not be supported at all — not pursued this pass).

**Root cause (not found — traced partway, stopped before guessing):**
`NetScope::evaluate_parameter_` (`net_design.cc` ~line 1941-1949)
elaborates `cur->second.val_type` into `cur->second.ivl_type` for
every parameter exactly once, immediately before dispatching to
`evaluate_parameter_logic_` (or the real/string/array variants) by
`use_type`. For an explicitly-typed `localparam int X = ...`, `val_type`
is always present, so `elaborate_type()` should always produce a
non-null `ivl_type` before `evaluate_parameter_logic_` ever runs and
checks it at line 1518. That it's null there for the class-method
case, but not for the plain-function case with the identical
declaration shape, means either: (a) class-method-local parameters
reach `evaluate_parameter_logic_` through a different call path that
skips this elaborate-type step, or (b) resolving the bare-name
`val_expr` (`RNG_BUS_WIDTH`) during `elab_and_eval()` recursively
touches parameter evaluation for the WRONG scope's `cur` iterator —
e.g. a class-method-local parameter table entry that shares the name
but was never given a `val_type` in the first place, as opposed to the
outer package's correctly-typed entry. Distinguishing these (and
finding why only the class-method path takes whichever route is
wrong) needs tracing `evaluate_parameters()`'s scope-walk order and
`elab_scope.cc`'s class-method scope construction directly, not
further black-box bisection.

**Closure requirements:** trace `NetScope::evaluate_parameters()`'s
scope-walk order for a class method scope specifically (does it visit
the method's own scope, or via a different path than plain
function/package scopes?), and instrument (or step through) which
`param_ref_t`/`cur` the crashing `ivl_assert` actually refers to when
it fires — confirm whether it is genuinely the class-method-local
entry for a name that was never locally declared (in which case the
bug is likely a spurious/duplicate parameter-table entry created
during class-method scope elaboration) or the correctly-shared outer
entry (in which case the bug is in whatever clears `ivl_type` between
the dispatcher and the logic evaluator). A real, discriminating
regression test (two class methods each referencing a differently-typed
outer parameter, or a runtime check on the correctly-elaborated value,
not just "does it not crash") is required once a fix is attempted,
per [[discovered-debt-hypothesis-is-not-diagnosis]] and this session's
own DD-039/DD-040 near-misses. Status: recorded, not selected.

### DD-042 — Covergroup cross `select_expression with (...)`: the `with` clause only accepts a bare cross/bins name, not a general `binsof`/`&&`/`||` selector (2026-09-17)

Found via the fresh OpenTitan census (Earlgrey-PROD-M6): two independent
real corpus files hit a raw `syntax error` on a cross-body `ignore_bins`
whose selector combines `binsof()` with a `with (...)` predicate:

`hw/ip/csrng/dv/cov/csrng_cov_if.sv:78-80`:
```systemverilog
ignore_bins not_full_and_not_ready = !binsof(cp_hw0_cmd_depth) intersect {2}
                                     with (!hw0_cmd_rdy);
ignore_bins full_and_ready = binsof(cp_hw0_cmd_depth) intersect {2} with (hw0_cmd_rdy);
```

`hw/ip/pwm/dv/env/pwm_env_cov.sv:99-101`:
```systemverilog
ignore_bins undefined_state = (binsof(blink_en_cp) && binsof(htbt_en_cp))
                                with ((blink_en_cp == 0) && (htbt_en_cp == 1));
```

**Confirmed via the LRM, not just slang, before touching the grammar**
(per [[top-syntax-family-is-often-upstream-invalid]]): IEEE 1800-2023
A.2.10 (clause 19.6.1) gives
```
select_expression ::=
    select_condition
  | ! select_condition
  | select_expression && select_expression
  | select_expression || select_expression
  | ( select_expression )
  | select_expression with ( with_covergroup_expression ) [ matches ... ]
  | cross_identifier
  | cross_set_expression [ matches ... ]
select_condition ::= binsof ( bins_expression ) [ intersect { covergroup_range_list } ]
```
— `with (...)` is a suffix on the **general, recursive** `select_expression`
production (so it can follow `!`/`&&`/`||`/parens/`binsof(...)
intersect {...}` just as well as a bare name), not something bound
only to `cross_identifier`. 19.6.1.2's prose confirms the semantics:
"the `with` clause specifies that only those bin tuples in the
**subordinate select_expression**... are selected" — `cross_identifier`
is explicitly called out as just ONE alternative select_expression
that happens to select all tuples, not the only thing `with` can
attach to. Confirmed independently: slang (`--std 1800-2017`) accepts
both real-file forms above, 0 errors.

**Root cause:** `parse.y`'s `cross_body_opt` already has a general,
recursive `cross_bins_expr` nonterminal (`binsof(...)`,
`binsof(...) intersect {...}`, `!`, presumably `&&`/`||` — the
IEEE 1800-2017 M11-3 comment above it says so) used for the plain
`ignore_bins X = cross_bins_expr ;` form. But the THREE `K_with`
productions (`illegal_bins`/`ignore_bins`/`bins` at parse.y ~4724-4742)
hardcode a bare `bins_name` (`IDENTIFIER`) as the operand before
`K_with`, not `cross_bins_expr` — so `with` only works after a plain
name, matching just the `cross_identifier` alternative of
`select_expression`, not the `binsof`/`&&`/`||`/paren alternatives the
LRM also allows before `with`.

**Why this isn't a small parse.y-only fix:** the pform-level struct
these productions populate (`class_type_t::pform_cross_t::cross_bin_t`,
`PClass.h` or wherever it's declared) has a `with_cross` field typed
as a bare `perm_string` (a cross/bins *name*), consumed downstream in
`elaborate.cc` (at minimum lines ~33715, 33802, 34476, 34704, 34725,
34734 as of this session) including a same-cross-name identity check
(`cb.with_cross == cross.label`, ~line 34706) that only makes sense
when the pre-`with` operand really is a name. Generalizing the grammar
to accept a full `cross_bins_expr` before `with` means either widening
`with_cross` to hold a full select-tree (like the existing `select`
field already does for the non-`with` bins forms) and updating every
elaboration consumer to handle both shapes, or adding a parallel field
— a real struct-and-multi-site change, not a grammar-only accept-and-
sorry patch. Given this session's own DD-039/DD-040 near-misses from
touching shared elaboration code under time pressure, this was
diagnosed precisely (LRM-confirmed root cause, both real reproducers
in hand) and then deliberately NOT attempted blind.

**Closure requirements:** generalize `cross_bin_t`'s `with_cross`
(or add an alternative field) to carry a full `cross_bins_expr` select
tree instead of a bare name; update parse.y's three `K_with`
productions to accept `cross_bins_expr K_with '(' expression ')' ';'`
in addition to (not instead of — `cross_identifier` remains a valid
LRM alternative) the existing `bins_name K_with (...)` form; update
every `elaborate.cc` consumer of `with_cross` to evaluate the select
tree against the candidate bin tuple instead of doing a name-equality
check, preserving the existing self-reference-only restriction ("Only
the cross_identifier of the enclosing cross may be used" per 19.6.1.2)
for the `cross_identifier` case specifically. A real regression test
needs runtime coverage verification (does the ignore_bins actually
suppress the correct tuples, not just parse), not a compile-only
check, per this session's own established discipline. Status:
recorded, not selected.

### DD-043 — Constraint `foreach`: no undotted selected-prefix form (`foreach (arr[fixed][loop])`), only plain and dotted-member forms exist (2026-09-17)

Found via the fresh OpenTitan census (Earlgrey-PROD-M6):
`hw/ip/adc_ctrl/dv/env/adc_ctrl_env_cfg.sv:118-122`:
```systemverilog
foreach (filter_cfg[channel]) {
  foreach (filter_cfg[channel][filter]) {
    soft filter_cfg[channel][filter] == FILTER_CFG_DEFAULTS[filter];
  }
}
```
`filter_cfg` is `rand int filter_cfg[NumAdcFilters][ADC_CTRL_NUM_CHANNELS]` — a plain 2D unpacked array, no class/struct member involved anywhere. The inner `foreach (filter_cfg[channel][filter])` hits a raw `syntax error`. This is the exact same construct class as DD-040 (a `foreach` selected-prefix, IEEE 1800-2017/2023 12.7.3: `channel` is already declared by the enclosing `foreach`, so it selects a fixed index rather than introducing a second loop variable) — but here inside a `constraint` block's iterative-constraint form (18.5.7.1) rather than an ordinary statement.

**Confirmed independently: slang (`--std 1800-2017`) accepts this exact reducer, 0 errors** (minimal standalone reproducer, no OpenTitan/UVM dependency):
```systemverilog
class C;
  rand int filter_cfg[3][4];
  int FILTER_CFG_DEFAULTS[4];
  constraint c1 {
    foreach (filter_cfg[channel]) {
      foreach (filter_cfg[channel][filter]) {
        filter_cfg[channel][filter] == FILTER_CFG_DEFAULTS[filter];
      }
    }
  }
endclass
module t;
  initial begin C c = new; void'(c.randomize()); end
endmodule
```
(`soft` and the nested-`foreach`-ness are both incidental: a single-level `foreach (arr[i]) { soft arr[i] == ...; }` already works fine today, confirming `soft` is not implicated; a 2D array with two *plain* foreach loop variables via the comma form, e.g. `foreach (filter_cfg[channel, filter])`, was not tried this pass but is expected to already work since it doesn't touch the selected-prefix grammar path at all.)

**Root cause:** `parse.y`'s `constraint_expression` nonterminal (IEEE 1800-2017/2023 18.5.7.1) has exactly two `K_foreach` alternatives: a plain single-bracket form (`K_foreach '(' IDENTIFIER '[' loop_variables ']' ')' constraint_set`) and a DOTTED selected-prefix form for a hierarchical/member target (`K_foreach '(' IDENTIFIER '[' loop_variables ']' '.' IDENTIFIER '[' loop_variables ']' ')' constraint_set`, already correctly implementing the "prefix_names select an already-declared value, not a fresh loop variable" semantics — the same ambiguity `parse.y` documents for the plain-statement foreach in ledger G65). There is no UNDOTTED sibling (`IDENTIFIER '[' loop_variables ']' '[' loop_variables ']'`, no `.member` in between) — exactly the gap DD-040 closed for ordinary statement `foreach`, but never added on the constraint side.

**Why this is not the same quick fix as DD-040:** on the statement side, `pform_make_foreach`/`PForeach::elaborate` provided a natural place to add the new grammar alternative and its guard. On the constraint side, `PEConstraintForeach` already has a distinct "hierarchical target" constructor and code path (`constraint_foreach_source_type_` in `elaborate.cc`, plus consumers at ~23974/27468/28856/30745) that assumes a real `.member_name` follows the prefix — after consuming `prefix_names().size()` array dimensions, it looks up `member_name` as a **class property or struct member** (`constraint_class_component_type_`/`record->member_index()`). An undotted selected-prefix (`arr[fixed][loop]`, plain array, no member) does not fit that shape: there is no member to look up, only "continue iterating the same array's own remaining dimension." Naively reusing the hierarchical constructor with `member_name == array_name` would make the elaborator try (and fail) a class/struct member lookup that was never supposed to happen. A correct fix needs either a third `PEConstraintForeach` shape (prefix-into-same-array, no member) or generalizing the hierarchical path to recognize "no member, self-referential continuation" as a distinct case, and updating every one of `constraint_foreach_source_type_`'s downstream consumers to handle it. Given this session's own DD-039/DD-040/DD-042 near-misses from touching shared, multi-site elaboration code under time pressure, this was diagnosed precisely (LRM/G65-pattern-confirmed root cause, minimal reproducer, slang-verified) and then deliberately not attempted blind.

**Closure requirements:** add the undotted grammar alternative to `constraint_expression` (mirroring DD-040's parse.y pattern, including the `pform_wire_visible_in_enclosing_scope`-style undeclared-selector guard — an undeclared identifier in the constraint-foreach selector position should be a real error here too, not silently accepted); extend `PEConstraintForeach` and `constraint_foreach_source_type_` (and its ~4 known consumers) to handle "prefix into the same array, no member" as its own case rather than misrouting through the class/struct member-lookup path. A real regression test needs actual constraint-solver output verification (does `randomize()` actually respect the fixed-selector semantics — a discriminating population, e.g. two different `channel` values producing correctly different constrained results — not just "does it parse"), per this session's own established discipline. Status: recorded, not selected.
