# M9-NFA: automaton-based SVA engine — design (Phase 2)

Status: DESIGN + staging plan. Implementation lands behind the
`IVL_SVA_NFA` flag; the legacy linear engine remains the default until
the compatibility gate (below) is green.

## Why

The current engine (pform.cc `sva_*`) represents a sequence as a
LINEAR chain of steps (`sva_seq_step_t`: cycle-delay range + boolean)
and synthesizes a checker process per assertion. That model cannot
express, and today diagnoses as sorry (or supports only in special
cases):

- `or` of sequences with different lengths; general `and`
- `intersect` beyond equal fixed lengths; `within`; `first_match`
- goto `[->n]` / nonconsecutive `[=n]` repetition anywhere but the
  chain tail; unbounded `##[m:$]` mid-chain
- local sequence variables with per-attempt independence
- `.matched`/`.triggered` across clocks; strong/weak sequence
  semantics; multiclock concatenation

These are all regular-language features: the correct core is an
automaton. This is closure-plan big rock #1; the M9D backlog retires
on this arc.

## IR: sequence expression tree

New parse-side tree (replaces the linear chain as the source of
truth; the linear chain remains only as the legacy engine's input
until removal):

    sva_sexpr_t
      SATOM(PExpr* bool)                    // sampled boolean
      SDELAY(lo, hi, child)                 // ##[lo:hi] prefix; hi=-1 for $
      SCONCAT(a, b)                         // a ##0-adjacent b (delays live in SDELAY)
      SREP(child, lo, hi, kind)             // [*], [->], [=]; hi=-1 for $
      SOR(a, b) | SAND(a, b) | SINTERSECT(a, b)
      STHROUGHOUT(bool, seq) | SWITHIN(a, b)
      SFIRSTMATCH(child)
      SLVAR_DECL/SLVAR_ASSIGN               // stage B

The parser builds this tree in the assertion rules. Property layer
(`|->`, `|=>`, `not`, until-family, nexttime/eventually) stays above
the sequence tree, unchanged in shape.

## NFA construction (compile time, in pform)

Thompson-style construction with CYCLE edges: an edge is either
epsilon (same tick) or a tick edge guarded by a boolean expression
(advance one clock, guard sampled in the Preponed region like today's
engine). Constructions:

- SATOM(e): start --[tick: e]--> accept
- SDELAY(m,n): m guarded-true ticks then (n-m) optional ticks
  (epsilon bypass per optional); n=$ becomes a true-guarded loop
- SREP [*m:n]: m copies then optional copies; [*0] = epsilon; $ = loop
- goto/nonconsec: LRM 16.9.2 expansions on the automaton
  (b[->n] = (!b[*0:$] ##1 b)[*n]; [=n] adds a trailing !b[*0:$])
- SOR: shared start/accept epsilons; SAND/SINTERSECT: product
  construction (intersect ties lengths, and takes the later end)
- STHROUGHOUT: conjunction of the invariant onto every tick edge
- SFIRSTMATCH: accept cut — on first acceptance, kill sibling threads
  of the same attempt (slot-local prune)

Epsilon closure is folded at compile time: the synthesized transition
relation contains only tick edges between closure-normalized states.
State count is bounded by the (finite) expression size; `$` bounds
become loops, which LIFTS the current `##[m:$]`/`[*m:$]` mid-chain
sorries.

## Runtime model: per-attempt bitset pool, synthesized as SV

The engine stays a pform-synthesized checker process (same
infrastructure, VPI/assertion-callback integration, and
disable-iff/`$assertoff` plumbing as today) — no new vvp opcodes in
stages A-C. Per assertion:

- N states → each attempt tracked as an N-bit state set.
- An ATTEMPT starts every clock tick (concurrent assertion
  semantics). Attempts are per-slot: a pool of K slots (default 16,
  `IVL_SVA_NFA_SLOTS` to raise), each = {busy, state set, start
  tick, (stage B) local-var copies}.
- Per tick, per busy slot: next_set = OR over tick edges
  (state[i] && guard_e) → bit j. Empty next_set without acceptance =
  that attempt FAILS (report exactly like today's checkers, with the
  same SVA_CB_* callback hooks). Acceptance handling per property
  operator (plain assert: accept = pass; |->: antecedent accept
  spawns consequent obligation in the same slot; obligation
  acceptance = pass, emptiness = fail).
- Pool overflow (more than K concurrent attempts alive) is a LOUD
  runtime warning counting dropped attempts — never silent. (The
  common UVM/ivtest patterns keep attempt lifetimes short; K=16 is
  generous. The bitset-per-slot model is what preserves per-attempt
  reporting and, in stage B, per-attempt local variables — a single
  merged bitset cannot do either.)

## Staging (each stage: assertion suites green in BOTH modes before merge)

- **Stage A** (first increment): IR + NFA + slot-pool synthesis for
  booleans, `##N`/`##[m:n]`/`##[m:$]`, `[*n]`/`[*m:n]`/`[*m:$]`,
  `or`, `|->`, `|=>`, `not`, plain assert/cover, `disable iff`,
  single clock. Flag `IVL_SVA_NFA=1` (env, read at compile).
- **Stage B**: local variables (slot storage), `first_match`,
  `within`, `throughout`, general `intersect`, `and`.
- **Stage C**: `[->n]`/`[=n]` everywhere, `.matched`, strong/weak
  (end-of-sim: pending strong = fail, weak = pass; hooks into the
  existing final/EOS reporting).
- **Stage D**: multiclock concatenation and sampling alignment.
- **Flip**: when the dual-run gate is clean across the SVA tests in
  ivtest + the UVM sweep, NFA becomes default; legacy stays behind
  `IVL_SVA_LEGACY` for one release, then the linear path is deleted.

## Compatibility gate (the honesty mechanism)

A dual-run harness compiles every SVA test twice (flag off/on) and
diffs the complete verdict streams (pass/fail/cover messages and
callback counts, tick-exact). Divergences are failures of the gate —
either an NFA bug or a documented, justified fix of a legacy-engine
bug (each such case gets a note in this file; silent behavior change
is not allowed). The four standing gates run in legacy mode until the
flip, so the default toolchain never regresses mid-arc.

## Explicitly out of scope for this arc

- `expect` statement timing (needs M6-CALLF; Phase 3).
- Assertion threads observing data across clock domains beyond the
  stage-D sampling rules.
- Recorded corner: `cbAssertionStep` VPI callbacks per NFA step.
