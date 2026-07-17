# Frontier Roadmap — 2026-07-17

A forward plan of the remaining IEEE 1800 / UVM conformance frontiers,
ordered by tractability and value. Grounded in the milestone truth audit
and the architectural findings recorded this session. Each item lists
**effort** (1 turn = one focused, self-validated increment like the ones
landed this session), **value**, and **dependencies**.

## Where we are

Closed on the current PR branch (follows merged PR #76): M14 clause
matrix; the truth audit; both *silent* miscompiles (M3-rm per-field
`rand_mode(0)`, M4-av string/real assoc reads); M6B scheduler inventory +
`$exit` + program-completion; and a large SVA + DPI + VPI advance —
M9B `intersect`, M9C `throughout`/`within`/`until` family, M9C-live
`nexttime`/`s_nexttime`/`s_eventually`, M9D parameterized
properties/sequences, M9E assertion control, M10 wide-vector DPI
marshaling, M12B assertion VPI enumeration.

No open *silent* miscompiles remain. Everything below is a completeness
gap (loud today) or an architectural investment.

---

## Tier 1 — Bounded increments, do next (≈1 turn each)

These reuse machinery that is fresh from this session and fit the
existing engines without rearchitecture.

1. **M12B-cb — assertion callbacks** (§40: cbAssertionStart /
   cbAssertionSuccess / cbAssertionFailure). Builds directly on the
   M12B `__vpiAssertion` identity just landed: the synthesized checkers
   already compute match/fail per cycle, so fire a VPI callback at those
   points against the assertion handle. *Value:* debug/coverage tools can
   observe assertion activity. *Dep:* M12B (done).

2. **M9F — bounded liveness/safety operators**: `nexttime[n]`,
   `s_nexttime[n]`, `eventually[m:n]`, `s_eventually[m:n]`, `always`,
   `always[m:n]`, `s_always[m:n]` (§16.12). Unlike the unbounded forms
   these are fixed windows — expressible on the existing pipeline the way
   `##[m:n]` already is. Needs the bracket-form grammar + a windowed
   lowering. *Value:* completes the temporal operator set. *Dep:* none.

3. **M9G — abort operators**: `accept_on` / `reject_on` /
   `sync_accept_on` / `sync_reject_on` (§16.12.15). `reject_on` is a
   `disable iff` variant (already implemented) and `accept_on` an early
   success; both are a sampled condition gating the existing checker.
   *Value:* reset-abort patterns in real checkers. *Dep:* none.

4. **M9H — property combinators**: `implies`, `iff`, `if (expr) p [else
   q]`, `case` property (§16.12). Boolean-combinator lowerings over the
   existing property machinery. *Value:* common structured properties.
   *Dep:* none.

## Tier 2 — Bounded, moderate (1–2 turns each)

5. **M12B-fr — VPI force/release on bit-selects + cbForce/cbRelease**
   (§36/38). The remaining half of the original M12B scope. Self-
   contained VPI work. *Dep:* none.

6. **M10B-md — multidimensional open arrays** (§35). Needs a
   non-contiguous access path: a 2-D unpacked dynamic array is a
   `vvp_darray_object` (array of inner darrays), so `svGetArrElemPtr2/3`
   must walk the structure (or copy into a canonical buffer). Niche but
   bounded. *Dep:* none.

7. **M5-if — virtual-interface corners**: bare module-scope
   `virtual <iface> v;`, generic `interface` ports, continuous-assign
   through a modport (currently an ICE). *Dep:* none.

8. **M13B — bind/timing tails**: bind to a specific instance path, bind
   target instance lists, `$nochange`/`$timeskew`/`$fullskew`,
   edge-descriptor event lists, `config`. *Dep:* none.

## Tier 3 — The SVA automaton engine (large; unlocks a cluster)

9. **M9-NFA — NFA-based sequence matcher.** The current engine lowers a
   sequence to a single flat linear token chain. That cannot host the
   features below, all of which need per-attempt state and true
   branching:
   - local sequence variables `(a, v = e) ##1 (b && f(v))`
   - goto / nonconsecutive repetition `b[->n]`, `b[=n]`
   - `.matched` / `.triggered`, strong/weak `strong(seq)`/`weak(seq)`
   - general nested sequence algebra and multiclock sequences

   This is the single highest-leverage SVA investment: one engine
   rearchitecture retires most of the M9D backlog. Multi-turn; stage it
   (thread model → local vars → repetition → strong/weak) behind the
   existing linear path so nothing regresses.

## Tier 4 — The synchronous-call rearchitecture (large; unlocks a cluster)

10. **M6-CALLF — scheduled-call / function-atomicity protocol**
    (§13.4.3, the `IVL_SCHED_CALLF` path, currently flagged off). The M6B
    ledger records this as the large blocked item. Landing it unlocks:
    - **DPI export** direction (C→SV execution), Tier 5
    - the **`expect`** procedural statement (blocks a process on a
      property), Tier 5
    - time-consuming DPI tasks
    - the cbNBASynch / post-NBA VPI callback region

    High risk; needs a careful staged rollout with the race litmus suite
    as the gate.

## Tier 5 — Depends on Tier 4

11. **M10-export — DPI export** (§35.9). Blocked twice over: an
    interpreter cannot synthesize a C-linkable symbol for a separately
    compiled `.so`'s `extern foo()` to bind against, and it needs
    Tier 4. Requires a trampoline/symbol-shim layer on top of M6-CALLF.

12. **M9-expect — `expect` statement** (§16.17). Procedural block on a
    property; rides on the property-wait machinery from Tier 4.

## Tier 6 — Foundational / diffuse

13. **M1B — semantic-IR remediation**: canonical type descriptor, typed
    lvalue + aggregate-layout interfaces, convert silent type-recovery
    fallbacks into tracked diagnostics, bypass-path inventory. Broad and
    cross-cutting; best done as a series of narrow, test-guarded
    conversions rather than a big-bang.

14. **M7 — UVM stress**: fuller register-model and objections coverage
    in the UVM harness.

---

## Recommended next-turn sequence

1. **M12B-cb** (assertion callbacks) — finishes the assertion VPI story
   while it is fresh; small and high-signal.
2. **M9F** (bounded liveness/safety) — completes the temporal operators;
   reuses the windowed-pipeline idiom.
3. **M9G + M9H** (abort operators + property combinators) — rounds out
   property-level SVA; both are gating/combinator lowerings.
4. **M12B-fr** (force/release VPI) — closes the rest of the M12B scope.
5. Then choose a **big rock**: **M9-NFA** (Tier 3) if the goal is to
   retire the SVA backlog, or **M6-CALLF** (Tier 4) if the goal is DPI
   export / `expect` / time-consuming DPI. M9-NFA is the recommended
   first big rock — lower risk than the scheduler rearchitecture and it
   unblocks more distinct features.
6. Interleave **M1B** conversions opportunistically whenever a nearby
   silent type-recovery fallback is touched.

## The two big rocks (strategic view)

- **M9-NFA** is the SVA endgame: a bounded, mostly-self-contained
  rearchitecture of one subsystem that retires local vars, goto/nonconsec
  repetition, `.matched`, and strong/weak sequences in one arc.
- **M6-CALLF** is the runtime endgame: the scheduler rearchitecture that
  the last hard interop features (DPI export, `expect`, time-consuming
  DPI, post-NBA VPI) all sit on. Higher risk; sequence it after the SVA
  engine so the assertion suite is complete before the scheduler churns.

Everything in Tiers 1–2 is deliverable one-per-turn with the same
regression gate used all session (UVM + bundled VPI + ivtest name-diff +
negative); Tiers 3–4 are multi-turn staged builds behind flags.
