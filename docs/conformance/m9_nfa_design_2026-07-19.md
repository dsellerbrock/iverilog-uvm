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

### Increment A.3: cover + mid-##0 antecedents — LANDED (stage A complete)

`cover property` now synthesizes through the NFA (kind 2, non-negated;
`cover (not ...)` stays legacy for its sorry). Counting is
per-accepting-slot with first-match-per-attempt clearing — the same
totals as the legacy per-eligible-position adds (verified by putting
the COUNT itself into the dual-run verdict stream: both engines name
the counter identically, `_ivl_sva<inst>_cnt0`, so a test can display
it and parity proves count equality, not just silence). Cover slots
have no fail/pass machinery; the disable guard clears slots but never
the counter (legacy behavior). Cyclic covers where legacy is exact
(final `##[m:$]`, whose pend-collapse cannot overflow) stay legacy;
mid-chain-window covers are NFA-only capability with a gold test.

Cover PASS STATEMENTS: neither engine executes them (a legacy
recorded corner the NFA matches for parity). The legacy engine used
to drop them SILENTLY — that drop is now a loud shared warning
emitted before the engine split, so both engines behave identically
and the manifesto's no-silent-drop rule holds. Executing cover pass
statements per match is future work (both engines at once, to keep
the dual-run gate clean).

