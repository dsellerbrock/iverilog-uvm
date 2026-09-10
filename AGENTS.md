# Repository agent guide

## Mission

This fork exists to improve Icarus Verilog toward standards-correct
SystemVerilog and verification support.

Track these goals independently:

1. IEEE 1800-2017 implementation and qualification.
2. IEEE 1800-2023 implementation and qualification.
3. IEEE 1800.2 / UVM compatibility and qualification.
4. Application-level verification with real, unmodified DV workloads.
5. Formal-verification capability as a separate long-term program.

The objective is observable semantic correctness, not compilation
progress.

A construct is not implemented merely because it parses, compiles,
avoids a crash, or lets UVM terminate. Never manufacture apparent
success by ignoring requested behavior; substituting constants, empty
strings, null handles, or fabricated values; broadening selectors;
dropping constraints, coverage, assertions, callbacks, or checks;
weakening diagnostics; accepting arbitrary models where
probability/order semantics matter; or counting zero-traffic/no-check
runs as successful DV.

Warnings do not make incorrect semantics correct.

Minimize implementation complexity subject to complete required
semantics. Never minimize required semantics.

Use Slang and other simulators as differential evidence, not as the
specification. Prefer VCS/Questa/Xcelium compatibility when it agrees
with IEEE. Treat Verilator as a diagnostic cross-check, not the
SystemVerilog or DPI/VPI ABI oracle.

## Standards authority

For semantic questions use:

1. Applicable IEEE 1800 edition.
2. IEEE 1800.2 for UVM-standard behavior.
3. Pinned Accellera UVM as implementation/application evidence.
4. Independent simulators as differential evidence.
5. Existing Icarus behavior/comments as implementation evidence only.

Do not assume 2017 and 2023 wording or semantics are identical. Before
declaring a standards-semantic fix complete, identify the applicable
clause/subclause when reasonably possible. Never invent clause
references.

## Documentation authority

Documentation has four authority levels.

### Level 1 — Constitution

`docs/conformance/iverilog_ieee1800_uvm_manifesto.md` defines mission,
correctness policy, evidence rules, implementation philosophy,
qualification policy, blocker lifecycle, and Definition of Done. It is
not a backlog. Its own milestone/execution-order sections are retained
planning history; they do not by themselves authorize current
implementation (see Targeted-fix protocol below).

### Level 2 — Canonical conformance state

Current conformance matrices/registries
(`docs/conformance/matrices/ieee1800_2017_clause_matrix.md`,
`docs/conformance/ieee1800_2023_delta.md`, and similar) own current
standards status. Use:

- UNASSESSED
- UNSUPPORTED
- PARTIAL
- IMPLEMENTED
- QUALIFIED

IMPLEMENTED != QUALIFIED. Do not casually use FULL.

### Level 3 — Operational work

`docs/conformance/BLOCKERS.md` and `.ai/ACTIVE_WORK.yaml` define
operational work. The blocker registry is a backlog. Only
`.ai/ACTIVE_WORK.yaml` authorizes implementation during a targeted-fix
run.

### Level 4 — Historical evidence

Session logs (`docs/conformance/session_logs/`, see its `README.md`),
old handoffs, old census results, and old PR descriptions are
historical. NEXT, OPEN, TODO, and future work in them do not authorize
current implementation. Preserve history; correct canonical current
documents instead.

## Targeted-fix protocol

The unit of implementation is one blocker.

```text
SELECTED
  -> REPRODUCED
  -> SPEC_GROUNDED
  -> ROOT_CAUSED
  -> PATCHED
  -> FOCUSED_TESTED
  -> REGRESSION_TESTED
  -> DOCUMENTED
  -> DONE
  -> STOP
```

In an explicitly authorized continuous campaign, stop changing the completed
patch, return to coordinator selection, and activate the next concrete blocker
without another user message. Keep one implementation blocker active at a time.
Standalone one-ticket tasks stop after completion. Backlog selection and
implementation remain separate phases.

The coordinator may replace ACTIVE_WORK after closure or safe suspension with
preserved work and a recorded prerequisite. Unrelated discoveries remain
record-only during implementation. An empty ready queue calls for bounded
assessment of one unqualified requirement cluster, not campaign completion.
At an execution or authority boundary, preserve the active phase, last validated
revision, outstanding gates, next action, and exact next command in
`.ai/CAMPAIGN.yaml`. All correctness, toolchain, worktree, and permission
safeguards remain in force.

