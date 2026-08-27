# 2026-08-27 — IEEE 1800 bind target-instance paths

## Scope and provenance

- Compiler base: `50edc6932fa880c73e217d827c1c96fd3c156747`
  (`origin/main`, including merged PR #241).
- Development branch:
  `agent/opentitan-next-after241-arm64-20260827`.
- Host/toolchain: native Apple Silicon; Homebrew Bison 3.8.x at
  `/opt/homebrew/opt/bison/bin/bison`; Apple flex at `/usr/bin/flex`.
- Every compiler, test, and application-corpus command ran through
  `evidence/arm64-tooling/resource-runner` with its 45-second CPU guard and no
  memory ceiling. The compiler and VVP came only from this worktree's
  `local-install/bin`.
- Normative audit: IEEE 1800-2017 and IEEE 1800-2023 23.11 and Syntax 23-9.
  Both editions define `bind_target_instance` as a hierarchical identifier
  with constant bit selections; this cluster has no edition delta.

This session implements a bounded part of 23.11. It does not claim complete
clause-23, OpenTitan, or IEEE 1800 conformance.

## Previous behavior

The parser flattened bind instance paths to text and rejected every selected
component. Parsed paths also had to begin with a module name, so a path such as
`u_sim_sram.u_sim_sram_if` inside its containing module could not resolve
relative to each elaborated containing-module instance. A legacy designwide
terminal-name search bypassed IEEE lexical lookup; it could activate a bind
from an unelaborated owner or attach to an unrelated same-named instance, and
could not model selected generate scopes, instance arrays, or relative
replication correctly.

A separately built ARM64 mainline comparator at
`ffa2b1f36a186a80076644ed8a5d312524529d7a` exits 4 for the positive reducer in
both `-g2017` and `-g2023`, rejecting its package-selected generate target and
selected module-instance-array target at parse time. Bind behavior is unchanged
between that comparator and this branch's `50edc6932` base.

## Implementation

1. `parse.y` preserves bind paths as `pform_name_t` components with their
   selection expressions instead of flattening them to strings. The grammar
   permits bit selects but not part-selects, as required by Syntax 23-9, and
   preserves an explicit `$root` prefix for forced absolute lookup.
2. Deferred pform resolution walks module/interface instances,
   one-dimensional module arrays, loop-generate scopes, and same-named
   conditional/case alternatives. Unqualified lookup starts in the nearest
   containing generate and then its module; a local instance wins the
   one-component ambiguity with a same-named module/interface type. The former
   global terminal-name search is removed.
3. Each elaborated module and generate scope retains the exact parsed
   definition that created or activated it. A contained directive is deferred
   until an occurrence of that declaration scope is elaborated, so inactive
   conditional/case arms, excluded roots, and uninstantiated owner modules
   cannot attach, report false misses, or load/diagnose a `-y` dependency.
   Alternatives are resolved per active owner occurrence, so same-named
   alternatives may have different concrete target types or scalar/array
   shapes.
4. Deferred owner and target discovery is a fixed-point operation. Pending
   directives are reconsidered when new owner occurrences or target definitions
   appear, independent of directive order. The same replay admits a target
   module definition, a container definition traversed by a target path, and
   compilation-unit bind directives appended by a source discovered through
   `-y` library loading. Automatic root discovery accounts for a library bind
   found during the initial compilation-unit closure. It deliberately does not
   rebuild the automatic-root set when a live contained directive discovers
   that library bind after root selection; use explicit `-s` to select the
   intended root for that closure.
5. Bind filters compare the complete structured root-to-target scope path,
   including declared instance/generate indices. Select expressions are
   elaborated separately in each declaration-scope occurrence, preserving
   genvar and parameter-specialization values. The same declaration scope is
   used for selected and explicit-root entries in
   `bind <type> : <target-instance-list>`.
6. Nonconstant, X/Z, host-range-overflow, scalar-selected, unselected array,
   and elaborated out-of-range forms all fail loudly. A final instance array,
   like an intermediate one, requires an element select. A post-worklist audit
   reports no match per active owner occurrence, including a module-type
   spelling that is not an elaborated root.
7. Bound instance names are reserved in the concrete target namespace. The
   same name is legal on disjoint targets; direct/direct, direct/list,
   multiple-owner, existing-definition, and same-base array-instance overlap
   on one target is an error. Target and directive-origin validations
   separately enforce the evidenced module/interface/checker/program/primitive
   rules, including a UDP type found only through `-y`. IEEE 23.11 allows only
   an interface or checker instantiation when the target is an interface. The
   internal M13 fixture was corrected from a module to an interface
   instantiation to obey that rule; this was a test-fixture correction, not a
   compiler compatibility regression.
8. Every directive resolves against the original hierarchy before any bound
   gate is inserted. Binding beneath an instance introduced by another bind is
   therefore rejected for direct and deferred owner/target creation in either
   source order.
9. The generate collector now visits a generate-for directly nested under a
   conditional/case alternative. Both loop-versus-scalar bind shapes compile
   and run, and a plain non-bind direct-nested generate smoke confirms that the
   traversal fix is not dependent on bind side effects.

## Permanent evidence

All new regressions are paired under `-g2017` and `-g2023`.

| Test family | Evidence |
|---|---|
| `sv_bind_indexed_relative_targets`, `sv_bind_self_instance`, `sv_bind_explicit_root_target_list` | Structured absolute, explicit `$root`, self-relative, module/generate-relative, selected loop-generate, and descending module-array targets; target-viewpoint actuals; local-instance/type-name ambiguity; explicit-root target lists. |
| `sv_bind_target_{dynamic_select,range_select,path_shape_fail,unselected_array_fail}` | Focused diagnostics for nonconstant, X/Z, host/range, scalar-selected, missing intermediate selection, and missing final-array selection. |
| `sv_bind_conditional_{duplicate_targets,different_types,array_shape_fail,generate_shape,generate_scalar_shape}` | The active same-named alternative is resolved per owner even when alternatives differ in target type or scalar/array and loop/scalar shape; only the active array occurrence requires a select. |
| `sv_bind_owner_{generate_lexical,inactive_generate,inactive_invalid,excluded_absolute,active_invalid_fail}` | Exact lexical owner identity; inactive/excluded occurrences do not attach or diagnose; active invalid owners do diagnose. |
| `sv_bind_owner_{loop_genvar_select,select_specialization_fail,scoped_target_list}` | Per-owner genvar/parameter evaluation and declaration-relative selected target-list entries. |
| `sv_bind_fixed_point_owner_overlap_fail`, `sv_bind_fixed_point_target_{first,reversed}_fail` | Deferred owner/target activation reaches a fixed point and reports the same overlap or bind-under-bind result independent of discovery/source order. |
| `sv_bind_same_name_{disjoint,target_overlap_fail,list_overlap_fail}`, `sv_bind_same_base_array_collision_fail` | Same introduced name on disjoint targets is legal; target/list overlap and array instances sharing one base name collide in a single target namespace. |
| `sv_bind_owner_{absolute_disjoint,absolute_overlap_fail,definition_collision_fail,duplicate_designwide_fail}` | Module-contained absolute paths are resolved per owner; disjoint targets remain legal while concrete overlap and pre-existing target declarations are errors. |
| `sv_bind_target_list_invalid_{first,last}_fail`, `sv_bind_target_list_scope_kind_fail` | Invalid target-list entry order does not change diagnostics, and the declaration before `:` must be a module/interface rather than a program/checker. |
| `sv_bind_{interface_checker,interface_inactive_alternative,interface_module_fail,interface_udp_fail,module_udp_fail}` | Active interface/module target kind controls legality; checker-into-interface works, while module-into-interface and UDP bound instantiations fail. Inactive interface alternatives do not poison an active module target. |
| `sv_bind_{checker_target_fail,program_instance_target_fail,origin_scope_fail,checker_root_selection}` | Checker/program targets and program/checker directive origins are rejected; an uninstantiated checker declaration is not promoted to a design root. |
| `sv_bind_{nested_direct_first_fail,nested_direct_reversed_fail,nested_deferred_fail}`, `sv_bind_owner_nested_{first,reversed}_fail` | Direct and deferred bind-under-bind is rejected consistently in every pinned ordering. |
| `sv_bind_library_{target,path,late_root}` | A target definition and a traversed container definition loaded through `-y` wake pending resolution. A loaded target source can append a compilation-unit bind; without `-s`, automatic root discovery still runs exactly one bound probe rather than promoting its bound module to a root. |
| `sv_bind_library_udp_kind_fail` | A UDP bound type that exists only in `-y` retains the focused Syntax 23-9 rejection even when its ordinary module target has no elaborated occurrence. |
| `sv_bind_owner_library_cu_closure` | A live contained bind can load a source whose compilation-unit bind joins the same activation closure. The test uses explicit `-s`, matching the policy that automatic roots are not rebuilt after this post-root discovery. |
| `sv_bind_owner_inactive_library` | An inactive contained bind neither loads nor diagnoses its deliberately malformed `-y` dependency; a live control bind still runs. Excluded owners follow the same activation rule. |
| Existing `sv_bind_target_instance` and `m13b_bind_instance_test` | Preserve standard containing-module lexical lookup and value-checked absolute target-instance-list behavior. |

The durable legacy and JSON/VVP focused lists each pass 110/110 on the final
native-ARM64 install. Full legacy passes 2063/2063 in 77.39 seconds, full
JSON/VVP passes 1141/1141 in 25.05 seconds, negatives pass 136/136, and VPI
passes 103/103 in 24.79 seconds. The real-DPI UVM umbrella passes 354/354 with
zero failures/skips. No new application-corpus result is claimed here. The two
focused harnesses must run serially: separate
`vvp_reg.pl` processes share `ivtest/work/test.txt`, so concurrent invocations
can overwrite one another's image and create a false `vsim: Unable to open
input file` failure. This is a harness concurrency property, not a compiler
result.

## Parser audit

Homebrew Bison reports 535 shift/reduce and 1119 reduce/reduce conflicts,
exactly matching the post-PR-#241 mainline. A canonical comparison of all 206
conflicting item cores, with generated midrule numbers normalized, reports
zero added and zero removed cores. Conflict totals alone are not sufficient in
this grammar because precedence can change an action without changing either
count.

## Pre-owner-hardening focused OpenTitan frontier replay

The retained post-#241 full file lists were replayed sequentially before the
owner/generate activation hardening and removal of the global terminal-name
fallback, never as two concurrent chip compiles. These results are historical
frontier evidence and have not been revalidated against the final semantics.
The common invocation was:

```zsh
set -o pipefail
"$RR" "$IVL" -g2012 -stb -uvm \
  -DUVM -DUVM_NO_DEPRECATED \
  -DUVM_REG_ADDR_WIDTH=32 -DUVM_REG_DATA_WIDTH=32 \
  -DUVM_REG_BYTENABLE_WIDTH=4 -DSIMULATION -DDUT_HIER=tb.dut \
  -o "$OUT" -c matrix-iverilog.scr 2>&1 |
  awk '/error:|sorry:|internal error:|Segmentation fault/' |
  tee "$LOG"
pipeline_rc=$pipestatus[1]
exit "$pipeline_rc"
```

The zsh-specific `$pipestatus[1]` preserves the compiler status; Bash's
`${PIPESTATUS[0]}` is not available in this shell.

| Target | Prior first stop | Historical bounded result |
|---|---|---|
| `lowrisc:dv:top_darjeeling_chip_sim:0.1` | Two relative-bind errors in `tb.sv:259,267`; exit 2 in about 2.0 s. | Former bind errors absent. The first new diagnostic is typed string concatenation in `chip_sw_sram_ctrl_scrambled_access_vseq.sv:53`; after many later independent diagnostics, the compiler exits 139 at 18.77 s and produces no `.vvp`. |
| `lowrisc:dv:top_earlgrey_chip_sim:0.1` | Selected `gen_flash_cores[1].u_core` plus relative-bind errors in `tb.sv:404,412`; exit 4 in about 2.2 s. | All former bind errors absent. The first new diagnostic is typed string concatenation in `chip_sw_flash_ctrl_lc_rw_en_vseq.sv:12`; after many later independent diagnostics, the compiler exits 139 at 18.68 s and produces no `.vvp`. |

Both first new failures reach the `ivl_type_t` default diagnostic in
`PEConcat::elaborate_expr` (`elab_expr.cc`). Filtered evidence is retained at:

- `evidence/opentitan-bind-targets-arm64-20260827/darjeeling-top-chip.filtered.log`
- `evidence/opentitan-bind-targets-arm64-20260827/earlgrey-top-chip.filtered.log`

The later compiler termination remains a separate defect. At that intermediate
checkpoint, disappearance of a diagnostic before termination demonstrated
frontier movement; it does not prove a successful chip compile, bound-checker
runtime semantics, or the post-hardening application result. The permanent
reducers provide the semantic evidence for the final bounded implementation.

## Explicit residuals

- Multidimensional module-instance arrays remain outside the compiler's
  existing one-dimensional instance-array representation.
- Automatic roots are not retroactively recomputed for a compilation-unit bind
  discovered only after a live contained bind loads a library. Use explicit
  `-s` for exact root selection in that case. Inactive/excluded owners never
  load or diagnose the dependency.
- Complete clause-23 closure still requires the exhaustive subclause and
  cross-context audit; the bounded 23.11 evidence above is not a claim about
  every clause-23 combination.
