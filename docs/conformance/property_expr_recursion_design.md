# Recursive `property_expr`: ground truth and design

IEEE 1800-2017 A.2.10 defines `property_expr` **recursively**. This fork
models a property as a flat step chain plus a scalar `op_type`, so most
of that recursion is unreachable. This document records what is actually
there, what it costs, and the design that follows from it.

## What the LRM asks for vs. what exists

| A.2.10 alternative | status |
|---|---|
| `sequence_expr`, `strong/weak(sequence_expr)`, `( property_expr )` | supported |
| `not property_expr` | restricted to `not ( sequence_expr )` — `not (a \|-> b)` is a **syntax error** |
| `property_expr or/and property_expr` (property level) | **absent** — the `or`/`and` that work are the sequence-level operators of 16.9.5 |
| `sequence_expr \|-> property_expr` | **closed enumerated set** of consequents only: plain sequence, multiclock, `strong`/`weak(seq)`, `s_eventually(seq)`. `a \|-> always b`, `a \|-> nexttime b`, `a \|-> (c \|-> d)` are absent |
| `if/case` over `property_expr` | grammar recurses, semantics refuse: each branch must already be a plain boolean |
| `nexttime/s_nexttime/always/s_always/eventually/s_eventually` | encoded as `op_type` 9–13, **boolean operand only** |
| `property_expr until/s_until/until_with/s_until_with property_expr` | grammar takes `sequence_expr`; lowering further requires a single boolean step |
| `implies` / `iff` | grammar takes `sequence_expr`; folded to a boolean |
| `accept_on/reject_on/sync_*` | `op_type` 14–17, boolean operand only |

## The cost of the flat encoding

`sva_property_t` has no self-referential field. The one nested-consequent
shape the fork needed — `a |-> s_eventually(b)` — was given **two
dedicated `op_type` values (18, 19)** and a bespoke ~95-line lowering,
and even that requires bare booleans on *both* sides. Two of twenty
`op_type` slots buy exactly one of the LRM's many legal consequents;
every other form would need its own value, multiplied by interactions
with `strength`, `win_lo/hi` and `abort_cond`. The struct's own comment
says this is a workaround, not a template.

## Where the refusals actually live

Not in the lowering — **at construction time**, in four gatekeepers:

- `sva_take_bool_seq_`, `sva_take_bool_prop_` (`implies`/`iff`/`if`/`case`)
- the guard blocks in `pform_sva_unprop` (liveness) and `pform_sva_abort`

each emitting *"supported only with a boolean operand (no nested or
sequence property)"*. They reject before any lowering runs, so the
lowerings have never needed somewhere to put a recursive result — and
that is precisely why they cannot accept one.

## Why recursion does not belong in the automaton

The automaton engine matches the **regular** (sequence) layer:
concatenation, repetition, and the 16.9 combinators. Implication,
negation and liveness are already generated checker logic wrapped around
one flat automaton. Three reasons that boundary must stay:

1. **Negating a nested property needs complementation.** Every existing
   composition is a union (`SEQ_OR`, additive) or a product
   (`AND`/`INTERSECT`/`WITHIN`, multiplicative). Complementation requires
   subset-construction determinization — worst-case exponential, a
   qualitatively worse growth mode than the `N*K <= 1024` budget check
   guards against. Note the current check runs only *after* the whole
   tree is built; there is no budget check inside construction.
2. **`always`/`eventually`/`until` are unbounded obligations**, not
   bounded start→accept matches. They do not reduce to another
   `sva_stree_t::kind`.
3. **Nested implication needs stacked obligations.** Today that is one
   sticky bit `ob[k]` per attempt slot, which cannot express depth.

## The design

**Separate "compute a property's verdict" from "dispatch that verdict."**

Today every lowering — `pform_make_temporal_assertion_`, the legacy
fallback, the multiclock paths — builds one instance, one register set,
one process pair, and drives straight into `sva_fail_action_` /
`sva_pass_action_`. Nothing returns an intermediate result, so nothing
can nest.

The target shape:

```
lower_property_(prop) -> verdict { fail_now, pass_now, pending }
```

- **Leaves** stay as they are: a sequence is matched by the automaton
  (or the legacy pipeline) and yields a match signal.
- **Property nodes** compose their children's verdict signals with their
  own register logic — `not` inverts, `and`/`or` combine, `always`
  samples per cycle, `until` adds a sticky bit, implication arms an
  obligation.
- **The root** turns the final verdict into `fail_stmt`/`pass_stmt`/cover,
  exactly as the terminal code does today.

This is the standard layering (sequence layer = automaton, property
layer = temporal logic over match signals), and it is reachable from
here because the leaf machinery is already composable:
`sva_rewrite_sampled_` recurses over expressions, the clone family is
operand-agnostic, and `sva_make_reg_` / `sva_fail_action_` /
`sva_pass_action_` / `sva_register_stmt_` / `sva_report_stmt_` are all
instance-keyed and stateless. `sva_lower_endpoint_methods_tree_` is
already a recursive walker — over the sequence axis rather than the
property axis. `pform_make_multiclock_chain_assertion_` is an existing
precedent for composing N independently-lowered pieces into one checker.

## Blast radius

- **IR**: a nested child field on `sva_property_t`.
- **Clone paths (4)**: named instantiation, parameterized instantiation,
  `sva_instantiate_seq_`, `sva_clone_steps_subst_` — each enumerates
  fields *by name*, so a new field is invisible unless added explicitly.
- **Destroy paths**: `pform_sva_destroy_property` is recursive and fine,
  but there are ~15 **ad-hoc inline teardowns** that delete fields by
  hand instead of calling it. A nested field leaks at every one of them
  unless each is updated. This is the sharpest hazard in the change.
- **Grammar**: the non-recursive productions (`not`, `until` family,
  `implies`/`iff`, the closed consequent set) plus the four gatekeepers.
- **Lowerings**: `pform_make_temporal_assertion_`'s five groups, the
  legacy fallback's contract, and every `op_type` dispatch
  (`pform_sva_nfa_try_assertion` 0–3, multiclock 0–2, `pform_make_expect`
  0, `sva_prop_is_named_ref_` 0).

## Staging

1. **Loudness first (no refactor).** Accept the legal recursive forms in
   the grammar and emit a specific `sorry` naming the construct and its
   LRM clause, instead of a bare syntax error. A legal construct that
   dies in the parser with `syntax error` is the worst diagnostic in the
   set, and fixing it is independent of everything below.
2. **Verdict contract, behavior-neutral.** Introduce the verdict return
   type and migrate the existing lowerings onto it, with the full ladder
   proving nothing changed. No new forms accepted.
3. **Switch on nesting** operator group by operator group, cheapest
   first: `not`, then property-level `and`/`or`, then liveness over a
   nested operand, then nested implication (stacked obligations last —
   it is the hardest).
4. **Retire the `op_type` 18/19 workaround** once nested consequents
   work, folding it into the general path.

Wave 2 is a pure refactor with no user-visible win; the payoff lands in
wave 3. That ordering is deliberate — it puts the risky part on a
migrated, tested base rather than building it alongside a rewrite.