Before modifying implementation code establish:

```text
ACTIVE BLOCKER:
FAILING REPRODUCER:
EXPECTED SEMANTICS:
ROOT-CAUSE HYPOTHESIS:
ALLOWED IMPLEMENTATION SCOPE:
```

If the hypothesis changes materially, state the new one before
broadening implementation.

A crash is not automatically the root cause. A timeout is not
automatically a scheduler defect. Trace the first incorrect observable
behavior.

## Scope lock

`.ai/ACTIVE_WORK.yaml` is the only implementation objective. Do not
opportunistically fix neighboring gaps, warnings, refactors, APIs,
tests, or technical debt.

A source file may be modified only if its relationship to the active
work item can be explained in one sentence.

If a correct fix requires broader architecture, stop and record:
violated invariant, why the reproducer requires broader work, why a
local fix is incorrect, proposed scope expansion, and affected
tests/subsystems.

## ACTIVE_WORK contract

Read `.ai/ACTIVE_WORK.yaml` before implementation when present. It
should identify blocker ID, goal, standards/clauses, status, reproducer,
expected/current behavior, suspected symbols, allowed/forbidden scope,
dependencies, completion requirements, evidence, discovery policy, and
stop-after-completion.

If no implementation ticket is active, do not select one because a
historical document says it is next.

## Unrelated discoveries

Finding another defect does not authorize fixing it. Record it in
`docs/conformance/DISCOVERED_DEBT.md` with discovery ID, active
blocker, observation, file/function, possible clause, evidence,
reproducer status, and triage status.

Recording the discovery completes responsibility for it during the
current ticket. Return to the active work item.

## Ponytail / minimal implementation policy

Prefer:

1. existing mechanism;
2. existing helper/abstraction;
3. small extension;
4. local semantic correction;
5. new abstraction only when necessary.

"Minimum implementation" means the smallest change that provides the
complete semantics required by the active reproducer and standard.

It never means test/project/path/UVM special-casing, fabricated results,
ignored behavior, broadened selectors, or weakened
width/four-state/lifetime/scheduling/probability/alias semantics.
Ponytail is about implementation complexity, never about semantics.

## Graph-guided navigation

When Graphify or equivalent tooling is available, start from symbols
implicated by the reproducer. Determine parse -> elaboration ->
IR/netlist -> lowering -> runtime -> tests.

Expand one hop at a time from the active symbols. Prefer
extracted/static edges. Treat inferred edges as hypotheses requiring
source confirmation. Do not explore unrelated graph communities because
they look important.

Graph tooling is navigation, not semantic authority.

## Semantic-degradation prohibition

Pay special attention to compile-progress stubs, fallback values,
compatibility paths, approximations, and recovery behavior.

A run is not valid conformance evidence if requested semantics were
ignored, dropped, stubbed, broadened, fabricated, or approximated
outside a standards-permitted allowance. Semantic-degradation/fallback
success is prohibited as a way to declare a blocker closed.

When repairing such a path, prove requested behavior, not merely
disappearance of a warning. Never remove a warning while leaving the
semantic substitution intact.

## Defect classification

Distinguish parser, elaboration/type, lowering/codegen, runtime,
scheduler, DPI/VPI, robustness, harness/configuration, upstream-invalid
source, dependency/setup, explicit unsupported behavior, and
qualification gaps.

Source reducers are conformance tests. Keep them minimal.

A harness correction is not a compiler-semantic gain.

Changes to VVP instructions generally require synchronized updates to
opcode declarations, compiler parsing, target emission, runtime
execution, and malformed-bytecode validation where applicable. Search
with `rg`/`rg --files` before changing code and follow the existing
ownership boundaries between parser, elaboration, target lowering,
runtime, and VPI/DPI.

## Randomization invariants

Preserve deterministic RNG ownership/consumption, object/process
seeding, rand/randc semantics, alias/static identity,
activation/rand_mode, soft priority, solve-before, callbacks,
transactional value/history rollback, container/member lifecycle, and
edition-specific distribution semantics.

Satisfiability is not probability correctness. Use small mathematically
derivable domains and deterministic replay where probability matters.

