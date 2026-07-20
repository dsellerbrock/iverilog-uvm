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

### Increment B.4: general `within` — LANDED

`within` (16.9.6) is now a two-way split at the grammar
(`pform_sva_seq_within`): both-fixed operands keep the legacy
`$past`-sampled combinational lowering (op 8, `pform_make_temporal_
assertion_`), identical under both engines; any non-fixed operand
builds a `SEQ_WITHIN` tree for the automaton engine, with the legacy
fixed-length sorry deferred to lowering when `IVL_SVA_NFA` is off.

Construction follows the LRM identity `s1 within s2 ==
(1[*0:$] ##1 s1 ##1 1[*0:$]) intersect s2`. `nfa_pad_` wraps s1's
folded automaton with a fresh true-self-loop PRE (enters s1 at any
tick) and a fresh accepting true-self-loop POST (entered once s1
accepts), then the padded automaton is intersected (product,
same-tick lockstep, joint accept) with s2 — tying s1's match to lie
inside s2's exact interval. The padded automaton is cyclic, but every
product tick advances s2, so for an acyclic s2 the product is acyclic
and the exact-K slot bound applies (no overflow); a cyclic s2 falls to
the capped pool. An s1 that cannot fit (e.g. longer than every s2
match) yields an unreachable product accept and the B.2
reachability guard makes it fall back to the deferred sorry rather
than an always-false checker.

Verified: `b within (x ##[1:2] y)` matches with b at the START,
MIDDLE, and END of the window and does NOT match when b is absent
(`within_nfa_only.sv`, cover=3 hand-computed); fixed-length within
holds verdict parity (`within_fixed.sv`, and the existing
`tests/m9c_within_test.sv` passes unchanged in both modes).

### Increment B.5: general `throughout` — LANDED

`throughout` (16.9.9) is now a two-way split at the grammar
(`pform_sva_seq_throughout`): a fixed-length sequence keeps the legacy
source-level lowering (`pform_sva_throughout` ANDs the invariant into
every step and expands `##N` gaps — exact and identical under both
engines); a variable-length sequence (`##[m:n]`/`##[m:$]`/`[*m:n]`),
which the legacy path diagnoses, builds a `SEQ_THROUGHOUT` tree for
the automaton engine, with the legacy sorry deferred to lowering when
`IVL_SVA_NFA` is off.

Construction: build seq's folded automaton and AND the invariant onto
EVERY tick edge — crucially including the pure-delay window ticks
(empty guard becomes the invariant alone), so the invariant is checked
at the variable wait cycles, which is exactly what the linear engine
could not do. This needed one supporting change to the synthesizer:
the guard capture now walks the built automaton's EDGES (collecting
each distinct guard pointer) instead of the source chains, so a
`throughout` invariant — which is not a chain step — and `##0`-fusion
conjuncts are captured uniformly. The refactor is verdict-neutral for
every existing shape (same guard set; dual-run gate unchanged).

Verified: `g throughout (x ##[1:2] y)` counts a window only when the
invariant held for its entire variable span, dropping the case where
`g` falls at a mid-window WAIT cycle (`throughout_nfa_only.sv`,
cover=2 hand-computed); fixed `throughout` holds verdict parity
(`throughout_fixed.sv`; `tests/m9c_throughout_test.sv` unchanged in
both modes). Dual-run gate 23/23.

## Stage B combinator operators: COMPLETE

Every regular-language sequence COMBINATOR from the stage-B list is now
lowered by the automaton engine, each with fixed-shape legacy parity
where one existed and a loud deferred sorry when the flag is off:

| Operator | Increment | Legacy (flag off) |
|---|---|---|
| `and` / `or` | B.1 | raw syntax error → now loud sorry |
| `intersect` (general) | B.2 | fixed = parity; else sorry |
| nesting / precedence | B.3 | (same, arbitrary trees) |
| `within` (general) | B.4 | fixed = parity; else sorry |
| `throughout` (general) | B.5 | fixed = parity; else sorry |

`first_match` is TRANSPARENT (the grammar returns the inner sequence)
and this is EXACT for standalone/existence positions: a cover/assert of
`first_match(seq)` counts once per attempt via slot-clear-on-accept,
which is precisely the first (shortest) match. Pinned by the parity
test `tests/sva_nfa/first_match.sv` (`first_match(a ##[1:3] b)` counts
identically to the bare window under both engines).

