---
name: UVM + IEEE-1800 systematic gap closure plan (Phases 64-73)
description: Sequenced multi-phase plan to close all gaps in /memory/uvm_ieee1800_gap_audit_2026_05.md. Each phase scoped to ship-able iverilog commit(s) + regression-clean (94/94) + memory update. Includes Phase 64 chunk-boundary root-cause as the first deliverable. Status section tracks per-phase progress; agent updates after each completion.
type: project
originSessionId: 3eb4c85e-78b0-4475-96cd-5139307107dc
---
# How this plan works

Each phase is a self-contained deliverable: pick the gap(s), root-cause via probe + source read, implement, run the canonical UVM regression (`PATH=...install/bin:$PATH bash .github/uvm_test.sh`), require **94/94 PASS**, commit with `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>`, update the **Status** section at the bottom of this file with commit SHA + a 2-line outcome.

Each phase has **scope**, **acceptance**, and **scheduling priority**. If a probe shows a gap is NOT ACTUALLY broken (e.g. fixed by overlapping work), mark the gap "RESOLVED-BY-PRIOR" in the audit file and skip.

If a phase exceeds 1 session: leave the in-progress work on a topic branch, document the partial state in **Status**, do NOT commit half-done changes to `development`. Resume next session.

If a phase reveals a deeper bug than scoped: STOP, document, and either (a) split the deeper bug into its own follow-up phase, or (b) escalate via memory note for the user to triage. Do NOT silently expand scope.

Audit reference: `docs/claude/uvm_ieee1800_gap_audit_2026_05.md` (gap IDs G01-G65).

## Branch-state convention (source of truth for "what's done")

Topic branches `claude/phase-NN` ARE the source of truth for cross-session state. The Status table at the bottom of this file is informational only; `development` never sees Status updates between phases (topic branches merge at the end). The agent infers global state by inspecting remote branches at session start.

**Done-marker convention.** When a phase is complete, the FINAL commit on `claude/phase-NN` MUST have a subject line starting with `Phase NN: COMPLETED` — e.g. `Phase 64: COMPLETED chunk-boundary root cause + restore chunk_size=1024`. The agent's session-start logic greps `git log -1 --format=%s origin/claude/phase-NN` for this marker.

**Session-start state inference** (the agent runs this at the top of every session):

```bash
git fetch origin --prune
NEXT_PHASE=""
RESUME=""
for NN in 64 65 66 67 68 69 70 71 72 73 74 75; do
  REF="refs/remotes/origin/claude/phase-$NN"
  if git rev-parse --verify --quiet "$REF" >/dev/null; then
    LAST_MSG=$(git log -1 --format=%s "$REF")
    if echo "$LAST_MSG" | grep -q "^Phase $NN: COMPLETED"; then
      continue   # done, skip
    else
      RESUME="$NN"   # branch exists, no done-marker → resume this
      break
    fi
  else
    NEXT_PHASE="$NN"   # no branch → next to start
    break
  fi
done

# Prefer resume over start
PHASE="${RESUME:-$NEXT_PHASE}"
[ -z "$PHASE" ] && { echo "All phases complete!"; exit 0; }
```

Then:
- If `RESUME` matched: `git checkout -B claude/phase-$PHASE origin/claude/phase-$PHASE`
- If `NEXT_PHASE` matched: `git checkout -b claude/phase-$PHASE` (off `origin/development`)

**Implementation work** lands as one or more commits with normal subject lines.

**Final commit** of a completed phase has subject `Phase NN: COMPLETED <one-line outcome>`. This is the marker that flips state. If you push without this marker, the next session will resume your branch (treats as in-progress).