Do not increase an enumeration cap as a substitute for missing
semantics. Never silently bias successful calls.

## Scheduler / SVA / clocking invariants

Preserve IEEE stratified event regions. Identify source, sampling,
evaluation, update, callback/report, and cancellation/reset regions for
relevant work.

Do not escape into Active/Reactive from Postponed-only actions. Do not
confuse "an operand changed" with "the watched expression changed."

SVA simulation support is not a hardware formal proof engine.

## Coverage correctness

Coverage tests must verify denominators and partial results, not only
100%. Exercise overlapping/disjoint bins, ignore/illegal/default
behavior, type vs instance coverage, crosses, dynamic selection, and
reporting where applicable.

Do not silently discard unsupported coverage and call the test
successful.

Functional coverage and code coverage are distinct. Report unavailable
code coverage honestly using the applicable standards-defined result.

## UVM qualification policy

Keep these evidence levels separate:

1. UVM parses/elaborates.
2. Focused UVM mechanisms execute.
3. Repository UVM regression passes.
4. Real DPI is exercised where required.
5. Complex unmodified DV environments compile.
6. They generate meaningful traffic/checking.
7. Outstanding work drains and they terminate normally.

Do not collapse these into "UVM works."

For traffic tests require appropriate evidence: intended nonzero
traffic, request/response activity, expected scoreboard checking, no
unexpected UVM errors/fatals, no unexplained outstanding work, and
intended normal completion.

The pinned Accellera library does not alone prove IEEE 1800.2
conformance. Report the actual generation mode used by
`.github/uvm_test.sh`; do not infer 2017/2023 qualification from another
mode.

## Formal-verification boundary

Track separately:

**Formal-language semantics** — assertions, assumptions, cover,
sequences/properties, sampled values, multiclock behavior, disable
behavior, checkers, and applicable normative assertion semantics.