The COMPOSED cut — `first_match(seq) ##1 c` continuing ONLY the
shortest match of `seq` — is NOT modeled, and it is blocked on IR, not
on the synthesizer. The linear-chain IR dissolves `first_match` into
its inner steps (`first_match(a ##[1:2] b) ##1 c` lowers as the plain
chain `a ##[1:2] b ##1 c`), so there is nowhere to carry the cut. A
correct composed cut needs a `first_match` node that survives into
construction, i.e. the **sequence-expression tree IR** (the design's
`SATOM`/`SDELAY`/`SCONCAT`/`SREP` tree that replaces the linear chain as
the source of truth). Stage B was deliberately built as property-level
combinator trees OVER linear chains, which covers every whole-sequence
combinator (and/or/intersect/within/throughout) but not a sub-sequence
operator like a composed `first_match` or goto/nonconsec repetition
(stage C). Migrating the sequence IR is its own arc; until then
composed `first_match` stays transparent (a recorded corner).

### Per-attempt local variables — design (implementable; scoped as its own arc)

This is the remaining stage-B feature. The design below is concrete and
ready to implement; it is scoped as its own arc rather than folded into
a combinator increment because it touches the grammar (declarations +
assignment atoms), the IR, and — for the variable-delay case — the slot
data model, and a rushed version would risk exactly the silent-wrong
behaviour the project forbids.

**Two regimes, split by whether the assign→read delay is constant.**

*Fixed-delay (the common case) reduces to `$past`, exactly, in BOTH
engines — no per-slot storage.* In `(a, v = d) ##N (b && f(v))` the
sequence already pins the assignment exactly N cycles before the read,
so a read of `v` is exactly `$past(d, N)`, gated by the (already
required) match of `a` N cycles back. Lowering is a source transform:
carry the assignment `(step, v, rhs)` on the chain step; at lowering,
for each read of `v` at step j, compute the cycle distance `Δ` from
v's assigning step to step j (a constant when every intervening delay
is fixed) and substitute `v → $past(rhs, Δ)`. This rides the existing
`sva_rewrite_sampled_` history machinery and works in the legacy engine
too — local variables become engine-independent for fixed delays.

*Variable-delay needs per-slot storage.* When an intervening delay is a
window/`$`/range-rep, Δ is not constant per attempt, so `$past` cannot
express the read; each slot must carry its own `v_k` register, written
`v_k := rhs` on the assigning edge and read (per-slot) on the reading
edge. This is the one place a guard stops being slot-independent: a
guard that reads `v` must be cloned per slot with `v → v_k`, and the
global guard-capture must skip such guards. This is the genuinely novel
synthesizer work (per-slot data registers + per-slot guard eval) and is
NFA-only.

**Grammar (both regimes).** Local var declarations in `property`/
`sequence` blocks (`property p; logic [7:0] v; <spec>; endproperty`),
and the assignment atom `( expression , identifier = expression )` as a
`sva_seq_atom` with a match-item list. The comma inside the parens
distinguishes it from `( sva_seq_expr )`; the conflict impact must be
measured (as every combinator increment did) before landing.

**Staging.** (LV-1) grammar + IR + the fixed-delay `$past` transform
(engine-independent, exact, low-risk — the bulk of real usage); (LV-2)
per-slot registers for variable-delay reads (NFA-only, the novel part).
Each with hand-computed dual-run golds like the rest of stage B.

### Increment LV-1 — LANDED (fixed-delay local variables, both engines)

Grammar: the sequence-match assignment atom
`( expression , identifier = expression )` (zero grammar-conflict cost;
the name and rhs ride on `sva_seq_step_t::lv_name`/`lv_rhs`). No
declaration is needed — the read is a compile-time substitution, so the
local var never reaches elaboration. Lowering
(`sva_lower_local_vars_`, run after splice and before EITHER engine so
both benefit): require the chain be fixed-delay; compute each step's
cumulative cycle offset; for every step, substitute a read identifier
matching a local var assigned at an earlier step `i` with
`$past(rhs_i, offset[j]-offset[i])`. Variable-delay reads
(`##[m:n]`/`$`/range-rep between assign and read) are a LOUD sorry
(negative test `tests/negative/sva_local_var_window.sv`) — that is
LV-2's per-slot-register work.

Fixing this exposed and repaired a genuine pre-existing bug: the SVA
sampled-value history registers (`sva_rewrite_sampled_`) were 1-bit, so
ANY multi-bit `$past` (not just local-var capture) truncated to bit 0.
`$past` history is now 32-bit; the boolean sampled functions
(`$rose`/`$fell`/…) stay 1-bit. No regression (sva_funcs_test and the
dual-run gate unchanged).

Verified: `(a, v = d) ##2 (b && (c == v))` captures the 8-bit `d` and,
two cycles later, requires `c` to equal the CAPTURED value —
`tests/sva_nfa/local_var.sv`, cover=2 hand-computed (two value-matches,
one value-mismatch), verdict parity in both engines.

### Increment LV-2 — LANDED (variable-delay local variables, per-slot storage)