**WIP exit (phase exceeds session)**: push your branch with the LAST commit subject like `Phase NN: WIP <what's left>` (anything that doesn't start with `Phase NN: COMPLETED`). Next session resumes.

**Status table at bottom of this file**: still updated on the topic branch (in the same commit as the done-marker, ideally) for human readability when you eventually merge to development. NOT the source of truth for the agent.

# Phase 64 — vvp chunk-boundary root cause + real fix

**Why first**: the current I2 fix (commit a93e3c8cc) bumps `code_chunk_size` from 1024 to 65536 as a *mitigation*. The underlying loader bug is unidentified and lurks for any function exceeding 65535 opcodes (rare today, but a time-bomb). A real fix lets us drop chunk_size back to 1024 (memory: ~32 KB/chunk vs 2 MB/chunk).

**Scope**:
1. Reproduce the bug at chunk_size=1024 with hand-edited .vvp insertion of `%noop` in any chunk-spanning function.
2. Bisect WHERE the bug fires:
   - Add `IVL_CODESPACE_TRACE` env-gated tracing in `codespace_allocate`/`codespace_next` to log every alloc + chunk transition.
   - Add `IVL_PC_TRACE_BOUNDARY` env-gated tracing in `vthread_run` step loop logging when `cp` lands at chunk pos 1022/1023 / next chunk pos 0.
   - Run `IVL_DEBUG_*=1 vvp /tmp/handedit_with_noop.vvp` and `... vvp /tmp/clean_baseline.vvp` and diff.
3. Hypotheses to test in order:
   - (a) Some path stores a `cp + N` pointer (raw arithmetic) and uses it later — would skip CHUNK_LINK if N crosses boundary.
   - (b) compile_codelabel's `codespace_next` peek may set a label at the wrong slot if `current_within_chunk == 1023`.
   - (c) of_CHUNK_LINK's `thr->pc = code->cptr` may be skipped by a parent-thread context staging path.
   - (d) Auto-frame allocation may walk forward in the bytecode looking for variable declarations and miss chunk transitions.
4. Implement the fix.
5. Restore `code_chunk_size = 1024`.
6. Verify hand-edited reproducer passes; verify 94/94 regression.

**Acceptance**: chunk_size=1024 + hand-edited .vvp with `%noop` in chunk-spanning function passes; 94/94 regression; commit message documents root cause.

**Diagnostic artifacts** (durable):
- `/tmp/audit_chunk/clean_baseline.vvp` — baseline VVP, no edits, passes
- `/tmp/audit_chunk/with_noop_emit.vvp` — `%noop` inserted into emit() body, hangs at chunk_size=1024
- `/tmp/audit_chunk/repro.sh` — script to rebuild and rerun

**Out of scope**: optimizing chunk allocation strategy, supporting >65k-opcode functions, removing CHUNK_LINK entirely.

---

# Phase 65 — Quick-wins (small surgical codegen/runtime fixes)

**Scope** (all < 50 lines each):
- **G19** `dist :/` weighted bins — parallel to C7's `:=` codepath in dist constraint codegen. ~30 lines.
- **G44** `unique case` quality — emit a flag in tgt-vvp/vvp_scope.c case translation. ~20 lines.
- **G45** `priority case` quality — same area; fix priority-encoder dispatch.
- **G38** `string.putc(idx, ch)` — runtime string mutation in vvp string method dispatcher. ~10 lines.
- **G39** `dyn = new[N](old)` — fix vvp_darray copy-init payload preservation.
- **G47** "unresolved vpi name lookup" — find the null-handle traversal in vpi name resolution; either guard or annotate.
- **G48** `callf child did not end synchronously` — investigate; add proper join-wait threading or suppress with a clearer cause string.
- **G49** spammy `get_object on unsupported property type` — add int/bit/enum cases in vvp_cobject get_object dispatcher.

**Acceptance**: each gap has a probe added to `tests/` directory exercising the behavior; 94/94 regression. Cosmetic warnings (G47/G48/G49) verified gone in regression log.

**Estimated effort**: 1-2 sessions.

---

# Phase 66 — Constraint solver gaps

**Scope**:
- **G11** `solve…before` + implication — Z3 conditional assertion.
- **G15** implication `->` constraint — same surface area; lift to Z3 implies.
- **G17** if-block constraint — needs nested constraint scope.
- **G16** `foreach(arr[i]) arr[i] inside {[i*10:...]}` — runtime expansion of foreach over actual array indices fed to Z3.
- **G18** `inside {ENUM_SET}` enum exclusions — propagate enum values to Z3.
- **G20** parent class constraint not applied to child rand fields — flatten constraint scopes across inheritance before solving.
- **G21** `arr.size() == sz` randomize for dynamic arrays — runtime resize hook.

**Acceptance**: probes p17, p24, p44, p45, p71, p82, p98 from `/tmp/audit_2026_05/` all pass; 94/94 regression; new tests in `tests/` for each gap.

**Estimated effort**: 2-3 sessions. Constraint backend is dense.

---

# Phase 67 — UVM core flows

**Scope**:
- **G22** `factory.create_object_by_name` and `uvm_factory::get().create_object_by_name` — wire singleton-returning function-result class-method dispatch.
- **G24** `uvm_config_db#(class_obj)::get` — fix class-handle round-trip through assoc-stored uvm_object.
- **G25** `uvm_field_sarray_int` (and `uvm_field_array_*`) clone/copy — fix do_copy/do_print for static-array field macros.
- **G23** `\`uvm_register_cb(T, my_cb)` macro — root-cause "netvector_t:bool" wrong type; likely macro expansion + class-property type elaboration.

**Acceptance**: probes p25, p28, p72, p95 pass; 94/94 regression; new tests added.

**Estimated effort**: 2-3 sessions.

---

# Phase 68 — SVA + property/sequence

**Scope**:
- **G05** `assert property` without explicit `@(posedge clk)` — synthesize a default clocking event or warn-and-skip cleanly.
- **G06** sequence operators `and`/`or`/`intersect`/`throughout`/`within` — synthesize each.
- Procedural concurrent assertion in always block (parse.y:2388,2433,2447 sorry).

**Acceptance**: probes p05, p60, p65 pass; new tests in `tests/sva_*` dir.

**Estimated effort**: 2-3 sessions; SVA is structural.

---

# Phase 69 — Streaming, packed/struct shapes

**Scope**:
- **G12** streaming LHS `{>>{a,b,c,d}} = src` — per-slice store mirror of Phase63b/C5.
- **G13** packed-struct `'{default: V}` — default propagation through struct members.
- **G14/G42** typed-default in assignment-pattern (`'{int: 0, default: 8'hFF}`) — parser + elab.
- **G56** array slice in continuous assigns — elab_net + elab_lval.

**Acceptance**: p23, p33, p53, p93 pass; 94/94 regression.

**Estimated effort**: 1-2 sessions.

---

# Phase 70 — Modport + interface arrays

**Scope**:
- **G26** modport task/function ports (`import do_write`).
- **G27** implicit modport selection at port bind (`producer p(a)` should pick mst).
- **G28** `bus_if b[4]();` interface array.
- **G29** `b.mst` modport-select bind syntax at instantiation.
- **G55** inout ports with unpacked dimensions.

**Acceptance**: p21, p43, p55, p99 pass; 94/94 regression.

**Estimated effort**: 1-2 sessions.

---

# Phase 71 — Process, event, method chaining, queue/array methods

**Scope**:
- **G07** process introspection (status updates, name() on handle).
- **G08** event triggered/wait race (both waiters wake).
- **G31** chained enum.method() on function-return.
- **G32** method-chain on class-handle returns (builder pattern).
- **G34** `event arr[N]`.
- **G35** `unpacked.reverse()`.
- **G36** unpacked-array `.min()`/`.max()`/`.sort()` (extend Phase63b queue methods).
- **G65** `pre_main_phase` body invoked twice — duplicate phase task call.

**Acceptance**: p08, p12, p32, p52, p58, p61, p84 pass; 94/94 regression.

**Estimated effort**: 2 sessions.

---

# Phase 72 — Parser sorry cleanup (where feasible)

**Scope** (each is a parser+elab patch):
- **G01/G02** `clocking` in module/program — convert assertion to error or implement.
- **G03** `let` declarations — lower to inline expression.
- **G04** `bind` instance binding — minimum: parse + best-effort elab.
- **G37** `assoc[string][]` foreach inner-loop var.
- **G46** `union tagged void Inv;` member syntax.
- **G50** `ifnone (negedge ...)` specify path.
- **G51** `->>` intra-assignment event control.
- **G52** declarative net delay `wire #5 a;`.
- **G54** `config name; design; endconfig`.
- **G59** `global clocking` syntax.

**Acceptance**: each parser sorry is either implemented (preferred) or downgraded to a `compile-progress` warn-and-skip with a clear note. New tests for each.

**Estimated effort**: 2 sessions; parser changes accumulate.

---

# Phase 73 — DPI open-array surface (svdpi.h)

**Scope**:
- **G30** `svdpi.h` — implement IEEE 1800-2017 §H.10:
  - `svOpenArrayHandle`, `svGetArrayPtr`, `svGetArrElemPtr1/2/3`
  - `svSize`, `svDimensions`, `svLow`, `svHigh`, `svIncrement`
  - Install header to `install/include/svdpi.h`.
  - Wire vvp runtime symbols to allow C linkage.
- DPI export decl test (G89 baseline) verified end-to-end with body.

**Acceptance**: probe p79 passes; new test exercises C-side iteration of an SV unpacked array.

**Estimated effort**: 1-2 sessions; surface is well-defined.

---

# Phase 74 — Performance + reliability hardening

**Scope** (post-functional cleanup):
- Run OpenTitan UART smoke vseq again with all Phase 64-73 fixes; profile via SIGUSR1 sampler.
- Identify next hot symbol (post Phase 61abcd, ~244 ns/s sim/wallclock); attempt a targeted fix.
- Audit deferred Source-grounded items in audit (elaborate.cc:584-738, elab_lval.cc:1269-1772, vvp/vpi_priv.cc:743-1029, vvp/vpi_darray.cc:137-225).

**Acceptance**: smoke runs measurably faster (≥2x) OR hot-path fix shipped.

**Estimated effort**: 1-2 sessions.

---

# Phase 75 — Compile-progress fallback hardening

**Scope** (the 45-site list in audit "Compile-progress fallback hot spots"):
- Audit each fallback site; either eliminate (real fix) or convert to clear file:line warning.
- Track per-site disposition in this file.

**Acceptance**: 45 sites triaged; ≥10 silent fallbacks converted to warnings or fixes; no silent miscompiles in canonical regression.

---

# Status

| Phase | Status | Commit / Notes |
|---|---|---|
| 64 chunk-boundary RC | not started | mitigation in a93e3c8cc; real fix pending |
| 65 quick-wins | not started | |
| 66 constraint solver | not started | |
| 67 UVM core flows | not started | |
| 68 SVA expansion | not started | |
| 69 streaming/structs | not started | |
| 70 modport/iface | not started | |
| 71 process/event/method-chain | not started | |
| 72 parser sorry cleanup | not started | |
| 73 DPI open-array | not started | |
| 74 perf hardening | not started | |
| 75 fallback hardening | not started | |

# Working notes (agent appends)

(Each agent run appends a dated entry: what was attempted, what passed/failed, what's deferred, next-step pointer. Newest at top.)

---