**Hardware formal backend** — a future proof backend needs an explicit
supported profile, initial-state relation I(s0), transition relation
T(s,i,s'), property/assumption lowering, bounded checking, cover
reachability, an unbounded-safety strategy where claimed,
counterexamples, replay, and soundness qualification.

The constrained-random Z3 integration is not a hardware model
checker. Never silently feed semantic-degradation paths into a proof
model.

## Worktree and Git lifecycle

- Inspect `pwd`, `git status --short --branch`, upstream, and
  `git worktree list` before editing.
- Preserve unrelated changes. Never reset, clean, or overwrite them.
- After a PR merges, stop using its feature branch; fetch updated
  `origin/main` and start new implementation work from it.
- Retire linked worktrees only through
  `scripts/retire-agent-worktree.sh`, dry-run first.
- Never raw-`rm` a worktree or bypass cleanup refusal.
- Lock deliberate baseline worktrees.
- Stage explicit paths; avoid `git add -A` in mixed/generated trees.
- Do not commit build products, local installs, logs, cores, generated
  parser files, `.dSYM`, or temporary evidence unless policy
  explicitly makes them durable.

## Build environment

For a checkout from Git, run `sh autoconf.sh`, configure a
repository-local install prefix, then build and install.

The Apple Silicon configuration for this campaign is:

```sh
PATH="/opt/homebrew/opt/bison/bin:/opt/homebrew/bin:$PATH" \
CPPFLAGS="-I/opt/homebrew/opt/libffi/include -I/opt/homebrew/opt/z3/include" \
LDFLAGS="-L/opt/homebrew/opt/libffi/lib -L/opt/homebrew/opt/z3/lib" \
CFLAGS="-g0 -O2" CXXFLAGS="-g0 -O2" \
./configure --prefix="$PWD/local-install" --enable-libveriuser

make -j1 YACC=/opt/homebrew/opt/bison/bin/bison LEX=/usr/bin/flex
make install
```

Standing assumptions: native ARM64, `/opt/homebrew`, Bison 3.8.x,
Homebrew Z3/libffi, serial builds, no fixed compiler RSS ceiling, and
the user-authorized 300-second per-process CPU guard for sweeps.

Do not repeatedly rediscover architecture without evidence of mismatch.
Never reuse Rosetta-era install trees/environments. Start a replacement
build with `make distclean`.

Before a full JSON ivtest run:

```sh
make -C tgt-fpga install
```

The root `make install` does not install `fpga.conf`/`fpga.tgt`, and two
FPGA diagnostic tests otherwise fail before reaching their expected
errors.

After edits rebuild affected objects first. Before handoff run
`git diff --check`; use `make -q` where useful. For grammar changes
report Bison conflict counts/signature.

On non-Apple-Silicon environments (e.g. a fresh Linux container),
install the equivalent toolchain (`flex`, `gperf`, a Bison >= 3.x, Z3
dev headers/libs) and adapt the flags above to that platform; the
`--prefix`/`CFLAGS`/serial-build/300s-guard conventions still apply.

## Tool provenance

Always test the compiler/runtime from the active worktree. Do not trust
ambient `/usr/local`, Homebrew Icarus, or sibling installs. Sibling
Icarus install trees may be Rosetta-era x86_64 artifacts, and Homebrew's
arm64 Icarus is the wrong semantic revision even though its
architecture matches.

Make the `local-install` prefix absolute before invoking a harness that
changes directory: from the repository root, `PATH="local-install/bin:$PATH"`
becomes invalid after `.github/ivtest_gate.sh` enters `ivtest` and can
silently fall through to Homebrew Icarus; use
`PATH="$PWD/local-install/bin:$PATH"` instead.

From `ivtest` prefer:

```sh
PATH="$PWD/../local-install/bin:$PATH" perl ./vvp_reg.pl <list>
PATH="$PWD/../local-install/bin:$PATH" python3 ./vvp_reg.py <list>
```

Run legacy and JSON focus harnesses serially unless work directories are
isolated; both otherwise use `ivtest/log` and can delete one another's
evidence.

`perl ./vvp_reg.pl regress-synth.list` does **not** inject `-S`: the
Perl runner adds its synthesis flag only when invoked without an
explicit list. Use the no-argument full runner or put `-S` on every
targeted synthesis entry/command; otherwise negative synthesis tests
misleadingly report that no error occurred.

When a generated artifact's shebang may select a stale runtime, invoke
the current repository `vvp/vvp` explicitly. Record the exact
compiler/runtime path in failure reports when tool provenance could
affect the result.

Use `../evidence/arm64-tooling/resource-runner` for sweeps. Do not
reintroduce legacy memory caps.

For OpenTitan preserve the pinned FuseSoC/Python environment, logical
venv path, `--fusesoc-python`, fresh ARM64 build roots, and current
compiler/runtime provenance. On Apple Silicon create that environment
with native `/opt/homebrew/opt/python@3.13/bin/python3.13` (ambient
Homebrew `python3` may be outside OpenTitan's supported range). Invoke
OpenTitan generators through that same Python (e.g.
`"$TOOL_PY" util/regtool.py ...`), keep the venv first on `PATH` without
resolving its symlink, and write generated comparison output outside
the read-only OpenTitan checkout. Never reuse an OpenTitan FuseSoC build
root created on another host architecture.

Load DPI bundles with the active `vvp` runtime's `-d <bundle>` option;
`-M/-m` is for VPI modules and is wrong for DPI bundles such as
Caliptra's `jtagdpi.vpi` or OpenTitan's AES DPI bundle. Keep Caliptra's
`+timescale+1ns/1ps` command file and filtered full-TB manifest at
durable paths; do not rely on vanished `/tmp` historical paths.

## Test pyramid

Run the narrowest meaningful gate first:

1. Build affected objects and run the failing reducer.
2. Run focused positive, negative, boundary, and interaction cases.
3. Check exact diagnostics/output and independent polarity where
   useful.
4. Run focused legacy and JSON ivtest paths.
5. Run directly affected integrated ivtest/VPI/negative/UVM suites.
6. Run broad external `sv-tests` only after the feature cluster is
   clean.
7. Run whole OpenTitan/Caliptra/application campaigns at coherent
   checkpoints, not after every edit.

Preserve a permanent reducer for every semantic bug fix. A pre-fix red
proof is valuable when practical.

Do not call a partial feature complete while known semantics within the
claimed subset remain wrong.

For the real-DPI UVM regression, initialize `uvm-core` before the first
compiler build, then run `make installuvm` and use
`PATH="$PWD/local-install/bin:$PATH" bash .github/uvm_test.sh`. The
driver bakes the bundled UVM version into `driver/main.o`; initializing
the submodule only after that object was built leaves `iverilog -V`
reporting "not installed" even though `make installuvm` later installs
the sources and DPI module — rebuild and reinstall `driver` after
initialization in that case.

## Regression artifacts

Positive tests prove behavior, not merely compilation. Negative tests
pin focused diagnostics/counts.

For ivtest additions normally provide source, legacy gold, JSON config,
split-stream gold, focused-list registration, and main-manifest
registration as applicable.

Verify each new basename occurs exactly where intended. Keep focused
lists small enough to rerun during development. Exact-output gold files
may contain intentional whitespace; source files may not.

## Application evidence

Application censuses are evidence, not standards coverage percentages.

Record compiler/runtime fingerprints, corpus revisions, seeds, commands,
tops, provider mappings, dependencies, and per-row results where
relevant.

Compare individual rows, not only totals.

Do not call diagnostic line-count changes semantic improvements without
checking diagnostic identities/raw logs.

A completed census may contain failures; distinguish census completion
from application success.

## Documentation updates for a fix

Documentation is part of Definition of Done, but scope remains locked.

After closing the active work item update only documentation directly
changed by that work:

1. canonical conformance requirement/status;
2. blocker entry (`docs/conformance/BLOCKERS.md`);
3. focused evidence/session record;
4. `ieee1800_2023_delta.md` only if edition behavior changed;
5. manifesto only if project policy changed.

Do not use a semantic-fix ticket to clean unrelated stale documentation.
Record documentation debt separately.

Never rewrite old session logs to make historical results current.
Append clearly revision-scoped evidence when repository convention
requires it.

## Definition of Done

A semantic blocker is DONE only when:

- [ ] current HEAD/worktree provenance is known;
- [ ] reducer failed before the patch, when practical;
- [ ] expected behavior is standards-grounded;
- [ ] root cause is identified;
- [ ] implementation scope remained authorized;
- [ ] smallest semantically complete fix is implemented;
- [ ] reducer passes;
- [ ] permanent regression exists;
- [ ] focused neighboring tests pass;
- [ ] all applicable required integrated gates pass; pending required
      gates mean awaiting validation, not DONE, CLOSED, or QUALIFIED;
- [ ] no semantic fallback was introduced;
- [ ] documentation/blocker state is updated;
- [ ] unrelated discoveries were parked rather than fixed;
- [ ] claims do not exceed evidence.

Then stop changing this patch. In an authorized continuous campaign, return
to coordinator selection; otherwise STOP. Do not build dependent fixes on
an unvalidated semantic baseline.

## Commit and pull request

Commit at a coherent tested boundary. Push/open a draft PR when
authorized and ready.

During this user-authorized continuous campaign, periodically publish validated
work to GitHub: create or update a draft PR at each coherent locally validated
checkpoint, before proceeding indefinitely with more local-only increments.
Keep PRs reviewable; use cohesive batches or explicitly dependent stacked PRs.
At resume/checkpoint boundaries, inspect existing PRs and work through any
unpublished validated backlog. Record PR URLs, published semantic revisions,
stack dependencies and outstanding CI in `.ai/CAMPAIGN.yaml`. Reuse an existing
PR for the same scope. This authorizes publication, not merging, and does not
waive required validation, CI, worktree safeguards or merge permissions.

Follow `.github/pull_request_template.md`. Include:

- blocker ID;
- applicable IEEE clause;
- reducer;
- root cause;
- implementation scope;
- exact tests/commands/results;
- compatibility impact;
- known limitations;
- pending qualification;
- documentation changes.

Do not merge until required checks are green.

If CI reveals an unrelated latent defect, record/triage it rather than
automatically expanding the current PR. If it is a regression caused by
the active change, it remains in scope and must be fixed before
completion.

## Handoff format

Keep handoffs compact and executable:

```text
ACTIVE BLOCKER:
BRANCH / HEAD:
STATUS:
REPRODUCER:
ROOT CAUSE:
CHANGED FILES:
TESTS ACTUALLY RUN:
RESULTS:
PENDING GATES:
UNRELATED DISCOVERIES:
EXACT NEXT COMMAND:
```

Never report historical test counts as fresh results.

Never claim a gate was run when it was not.

Never substitute a plan, audit, or documentation-only update for a
requested implementation fix.