The design's "local variables (slot storage)": a local variable across
a VARIABLE-length delay (`##[m:n]`/`##[m:$]`/rep) cannot reduce to
`$past` (the read offset varies per attempt), so each slot gets its own
copy. NFA-only (the legacy engine cannot store per-attempt values;
`IVL_SVA_NFA` off is a loud sorry — negative test).

- `sva_lower_local_vars_` returns code 2 for a variable-delay chain and
  LEAVES the assignments on the steps; an implication with any local
  variable routes straight to the slot path (the antecedent-assign /
  consequent-read spans two chains that `try_assertion` reunites).
- `try_assertion` collects the assignments, identifies each variable's
  CAPTURE state (the destination of edges carrying the assigning gate),
  and allocates a 32-bit per-slot register `vk[k][li]` plus a shared
  once-per-tick rhs sample.
- Guards that READ a local variable are detected (`sva_expr_reads_lv_`)
  and, instead of a shared sample register, are cloned per slot with the
  name replaced by that slot's copy (correct in this engine because
  every guard is a blocking read at the same posedge).
- The capture fires when the assigning EDGE fires (the gate matched from
  the pre-advance state), NOT merely when the attempt sits in the assign
  state — a `##[m:$]` wait self-loop re-enters that state every tick and
  would otherwise clobber the stored value with stale data. This was the
  key bug; keying on the edge fixed it.
- Local-variable chains force the automaton's cyclic pool even for
  final-`##[m:$]` shapes the legacy engine would otherwise claim, since
  the legacy engine cannot carry the value.

Verified (`tests/sva_nfa/local_var_window_nfa_only.sv`, hand-computed):
a bounded window matching at offsets 1 and 3 with the captured value
(cover 2), an UNBOUNDED wait (cover 2), and the canonical
outstanding-transaction implication `(req, t = tag) |-> ##[1:$] (ack &&
(id == t))` (matches on the tick `ack` carries the matching id). Fixed
(LV-1), bounded, unbounded, plain, and implication all confirmed; the
one intersection that still falls back is unbounded IMPLICATION without
a local variable already being legacy-only — documented, loud.

With LV-1 + LV-2 the stage-B "local variables (slot storage)" item is
complete.

### first_match: exact standalone, exact composed (expansion), LOUD otherwise

`first_match` is transparent (its inner sequence flows into the chain).
This is EXACT for standalone/existence positions — a cover/assert of
`first_match(s)` matches iff `s` does, and slot-clear-on-accept already
counts the first (shortest) match once per attempt (this also makes
`first_match` over a local-variable sequence correct: the value is
captured at the assign and the attempt completes at the first match).
It is WRONG only when the wrapped sequence has MULTIPLE match lengths
AND its end feeds a continuation (`first_match(a ##[1:2] b) ##1 c`, or a
multi-length first_match antecedent of an implication): the cut would
change which match continues, and transparent lowering would silently
OVER-match.

