# OpenTitan gap ledger

One row per distinct defect found while making this fork run
[OpenTitan](https://github.com/lowRISC/opentitan) (measured against
`dsellerbrock/opentitan` @ `ef575385`, a clean unmodified upstream snapshot).

Narrative, toolchain recipe and per-IP measurements live in
[`opentitan_compat_2026-07-29.md`](opentitan_compat_2026-07-29.md). This file
is the flat list: what is wrong, why, whether it is fixed, and the smallest
input that shows it.

Every entry is an **IEEE 1800 conformance gap or a compiler defect**, not an
OpenTitan-specific accommodation. Several break ordinary RTL that has nothing
to do with OpenTitan; those are marked **[general]**.

## How to read the status column

| Status | Meaning |
|---|---|
| **fixed** | Landed with a regression test that checks behaviour, not just compilation |
| **partial** | Some shapes work, the rest refuse out loud; scope stated in the row |
| **open** | Diagnosed, not implemented |
| **⚠ silent** | Produces a WRONG ANSWER with no diagnostic — the worst class |

---

## G1 — `property_expr ::= ( property_expr )` — **fixed** (PR #135)

*A.2.10. [general]*

A fully parenthesized property was a syntax error. This is the shape every
argument-wrapping assertion macro emits, so **every** OpenTitan assertion was
unparseable, and the parser then lost module boundaries and cascaded bogus
"already declared" errors far from the cause.

```systemverilog
assert property (@(posedge clk) disable iff ((!rst_n) !== '0) (a |=> b));
```

Fix: add the production. Parens holding only a sequence keep the existing
path via the shift/reduce resolution on `)`.
Test: `sv_assert_paren_property.v`.

## G2 — a property may not start with `(` and continue as an expression — **fixed** (PR #135)

*A.2.10. [general] — this one breaks plain RTL.*

```systemverilog
assert property (@(posedge clk) (x == 1) && (y == 2));   // was a syntax error
assert property (@(posedge clk) (a) ? b : c);            // was a syntax error
```

Root cause is a **reduce/reduce tie-break resolved the wrong way**. In the
state reached after `(` plus an expression (state 3106 of the generated
parser):

```
sva_seq_atom   : expression .     (parenthesized SUB-SEQUENCE)
expr_mintypmax : expression .     (parenthesized EXPRESSION)
```

Bison breaks such ties by declaration order; `sva_seq_atom` was declared
first, so `(a)` always became a sub-sequence and no expression operator could
follow the `)`. A comment in `parse.y` asserted the opposite resolution — it
was wrong.

Fix: route the sequence's boolean leaf through a new `sva_bool_atom`
nonterminal declared *after* `expr_mintypmax`. Conflict counts unchanged
(497 s/r, 1162 r/r) — the resolution flipped, no new ambiguity.
Test: `sv_assert_paren_boolean.v`.

## G3 — conditional operator loses the enum type — **fixed** (PR #135)

*11.4.11 / 6.19.3. [general]*

`e = cond ? A : B` with both arms the same enum type was rejected whenever
the condition was 4-state. The result type is the common operand type; a
4-state condition is a *value* concern (bitwise blending), not a type
concern — and refusing the type bought nothing, because the cast the user was
forced to add produces exactly the same bits.

Backbone of OpenTitan's security hardening (`mubi4_bool_to_mubi`,
`lc_tx_bool_to_lc_tx`, FSM state updates in `prim_alert_sender` and
`tlul_adapter_reg`). Fix: drop the 2-state guard in
`NetETernary::enumeration()`. Genuine 6.19.3 violations still rejected.
Test: `sv_enum_ternary_type.v`.

## G4 — size cast of a string literal — **fixed** (PR #135)

*5.9.* `64'("GAL_XOR")` was rejected as a non-vector base. A string literal is
a packed byte array and behaves as an unsigned integer constant in integral
contexts. `prim_lfsr` selects its polynomial this way, so this blocked AES and
everything else instantiating an LFSR. A string-*typed* expression is still
correctly rejected — that is a dynamic type, not a vector.
Test: `sv_cast_size_string_literal.v`.

