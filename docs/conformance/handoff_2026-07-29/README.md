# Session handoff — Campaign 7 fix wave (2026-07-29)

The session was retired mid-wave. This directory preserves the three
in-flight fix agents' UNCOMMITTED, UNVALIDATED work-in-progress diffs.
**None of these patches passed validation — do not apply them blind.**
Each fix should be re-derived or the patch used as a starting sketch,
then taken through the full matrix (gate + VPI + negative + sva_nfa +
UVM + frontend scenarios) per the campaign discipline.

## State of the world at handoff

Everything merged through PR #137 (main at aa82a67): Campaigns 1-6
complete, the expected-failures ledger empty, and both Campaign 7
truth-pass RECORDS committed (roadmap notes + the 1800-2023 delta
survey). PR #138 (draft) carries the truth-pass-B record and was meant
to receive the fix wave below.

## Verified-but-unfixed defects (the fix wave's targets)

All were confirmed with minimized reproducers by the truth-pass agents
(reproducer probes were in /tmp scratchpad — regenerate from the
descriptions in the roadmap's two Campaign 7 truth-pass notes):

1. **Struct value-copy aliases container FIELDS** (falsifies M1B-2 /
   M4B-1 for that shape): `b = a` where the struct has a darray/queue/
   assoc member copies the container by REFERENCE
   (`property_object::copy`, vvp/class_type.cc ~:831 does a raw handle
   copy; the nested-struct sibling `property_cobject::copy` ~:901
   recurses correctly). Also breaks by-value args and push_back.
   F1's patch sketches a deep-copy; the class new-copy semantics
   question (7.5.2/7.9/7.10 vs 8.11) was being worked through.

2. **Static class-property container-of-struct member reads return
   garbage AND the checking comparison silently no-ops** — the
   compile-progress "expression dropped" warning path makes
   `if (b.pool[0].x != 3)` compile to a no-op. Route static props
   through the instance-property machinery; make any residual drop a
   HARD ERROR (the R28/R30 pattern). F2's patch is the start.

3. **String queue-of-queues loses element contents** (sizes right,
   strings read ""): `qq.push_back('{"a","b"}); qq[0][1]` → "".
   Against M4C-12's own claim text.

4. **`'{N{...}}` on a plain 1-D packed vector with multi-bit elements
   silently yields garbage** — 10.9.2 wants a count-mismatch error.

5. **G65 CONFIRMED**: UVM task-phase hooks execute twice per component
   (function-scope fork/join_none of exec_task in
   uvm_task_phase::execute — suspected unfixed sibling of the R27
   staging family). Plus a genuine vvp ICE: two threads racing `+=`
   on one variable assert in vvp_vector4_t::add (vvp_net.cc:1450).
   F3's patch is early diagnosis work.

6. **R25 companion path**: a ref formal bound to an UNNAMEABLE actual
   (array element / class property) whose task writes from a detached
   fork loses the write silently for int/real/class handles alike;
   warn_ref_formal_fork_hazard misses it (gates on declared type, not
   per-call-site companion fallback). Minimum bar: per-call-site
   warning.

7. Disclosed-loud residuals (roadmap notes): M4B-12/13/14 for
   class-property-held structs; M3B-6 constraints one property hop
   deep; `process::self().srandom()` not wired (18.13.3).

8. Truth-pass coverage gaps listed in the two roadmap notes (9 of 16
   M4C rows, M9/M10/M3B sub-rows, M13B) — highest-risk unprobed
   surface, given the ~20% falsification rate among probed rows.

## Recommended next-session order

Fix 1 and 2 first (silent-wrong, UVM-relevant), then 5 (G65 — needs
the staging-machinery diagnosis), then 6's warning, then 3/4. The
1800-2023 uplift plan is in ieee1800_2023_delta.md (start with array
map() and the $stacktrace string-function form).