The COMPOSED case is now LOWERED exactly (`sva_expand_first_match_`),
not sorried. The insight: the earliest-match cut of a single bounded
window `##[m:n]` is a disjoint union of fixed-length branches, where
branch `k` demands the awaited boolean is FALSE at every earlier window
offset `m..k-1` and TRUE at `k`:

    first_match(a ##[1:2] b) ##1 c
      = (a ##1  b ##1 c)                     // earliest = offset 1
        or
        (a ##1 !b ##1 b ##1 c)              // earliest = offset 2

The `!awaited` guards make the branches mutually exclusive, so exactly
the earliest match survives and the tail continues from it — precisely
first_match semantics, with no double-counting. The synthesizer builds
this as a `SEQ_OR` combinator tree and re-dispatches through the stage-B
tree path, so the automaton engine lowers it directly. Because the
result is a tree (automaton-only), the rewrite is attempted only when
`IVL_SVA_NFA=1`; the legacy engine still emits a loud sorry
(`sva_check_first_match_` gates the rewrite; negative test
`tests/negative/sva_first_match_composed.sv` pins the flag-off
rejection; gold test `tests/sva_nfa/first_match_composed_nfa_only.sv`
pins the flag-on count of 2 vs a transparent engine's wrong 3).

Shapes the expansion does not yet cover (local var inside the window,
range repetition, a second variable window, `##[m:$]` unbounded, or a
composed first_match antecedent of an implication) fall through to a
loud sorry rather than a silent miscompile — they want the general
sequence-expression-tree migration that stage C also needs.

## Stage B: HONESTLY COMPLETE

Every stage-B construct is now either lowered correctly or diagnosed
with a loud sorry — no silent miscompiles:

| Stage-B item | Status |
|---|---|
| `and` / `or` | lowered (B.1) |
| `intersect` (general) | lowered (B.2) |
| nesting / precedence | lowered (B.3) |
| `within` (general) | lowered (B.4) |
| `throughout` (general) | lowered (B.5) |
| local variables (slot storage) | lowered — fixed (LV-1, both engines), variable/unbounded (LV-2, per-slot) |
| `first_match` | exact standalone; composed single-window lowered by earliest-match OR-expansion; residual shapes are a loud sorry |

The residual first_match shapes still reduced to a loud sorry (local var
or repetition inside the window, multiple variable windows, `##[m:$]`
unbounded, composed antecedent of an implication) share the general
sequence-expression-tree IR migration with stage C (goto/nonconsec
repetition, `.matched`), so they are naturally that arc's opening items,
not stage-B gaps left silent.

## Stage C (in progress)

Stage C scope: `[->m:n]`/`[=m:n]` goto & nonconsecutive repetition,
`.matched`, and strong/weak end-of-sim semantics. Before this stage all
four were plain syntax errors (a loud rejection — no silent miscompile).

### Increment C.1: goto `[->m:n]` / nonconsecutive `[=m:n]` — LANDED

Goto and nonconsecutive repetition apply to a **boolean** operand
(16.9.2), so they need no sub-sequence IR: the count lives on the chain
step (`sva_seq_step_t::rep_kind` 1=goto / 2=nonconsec, `rep_lo`/`rep_hi`,
`rep_hi = -1` for `[->m:$]`), and `b[->2] ##1 c` composes as ordinary
chain steps. The lexer gains `[->` (`K_LBGOTO`) and `[=` (`K_LBEQ`)
openers (mirroring `[*`); `pform_sva_goto_repeat` records the counts on a
single boolean atom (a multi-step operand, a local-var step, or a nested
repetition is out of scope and marked `delay_lo=-3`, the existing loud
diagnostic).

The automaton fragment (`nfa_add_step_`) is a counting wait-loop. The
end-of-match rule is the whole point and is encoded structurally:

- **goto** `b[->m:n]`: each count level is SPLIT into a wait state
  `w[i-1]` and an arrival state `a[i]`. `w` self-loops on `!b` (waiting)
  and ticks to `a[i]` on `b` (advance); `a[i]` has NO self-loop and
  eps-exits for `i in [m,n]`, so acceptance fires exactly on the tick of
  the i-th `b` — the match ends ON the occurrence. `[->m:$]` adds a
  perpetual +1 loop from `a[m]`.
- **nonconsec** `b[=m:n]`: a single state per level with a trailing `!b`
  self-loop on the top state, eps-exit for `i in [m,n]` — the match may
  extend past the last `b`. `[=m:$]` also self-loops on `b`.

These self-loops make the automaton cyclic, so it routes to the slot
pool exactly like `##[m:$]`. Cover counts the shortest match once per
attempt (the established rule `a ##[1:n] b` and first_match already
follow; the dual-run gate enforces it). The legacy engine has no such
construct: `sva_nfa_legacy_supports_` rejects any `rep_kind` step, and a
`rep_kind` step reaching the legacy path (flag off, or the NFA engine
declined) is a loud sorry — never a silent drop.

Tests (automaton-only; legacy sorries): `goto_nonconsec_nfa_only.sv`
pins the goto-vs-nonconsec end-of-match discriminator (goto=0,
nonconsec=1 on a trace whose tail sits one cycle past the occurrence);
`goto_range_nfa_only.sv` pins ranged/unbounded/exact counts;
`tests/negative/sva_goto_nonconsec.sv` pins the flag-off rejection.

Still open in stage C: `.matched`, strong/weak.

---

Older note (kept for context): the one remaining stage-B item is
per-attempt local variables.

Sequence local variables (`int v; (a, v = d) ##1 (b == v)`, 16.10) are
the remaining stage-B feature and are deliberately NOT yet implemented,
because they break an assumption the whole slot pool rests on: today a
guard is a slot-INDEPENDENT sampled boolean, captured once globally and
referenced by every slot. A local variable is per-ATTEMPT — each slot
needs its own copy, written on the assigning edge and read (compared)
on a later edge — so the guard model must gain per-slot DATA registers,
not just per-slot state bits. Concretely it needs: (1) grammar for
`(expr, var = expr)` assignments and inline `var` declarations inside a
sequence; (2) IR carrying per-step assignments/reads; (3) a synthesizer
extension where each slot k holds `v_k` registers, an assigning edge
does `v_k := d` when it fires, and a reading edge's guard references
`v_k`. That is a self-contained arc of its own (call it B-LV), not a
bounded tail of B.5, and is scoped here rather than rushed. The
combinator surface above is what stage B set out to make the automaton
engine express, and it is complete.