## G5 — compiler ABORT on a continuous assign to a packed-array struct member — **fixed** (PR #135)

*[general] — a crash, not a diagnostic.*

```systemverilog
assign hw2reg.key[3].d = ...;   // `key' is a packed ARRAY OF STRUCTS
```

```
ivl: elab_net.cc:695: NetNet* PEIdent::elaborate_lnet_common_(...):
     Assertion `use_path.empty()' failed.
```

The member walk stepped into `key`, found a packed array rather than a struct,
and asserted nothing followed — but `.d` did. The index was ignored entirely.
The **procedural** lvalue path already handled this shape; only the
continuous-assignment path aborted. Fix mirrors the procedural path, and
replaces the assertion with a diagnostic: malformed input must never abort the
compiler. This is the register-file interface shape every OpenTitan
comportable IP generates.
Test: `sv_lnet_parray_struct_member.v` (checks computed offsets).

## G6 — `for` with several typed declarations — **fixed** (PR #135)

*12.7.1. [general]*

```systemverilog
for (int i = 0, state_e t = t.first(); i < t.num(); i += 1, t = t.next())
```

Only one declaration was accepted (a comma-separated *step* list already
worked). Desugars into the synthetic block that already wraps a declaring
`for`, with initializers emitted **in source order** — which the standard
requires and which matters when a later clause reads what an earlier one set.
Unblocks `prim_sparse_fsm_flop`, hence assertion-enabled builds of any IP with
a sparse FSM.
Test: `sv_for_multi_var_decl.v`.

## G7 — unbounded consecutive repetition `[*m:$]` — **partial** (PR #135)

*16.9.2.* The goto (`[->m:$]`) and nonconsecutive (`[=m:$]`) forms had their
unbounded variants; the plain star form did not. `rep_tail = -1` now encodes
it and the automaton lowers it as a guarded **self-loop** on the join state
rather than a finite fan-out.

**Scope:** works in consequent and standalone positions. OpenTitan uses it in
an implication *antecedent* (`prim_alert_receiver`), which is blocked by
**G10**, so this fix alone does not unblock that file.
Test: `sv_assert_star_unbounded.v` (must match at one, two *and* three
occurrences, proving it loops).

## G8 — `s_eventually` as an implication consequent — **partial** (PR #135)

*A.2.10.* The consequent of an implication is a full `property_expr`, not
merely a sequence, but the grammar only had `sva_seq_expr |-> sva_seq_expr`.