Mid-##0 ANTECEDENTS (`p ##0 q |=> r`) are synthesized now: the
exactness guard still requires fixed delays, and the obligation
trigger conjoins ALL booleans of the antecedent's trailing ##0-fused
run (the completion tick's full guard set) — arming on `p && q`, not
`q` alone, so a lone `q` stays vacuous. Found the hard way: an
earlier draft consulted only the final step's boolean; the dual-run
gate's ante_zero_delay seed pins the conjunction.

With A.3, every stage-A shape from the staging list is either
synthesized or intentionally-legacy with a loud path: stage A is
COMPLETE. Next: stage B (parser sequence-expression IR —
`or`/`and`/`intersect`/`first_match`, local variables, `within`,
`throughout` beyond the linear rewrite).

### Increment B.1: sequence `or` / `and` (combinator tree) — LANDED

The parser now accepts `seq or seq` and `seq and seq` (previously raw
SYNTAX ERRORS) via a minimal combinator tree over chains
(`sva_stree_t` in parse_misc.h: LEAF/SEQ_OR/SEQ_AND/SEQ_INTERSECT,
carried on `sva_property_t::tree`). Only the automaton engine lowers
trees; without `IVL_SVA_NFA=1` the assertion is a LOUD sorry naming
the flag. Construction (pform_sva_nfa.cc):

- `or` = union (fresh start/accept epsilons around both fragments).
- `and` = product with DONE-IDLING: each side is normalized to its
  own folded automaton, extended with an absorbing `done` state
  (accept --true--> done --true--> done); the product accepts at
  (accept,accept), (done,accept), (accept,done) — the match ends with
  the LATER side (16.9.5). Loop-free sides give a loop-free product
  after pruning ((done,done) cannot reach accept and dies), so the
  exact-K guarantee survives.
- `intersect` product (same-tick lockstep, accept only at
  (accept,accept)) is built in the construction; the grammar routes
  it in B.2 below.

Grammar cost: +7 reduce/reduce conflicts (1126 → 1133; shift/reduce
unchanged at 491; the useless-rule set is unchanged against a
baseline bison run). Gate evidence that nothing was stolen from the
other `or`/`and` uses (event lists, gate primitives): full ivtest
name-diff clean.

Stage-B.1 scope notes: trees ride op 0 only (`assert`/`assume`/
`cover` of a top-level or/and; `not(...)` and implication operands
containing trees do not parse into trees yet — the grammar builds
them at the property level only, non-nesting). Guard capture, slot
machinery, cover counting, cyclic pool/overflow, and EOS pending
notes are all shared with the chain path unchanged.

### Increment B.2: general `intersect` — LANDED

`intersect` is now a three-way split at the grammar
(`pform_sva_seq_intersect`):
- EQUAL-length fixed operands keep the proven legacy AND-chain
  lowering (a plain `p->seq`, so both engines lower it identically —
  dual-run parity, not an NFA-only path).
- UNEQUAL FIXED lengths keep the legacy "same length" parse-time
  sorry — they can never match over one interval, and BOTH engines
  diagnose rather than synthesize an always-false checker.
- Any NON-fixed shape (a windowed/repeated/unbounded operand) builds
  a `SEQ_INTERSECT` product tree for the automaton engine, with the
  legacy "fixed-length only" sorry text DEFERRED to lowering (carried
  on `sva_property_t::tree_sorry`) so that without `IVL_SVA_NFA=1` the
  exact legacy diagnostic still fires.

The product is the same-tick lockstep automaton (edge guards are the
conjunction of both sides' guards, accept only at the joint
accept state). A windowed operand whose length can never coincide
with the other side yields an automaton whose accept is UNREACHABLE
from the start; the synthesizer now checks accept-reachability up
front and, when the accept is dead, falls back so the deferred sorry
fires instead of an always-false checker (no silent always-false, no
crash). Verified: `(a ##1 b) intersect (c ##[1:2] d)` matches only
when the windowed side ends at length 2 (gold test); unequal-fixed
and never-coincident-window shapes both sorry under both engines.

This makes SEQ_INTERSECT (built but unreachable in B.1) live and
tested. Remaining stage B: recursive combinator NESTING (B.3, see
below), `first_match`, `within`, general `throughout`, and per-attempt
local variables.

### Increment B.3: recursive combinator nesting — LANDED

Arbitrary nesting of `or`/`and`/`intersect`: flat N-way (`a or b or c`),
mixed precedence (`a or b and c`, with `and`/`intersect` binding
tighter than `or` per 16.9-1), and parenthesized regrouping
(`(a or b) and c`). A first attempt was reverted for two real defects;
both are now fixed and the two fixes are what make nesting correct:

**Fix 1 — the epsilon fold (its own commit).** The original
`fold_epsilons_` eliminated epsilons by duplicating each edge's
PREDECESSORS forward, which orphaned any state with two outgoing
epsilons — the `or` fresh start with `eps` to each branch. Processing
the first branch's eps moved the start onto it and erased the other,
so `(a ##1 b) or (c ##1 d)` matched ONLY its first operand (a stimulus
firing only the second branch matched nothing). This was latent since
B.1; the NFA-only golds masked it because their stimulus started both
branches together. Replaced with textbook closure-based elimination
(epsilon-closure, lift each state's reachable tick moves, one fresh
accept sink with a parallel edge from every tick whose target
eps-reaches the old accept — so a window state that both accepts and
continues fires both on one tick). Regression:
`or_branches_nfa_only.sv` drives each branch alone.

**Fix 2 — the grammar (has-operator split).** The first attempt put
the operators at BOTH the `property_expr` level and the recursive
level, making `and`/`intersect` reduce/reduce-ambiguous; bison
resolved it so a plain top-level `seq and seq` became a SYNTAX ERROR
(a regression). The fix is a precedence layer where every nonterminal
REQUIRES at least one operator: `sva_comb_atom` (chain leaf or
`( sva_seq_comb )`), `sva_and_has_op` (folds `and`/`intersect`,
tighter), `sva_or_has_op` (folds `or`), and `sva_seq_comb` = either.
A bare chain reduces ONLY to `property_expr : sva_seq_expr` (op 0) and
never through the combinator layer, so there is no reduce/reduce with
the op-0 rule. Net grammar cost is ZERO versus B.2 (491 s/r, 1133 r/r
unchanged; no new useless-in-parser rules). Parenthesised nesting
works because the paren body disambiguates: `( sva_seq_comb )` fires
only when the body has an operator, else `( sva_seq_expr )`
(sva_seq_atom) keeps it a chain.

The C++ layer (`pform_sva_leaf_prop`, `pform_sva_tree_comb`,
`pform_sva_tree_intersect`) combines operand properties, each carrying
a tree (or a chain from the legacy fixed-intersect path). Top-level
`seq intersect seq` over two bare fixed chains still delegates to the
legacy 3-way split (equal-fixed parity / unequal-fixed sorry), so B.2
behaviour is unchanged; any nested or non-fixed shape builds a product
tree. Verified by `nesting_nfa_only.sv` with hand-computed counts that
discriminate branch, precedence, and regrouping (n1=3, n2=2, n3=1).

Remaining stage B: `first_match`, `within`, general `throughout`, and
per-attempt local variables.
