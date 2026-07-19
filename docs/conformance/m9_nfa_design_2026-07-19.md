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


## Stage A synthesizer: implementation spec (from legacy-assembly recon)

Placement: `pform_sva_nfa_try_assertion` moves into pform.cc (it needs
the static helpers); pform_sva_nfa.cc exports only construction+dump
via a new pform_sva_nfa.h (`sva_nfa_t`, `pform_sva_nfa_build_from_chain`,
`pform_sva_nfa_dump`).

Reuse points in the legacy assembly (pform.cc pform_make_assertion,
after the NFA hook):
- Clock: explicit `prop->clk_evt`, else the `$ivl_default_clock`
  marker event built from the module's `default_clocking` (copy the
  block at "Clock: explicit, else the module's default clocking").
- Callbacks: `sva_report_stmt_(loc, inst, SVA_CB_SUCCESS/FAILURE)`;
  legacy folds SUCCESS into pass_stmt for kind!=2 && !negated — the
  NFA path must do the same fold itself (the hook sits BEFORE that
  fold). `inst` comes from `sva_gensym_counter++`.
- disable iff: outermost if(disable) -> clear all slot state, no
  reports (match legacy's guard placement).
- State storage: synthesized REAL variables via the tc_make_real_
  pattern (0.0/1.0, >0 tests) — proven decl plumbing, no new var
  machinery. One real per (slot k, state j): `_ivl_nfa<I>_k<k>_s<j>`,
  plus shared next-state temps `_ivl_nfa<I>_nx<j>` (slots advance
  sequentially in one always body, so temps are shared safely).

Per-tick body (single always @(clk)):
1. injection: first slot with busy_k==0 (busy = OR of its state
   reals) gets start-state bit := 1 BEFORE the advance loop, so the
   anchor tick is consumed this tick. No free slot -> loud overflow
   ($display warning + dropped counter; once-flag real).
2. advance per slot: nx_j = OR over edges(from->j) of
   (s_k_from>0 && clone(guard)); then
   - accept semantics by op:
     op 0 (plain): nx_accept -> pass'(=CB fold) once, clear slot;
       all-nx-zero && was-busy -> fail' (fail_stmt + FAILURE cb),
       clear slot; else copy nx into slot.
     op 3 (not): accept -> fail'; all-dead -> pass'.
     op 1/2 (|->/|=>): composite automaton (antecedent accept state
       epsilon-joined to consequent start; |=> adds one true tick),
       slot-sticky `obligated` real set when any CONSEQ-mask state
       becomes live; accept -> pass'; all-dead -> obligated ? fail'
       : (vacuous, silent). EXACTNESS GUARD: only return true when
       the antecedent has a unique match length (all fixed delays, no
       window/rep/unbounded in the antecedent) — one obligation per
       attempt, so slot-emptiness is per-obligation exact. Windowed
       antecedents stay legacy until stage B's obligation slots.
3. K (slot count): longest acyclic path when the automaton is loop
   free (exact, no overflow possible); else max(depth,8), cap 16,
   IVL_SVA_NFA_SLOTS override.

Dual-run harness (lands with the synthesizer): tests/sva_nfa/run.sh
compiles each listed test twice (flag off/on), runs both, diffs
stdout+stderr verdict streams exactly; any diff fails. Seed list: the
ivtest sva_* tests that use only stage-A shapes plus new
mid-chain-window/unbounded tests that ONLY the NFA path accepts
(legacy sorries -> those run flag-on only and check verdicts against
hand-computed traces).

Chain-only note: the legacy chain IR cannot express anything the
legacy engine does not already lower EXCEPT window/unbounded/rep in
non-final positions (legacy sorries there). Stage A's user-visible
win is exactly those mid-chain shapes; its architectural win is the
dual-run-proven engine that stages B-D build on (parser IR arrives
with stage B for or/and/intersect/first_match).

## Stage A synthesizer: LANDED (implementation notes + spec deviations)

The synthesizer is in pform.cc (`pform_sva_nfa_try_assertion`, directly
above `pform_make_assertion`); construction/analysis exports moved to
pform_sva_nfa.h. The dual-run gate is `tests/sva_nfa/run.sh`: every
test runs flag-off and flag-on with exact verdict-stream diffs, plus an
ENGAGEMENT check (the flag-on vvp must contain the slot state
registers, so a synthesizer that silently regresses to always-falling-
back fails the gate rather than passing vacuously); `*_nfa_only.sv`
tests (mid-chain window, mid-chain unbounded) require the legacy sorry
flag-off and hand-computed gold traces flag-on.

Synthesized slice: op 0 (plain assert/assume), op 3 (`not`,
loop-free), op 1/2 (`|->`/`|=>`) with fixed antecedents and
non-overlapped consequent starts. Guard mapping is by pointer
identity: each chain step's boolean is captured ONCE into a 1-bit
sample register (through `sva_rewrite_sampled_`, so `$rose`-family
history chains work unchanged) and automaton edges reference the
sample by the original expression pointer — no expression cloning at
all. Loop-free automata get K = longest-path slots (an attempt lives
at most that many ticks, so overflow is provably impossible; a loud
`$display` backstop remains against construction bugs). Cyclic
automata are synthesized only where legacy sorries (mid-chain
`##[m:$]`): capped pool (max(depth,8), cap 16, `IVL_SVA_NFA_SLOTS`
override), loud once-per-run overflow warning, and an
end-of-simulation pending note; final-step-unbounded chains stay
legacy, whose pend-collapse cannot overflow. Budget guard: N states x
K slots &gt; 1024 bits falls back.

Two DOCUMENTED deviations from the spec text above, both in favor of
dual-run parity (the gate outranks the spec prose):

1. op 3 all-dead is SILENT, not pass': the legacy engine never fires
   a pass action for `not` properties (it deletes pass_stmt), so
   firing pass' on all-dead would diverge the verdict streams.
2. State storage is the SVA engine's own 1-bit `sva_make_reg_`
   registers, not `tc_make_real_` reals — the same proven declaration
   plumbing the legacy checkers use, cheaper, and directly usable in
   logical expressions.

Also deferred within stage A (fall back to legacy, which handles all
of them exactly): overlapped `##0` consequent starts (need guard
fusion onto the antecedent's final tick edge — with the composite-
chain design this means conjunction guards, a small stage-B item),
`cover property` (match counting), and cyclic `not`.

### Increment A.2: ##0 fusion (conjunction guards) — LANDED

Edges now carry a guard CONJUNCTION (`std::vector<PExpr*> guards`;
empty = pure delay). A non-first `##0` step fuses: every tick edge
arriving in the previous exit's backward-eps closure is duplicated
with the step's boolean appended, targeting a fresh join; `##[0:n]` /
`##[0:$]` build the delayed arrivals as an ordinary `##[1:n]`/`##[1:$]`
fragment eps-joined with the fused arrival-0 state. The pre-fusion
arrival states keep their original edges (accept-reachability pruning
removes them when orphaned).

This lifts the overlapped-consequent deferral: `a |-> b` (the most
common SVA shape) and windowed overlap starts (`a |-> ##[0:2] b`) now
engage the NFA with verdict parity, and a NEW NFA-only capability
appears — overlapped implications with mid-chain windows
(`a |-> b ##[1:2] c ##1 d`), which legacy sorries on. Cyclic `not`
(mid-chain `##[m:$]` under negation) is also synthesized now: accept
fires the fail, all-dead and end-of-simulation pending are both
silent (the negated property held).

The obligation bit moved from a BFS region mask to an edge-exact
trigger: ob[k] is set the tick the attempt sits in the unique
pre-boundary state (BFS depth ante_edges-1; the fixed antecedent is a
linear path) AND the antecedent's final boolean sample fires —
regardless of whether the fused consequent edge also fires. This is
what makes overlap failures (`a && !b`) fail on the a-tick instead of
appearing vacuous, and it is exactly the legacy timing. Antecedents
with mid-chain `##0` (fusion inside the antecedent would make the
completion condition a conjunction) stay legacy.

Still deferred after A.2: `cover property` (match-counting parity
needs its own analysis), and `or`/`and`/`intersect`/`first_match`/
local variables (stage B parser IR).