```systemverilog
`ASSERT(TlulOOBAddrErr_A, oob_addr_err |-> s_eventually(d_valid && d_error))
```

This is what the **generated** CSR assertions emit for every comportable IP,
and its parse failure cascaded into `lc_ctrl_reg_pkg`, `prim_esc_*` and the
`uart_bind` targets.

`sva_property_t` models the consequent as a flat step chain with no
nested-property field, so rather than invent a half-designed one the two forms
get dedicated op types — 18 (`|->`) and 19 (`|=>`) — lowered beside the
`until` family whose pend-register machinery they reuse.

The lowering rests on a collapse worth stating: for every antecedent match the
consequent must hold at some cycle at or after it, and the obligation from the
**last** match is the strongest, since a `b` discharging it discharges every
earlier one. So one pending bit is *exact*, not an approximation. The forms
differ only in set/clear order within a cycle: `|->` clear-else-set (same-cycle
`b` discharges), `|=>` clear-then-set.

**Scope:** `s_eventually` only, with a boolean antecedent and boolean operand.
Sequence operands and `cover property` of this shape get a loud `sorry`.
`a |-> always b`, `a |-> nexttime b` and nested `a |-> (b |-> c)` remain
syntax errors — see **G12**.
Test: `sv_assert_impl_s_eventually.v` (six cases, including the two that must
*fail*).

## G9 — run-time index in a non-final packed dimension — **fixed** (PR #139)

*11.5.2 / 7.4.6. [general]*

Only the **last** index could be variable:

```systemverilog
logic [3:0][3:0][7:0] t;
t[1][j] = x;   // OK  -- constant prefix
t[i][1] = x;   // was: error
t[i][j] = x;   // was: error
```

`evaluate_index_prefix()` folds every index but the last into a single
**constant** slice offset. `collapse_array_exprs()` already built the fully
general offset — sum over dimensions of `normalize(index_k) * slice_width_k` —
it just was not reachable from the select paths. `collapse_packed_base()` now
wraps it; both select paths try the constant prefix quietly first and only
take the general path when it genuinely cannot.

This is the `aes_transpose` idiom in `aes_pkg`.
Test: `sv_packed_multidim_var_index.v` (checks values — a mis-scaled offset
would still elaborate but read the wrong element).

## G10 — variable-length implication antecedents — **open**

*16.9.2 / A.2.10. [general]*

**No** variable-length antecedent is supported:

```systemverilog
assert property (@(posedge clk) a ##[1:3] b   |=> c);   // sorry
assert property (@(posedge clk) a[*1:3] ##1 b |=> c);   // sorry
assert property (@(posedge clk) a ##[1:$] b   |=> c);   // sorry
assert property (@(posedge clk) a[*1:$] ##1 b |=> c);   // sorry
```

```
sorry: this assertion antecedent shape is not supported
       (fixed-delay sequence chains up to 128 cycles only)
```

`pform_make_assertion` builds the antecedent as an AND of per-step booleans
delayed through the `$past` history machinery, which models exactly one
attempt at a fixed offset. A variable-length antecedent means several attempts
in flight at once, each with its own obligation. The automaton engine can
express that; the assert-property lowering does not route antecedents through
it. **Architectural — wants a design pass.**

Blocks `prim_alert_receiver`, `prim_diff_decode`.

## G11 — sequence combinators as an implication operand — **open**

*A.2.10. [general]*

```systemverilog
assert property (@(posedge clk) (a or b)  |-> c);   // syntax error
assert property (@(posedge clk) (a and b) |-> c);   // syntax error
assert property (@(posedge clk) a |-> (b or c));    // syntax error
```

The combinator rules (`sva_or_has_op`, `sva_and_has_op`) yield an
`sva_property_t` carrying a combinator tree, while the implication productions
accept only `sva_seq_expr` on either side — so no production covers the
combination. The antecedent side additionally needs the automaton engine.

Currently the **first** diagnostic in the OpenTitan DV build
(`prim_alert_sender.sv:324`).

## G12 — the other property-expression consequents — **open**

*A.2.10.* `a |-> always b`, `a |-> nexttime b`, nested `a |-> (b |-> c)`.
G8 deliberately sidesteps the general case with dedicated op types; these need
the real nested-consequent field in `sva_property_t`.

## G13 — non-literal cycle-delay bounds — **open**

*16.9.2.* `##[SkewCycles+2:SkewCycles+3]` where the bounds are parameters
rather than literals:

```
sorry: sequence cycle delays must be literal constants
```

8 occurrences in the OpenTitan DV build.

## G14 — select on a multi-dimensional packed PARAMETER — **partial** (in progress)

*11.5.2.* Was an assertion failure that aborted the compiler:

```
netmisc.cc:2651: failed assertion packed_dims.size() == 1   (aes_prng_clearing.sv:143)
```

```systemverilog
typedef logic [63:0][5:0] perm_t;
parameter perm_t RndCnstSharePerm = ...;
assign data_o[1][i] = lfsr_state[RndCnstSharePerm[i]];
```

Verified pre-existing rather than assumed: none of those selects reach the G9
code (single index, or constant prefix). It became reachable because G9
cleared the errors that used to abort `aes` first.

**A wrong first attempt, recorded because the lesson generalises.** The
obvious fix is to report the flattened bit range. That *does* stop the crash —
and it is wrong: the caller then reads `Perm[i]` as a one-bit select instead
of a six-bit element and **silently returns the wrong value** (an identity
permutation produced `8'h77` where `8'ha5` was correct). It compiled clean and
the crash was gone; only checking the *value* caught it. Trading a crash for a
wrong answer is the worse bug.

The real fix, now implemented: `calculate_param_range()` optionally reports a
**slice width** — the element width, with msv/lsv then describing the
outermost dimension — and the parameter bit-select path selects a whole
element when that width exceeds 1, in both the constant-fold and run-time
paths. Callers that do not ask for a slice width still get the loud refusal
rather than a mis-widthed select.

## G15 — inline multi-dimensional packed parameter select — **⚠ silent**

*11.5.2. [general] — WRONG ANSWER, NO DIAGNOSTIC.*

```systemverilog
parameter logic [7:0][2:0] Perm = {3'd7,3'd6,3'd5,3'd4,3'd3,3'd2,3'd1,3'd0}; // identity
logic [7:0] lfsr = 8'hA5;
assign data_o[i] = lfsr[Perm[i]];     // yields 8'h77, should be 8'ha5
```

An **inline** multi-dimensional packed parameter declaration is flattened to a
single-dimension vector, so `Perm[i]` becomes a one-bit select of the 24-bit
value instead of a three-bit element select. The bit pattern is fully
explained by that: with the concatenation laid out as
`111 110 101 100 011 010 001 000`, bit `i` for `i = 0..7` is
`0,0,0,1,0,0,0,1`, and `lfsr[that]` gives `0x77`.

Distinct from G14: there the type *retains* its dimensions (the `typedef`
form) and the select could be fixed; here the dimensions are lost at
declaration, so the select path never learns there was an element structure.

Not introduced by any change here — single-index selects never reach the G9
code. **This is the highest-priority item in the ledger** despite blocking
nothing, because a wrong answer with no diagnostic is worse than any refusal.

## G16 — variable index into a struct-member packed array — **open**

*11.5.2.* 

```systemverilog
reg2hw.key[i].qe      // hmac.sv:819
digest[i]             // hmac.sv, kmac.sv
```

```
error: Array index expressions for member key must be constant here.
```

A different code path from G9 — the struct-member walk in `elab_expr.cc`
(~7415), `elab_lval.cc` (~2735) and `elab_net.cc` (~726), each of which
requires a constant index. The dominant blocker for `hmac` (81 errors).

## G17 — multiple-driver analysis on `otbn` — **open**

38 × "cannot have multiple drivers" plus 10 × "also continuously assigned" in
`otbn`. Not yet diagnosed; may be several distinct causes.

---

## Two measurement traps worth remembering

**The error count is not a progress metric while the parser can still give
up.** The DV build reported 24 errors — but its log ended in `I give up.`,
meaning the parser abandoned the file list at line 158 of 256 and everything
after was never parsed. Fixing that file took the count to 128, which is the
compiler getting *further*. The same happened to `aes` (2 → 7). Read the first
diagnostic and whether the parser survived, not the total.

**`-DSYNTHESIS` is not a valid way to probe the DV build past the assertion
gaps.** `hw/dv/sv/common_ifs/pins_if.sv` wraps its entire interface in
`` `ifndef SYNTHESIS ``, so the define deletes DV infrastructure rather than
just assertions — it produced 15 confident-looking phantom "compiler gaps"
(`Unknown interface type 'pins_if'`, `cfg.intr_vif.sample()` has no method)
that were pure artifacts of the workaround. `-DVERILATOR` is no better: it
strips the `dv_macros.svh` / `uvm_macros.svh` includes out of `clk_rst_if.sv`.
There is no safe stub define. The DV sources also need `+define+UVM`, which
OpenTitan's dvsim passes.
