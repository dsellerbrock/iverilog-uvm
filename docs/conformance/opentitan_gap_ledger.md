# OpenTitan gap ledger

One row per distinct defect found while making this fork run
[OpenTitan](https://github.com/lowRISC/opentitan) (measured against
`dsellerbrock/opentitan` @ `ef575385`, a clean unmodified upstream snapshot).

Narrative, toolchain recipe and per-IP measurements live in
[`opentitan_compat_2026-07-29.md`](opentitan_compat_2026-07-29.md). This file
is the flat list: what is wrong, why, whether it is fixed, and the smallest
input that shows it.

The current upstream campaign is driven by the reproducible synthesis/SVA/UVM/
runtime census in [`opentitan_matrix.md`](opentitan_matrix.md); its JSON output
keeps build/topology failures separate from compiler conformance defects.

Every entry is an **IEEE 1800 conformance gap or a compiler defect**, not an
OpenTitan-specific accommodation. Several break ordinary RTL that has nothing
to do with OpenTitan; those are marked **[general]**.

## Current upstream closure campaign

The newer upstream witness at OpenTitan revision
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19` is being measured independently
from the historical `ef575385` ledger below. The generated `adc_ctrl` simulation
graph now reaches VVP code generation with **zero hard errors**. That milestone
closed, among other items, class-handle dynamic-array assignment patterns and
selected interface-array scopes used by `$asserton`, `$assertoff` and
`$assertkill`.

It is not yet a clean UVM result: the log still contains explicit
compile-progress/degradation warnings for unresolved UVM specialization and
method calls, constraint loss, interface typing, covergroup members, queue/ref
semantics, assertion binding and NBA scheduling. Each is a ledger item to fix or
turn into a strict error; none may be ignored for the final zero-debt gate. The
canonical post-corpus plan is M14B in [`ROADMAP.md`](ROADMAP.md).

The first durable matrix inventory at this revision contains 267 RTL candidates,
109 standalone SVA/formal jobs and 80 UVM simulation jobs (plus the same 80 as
runtime jobs). Package/fileset providers with no standalone top are recorded as
dependency-covered rather than false failures. The ADC-control witness
currently reports RTL `DEBT`, SVA
`FAIL`, and UVM `DEBT`; details and exact pass criteria are recorded in
[`opentitan_matrix.md`](opentitan_matrix.md). The SVA hard error is currently a
corpus topology mismatch: the formal target elaborates `adc_ctrl` while its SVA
source directly names `tb.dut`. It is not being counted as an IEEE compiler gap
unless an equivalent standard-valid, self-contained reproducer demonstrates
one.

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

## G14 — select on a multi-dimensional packed PARAMETER — **fixed** (recovery campaign 1, 2026-07-29)

Closed together with G15 by routing every multi-dim or multi-index
parameter select through one canonical stride calculation
(`param_select_packed_`, elab_expr.cc). Verified by value:
`sv_param_multidim_packed_select` covers constant/variable indices in
any dimension, part and indexed-part selects (element-range semantics),
ascending dims, 3-D, package/class scopes, instance overrides, and the
array query functions; `sv_param_unpacked_array_select` covers unpacked
array parameters (descending/non-zero-based bounds, variable index,
element-applied trailing selects). The original text follows.

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

## G15 — inline multi-dimensional packed parameter select — **fixed** (recovery campaign 1, 2026-07-29)

The declaration-time flattening in `pform_set_parameter` is removed:
an inline multi-dim packed parameter now keeps its dimensions and
elaborates identically to the typedef'd form, taking the same fixed
select path as G14. The identity-permutation reproducer reads `8'ha5`.
The original text follows.

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

## G18 — run-time selected packed l-value in synthesis — **fixed** (current upstream campaign)

*11.5.1 / 11.5.2. [general] — compiler abort and unsupported legal RTL.*

```systemverilog
always_comb begin
  class_masks = '0;
  for (int unsigned k = 0; k < N_ALERTS; k++)
    class_masks[alert_class[k]][k] = 1'b1;
end
```

Synthesis tried to constant-fold the whole flattened l-value base because `k`
was an unrolled loop index, even though another packed dimension still depended
on the run-time value `alert_class[k]`. Constant-function evaluation reported
an error and then aborted in `NetESelect::evaluate_function`. This blocked both
Darjeeling and Earl Grey alert-handler synthesis.

The synthesis path now distinguishes expressions foldable in the loop context
from genuinely dynamic bases. Dynamic writes use a case-equality decoder and
bit-level mux network, preserving the required no-write behavior for X/Z and
out-of-range indices, including partially overlapping signed and unsigned
indexed part selects. The regression checks values after synthesis, not merely
successful compilation: `ivtest/ivltests/synth_variable_packed_lvalue.v`.

The exact Darjeeling alert-handler target now returns zero with no hard error;
its remaining matrix status is `DEBT` solely because of the separately tracked
conservative `always_*` sensitivity warning.

## G19 — constant-only `always_comb` misclassified as synchronous — **fixed** (current upstream campaign)

*9.2.2.2.2 / synthesis contextualization [general] — compiler abort.*

```systemverilog
always_comb begin
  attr = '0;
  attr.mode = 3'b101;
  attr.enable = 1'b1;
end
```

Elaboration correctly creates an empty implicit event wait and reports that
the process has no sensitivities. Synthesis previously treated an empty event
list as proof that the process was synchronous, then entered the clocked
process path and asserted that exactly one event existed. OpenTitan's
`prim_pad_attr` triggered this abort while synthesizing pinmux.

An empty event wait is now classified as combinational. The regression checks
the packed-struct value after both ordinary and synthesized compilation. The
exact Darjeeling pinmux target now exits zero with no hard errors; its two
remaining debts are the explicit no-sensitivities warning and the separately
tracked conservative `always_*` sensitivity warning.

## G20 — contextually constant unpacked-array word in synthesis — **fixed** (current upstream campaign)

*7.4 / 12.7.1 / synthesis contextualization [general] — unsupported legal RTL.*

```systemverilog
always_comb begin
  for (int i = 0; i < NumPolicies; i++)
    combined_racl_error[i] = policy_error[i] | range_error[i];
end
```

The l-value word expression is syntactically variable, but `i` is a constant in
each unrolled synthesis iteration. The output-discovery pass returned no output
for such a word and the assignment pass rejected it as a run-time memory write.
That conflated two different cases: an unrolled array word, which must lower to
one ordinary vector assignment per iteration, and a true run-time RAM address,
which still requires RAM-write lowering.

Default synthesis output discovery now exposes every possible unpacked word,
and the assignment pass evaluates the word with the loop's constant context and
selects the exact word nexus. The always_comb sensitivity-pruning walk remains
conservative so it does not remove words that are only read. Part-select stores
first size the replacement to the selected width and preserve the untouched
bits through `NetSubstitute`; this closed a wrong synthesized value found by the
new value-checking regression.

`ivtest/ivltests/synth_contextual_array_word.v` checks whole-word writes,
part-select writes, fields of an unpacked array of packed structs, and a
contextually constant packed select that lies completely outside the target in
both ordinary and `-S` execution. The out-of-range case is a no-op; previously
its negative base was still written into the synthesis bit mask and could
segfault the compiler. The exact Darjeeling RACL target no longer reports any
variable-memory-word diagnostic. After G23 and G24, the same pinned target is a
zero-error, zero-debt `PASS` in 0.334 seconds on the final tested compiler.

True run-time RAM writes such as `mem[addr_i] <= wdata` remain loud unsupported
synthesis debt and are not claimed by this fix.

## G21 — legacy synthesis fallback aborted on rejected `always_*` — **fixed** (current upstream campaign)

*[general] — compiler robustness, not feature completion.*

When synth2 rejected an `always_comb`, `always_ff` or `always_latch` process,
the unchanged process fell through to the legacy `syn-rules` matcher. That
matcher asserted that modern process kinds should never reach it, converting a
useful unsupported-feature diagnostic into exit 134 or a segfault cascade.

The legacy pass now emits a normal `sorry`, increments the compiler error count
and skips the process. `synth_modern_process_reject.v` verifies that a partial
asynchronous reset is rejected with an ordinary nonzero exit rather than a
signal. This does not implement partial resets or bit-level latch enables; it
makes their current boundary deterministic and non-crashing.

## G22 — Ibex synthesis lowering exceeds its declared resource bound — **fixed** (current upstream campaign)

*[general] — bounded-termination/performance defect, not a cybersecurity finding.*

The first whole-RTL checkpoint left four Ibex compiler engines running after
their 1800-second drivers timed out. Process-session cleanup now proves that a
timeout cannot leak those descendants, and the compile bound is 600 seconds,
but the underlying lowering cost remains open.

An exact post-G20 run of `lowrisc:ibex:ibex_core:0.1` at OpenTitan
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19` no longer hits the former
out-of-range bit-mask segfault. It reaches the 600.085-second bound and exits as
`COMPILE_TIMEOUT`; the complete compiler process session is reaped. A process
sample spends 663 of 685 samples in `connect()` below
`NetESelect::synthesize`, inside a condition nested in an unrolled `for` loop.
The same run had already diagnosed the separate bit-level latch-enable limit in
`ibex_alu.sv` and three unsynthesized `ibex_multdiv_fast.sv` processes.

After G23 was generalized from a syntactic no-condition test to its real
semantic invariant (owned bits written on every path and a constant-high
process enable), the exact `ibex-disjoint-precise-v2` replay removes the
`ibex_alu.sv` `shift_amt[4:0]` latch diagnostic. The independently driven bit 5
and complete `if/else` lower field are now recognized as disjoint,
latch-free owners. The run still reaches `COMPILE_TIMEOUT` after 600.078 seconds
and leaves no descendant. Its only emitted semantic-debt line was the legal
constant-only `always_comb` warning in `ibex_cs_registers.sv`; that warning is
removed immediately afterward under G26. The termination hot path therefore
remains independent of both semantic fixes.

G27 through G29 close the independent causes hidden by that timeout: sparse
ordinary cases were expanded into dense muxes with quadratic nexus searches;
loop-context select arithmetic was not folded; descending loop subtraction was
reversed and then lost the signed loop-variable context; and an empty default
clause was not recorded as a default when reducing a wide selector.

The final exact `ibex-case-fallback-v8` replay of
`lowrisc:ibex:ibex_core:0.1` at the same pinned OpenTitan revision is `PASS` in
0.761 seconds: exit 0, 0 hard errors, 0 semantic-debt diagnostics, no timeout
and no leaked descendant. This is bounded-termination and synthesis-conformance
closure, not a cybersecurity vulnerability.

## G23 — disjoint packed fields looked like conflicting whole-vector processes — **fixed** (current upstream campaign)

*9.2 / synthesis process ownership [general] — false latch and false conflict.*

OpenTitan's generated arbitration trees use separate unconditional
`always_comb` processes for disjoint bits or fields of packed tree vectors.
Synthesis already computed a per-process write mask, but treated every false
bit as a latch and later used a whole-net l-value reference count to reject the
other disjoint processes as conflicting writers.

An asynchronous process consisting only of unconditional assignments now
drives `Z` outside its write mask, so independently synthesized fields compose
without state. Synthesized procedural ownership is claimed per nexus bit, not
per `NetNet`: a second process may claim a disjoint field, while a real overlap
still produces a local hard diagnostic naming the exact bit.

Ownership is the union of exact constant ranges written anywhere in a process,
including conditional clocked branches. After the complete synthesis walk, a
second validation pass also rejects a packed signal that retains a behavioral
procedural l-value while carrying any synthesized process driver. That keeps
the pre-existing `case5-syn-fail` safety boundary loud instead of accepting a
mixed behavioral/structural variable that would simulate incorrectly.

`synth_disjoint_packed_processes.v` checks generated one-bit and two-bit writers
with two changing values in ordinary and `-S` execution.
`synth_overlapping_packed_processes.v` proves that two fields sharing bit 1 are
still rejected, and `synth_overlapping_conditional_packed_processes.v` proves a
conditional `always_ff` write remains owned and conflicts correctly.
Complete conditional branches over the same partial field are included because
their synthesized enable is constant high. Incomplete conditional
combinational/latch writes are not; G25 keeps that stateful case loud.

## G24 — constant part-select `always_comb` sensitivity was widened — **fixed** (current upstream campaign)

*9.2.2.2.1 [general] — extra scheduling and explicit semantic debt.*

The input walk could already represent a constant select as a nexus plus exact
base and width, but the implicit-event elaborator ignored that range. It
therefore monitored the entire vector and emitted a debt warning for every
such `always_comb` process.

Implicit event elaboration now inserts a `NetPartSelect` probe through a
one-pin carrier, preserving the selected unpacked-array word as well as the
packed base/width. Event analysis traces that probe back to its source range,
and compiler-generated `always_comb`/`always_latch` events retain their
time-zero asynchronous classification.

`sv_always_comb_precise_select_sens.v` counts evaluations: selected-bit changes
wake the process, while two different unselected-bit changes do not. The older
read-one-field/write-another regression remains value-clean.

Together, G20, G23 and G24 move the exact pinned Darjeeling RACL synthesis job
to `PASS`: exit 0, 0 hard errors, 0 semantic-debt lines, no timeout, 0.334
seconds on the final tested compiler.

## G25 — incomplete conditional partial packed writes need independent latch enables — **open**

*[general] — real stateful synthesis boundary.*

Unlike G23's fully assigned disjoint owners, `always_latch if (en) q[0] = d`
must retain the prior value of one field without claiming untouched fields.
The current synthesis interface carries a vector-wide enable plus a write mask,
not one enable expression per bit. `synth_partial_latch_reject.v` permanently
requires a normal nonzero diagnostic rather than a crash or a silent `Z`
substitution. `synth_branch_disjoint_partial_latch_reject.v` covers the less
obvious adversarial case: each `if/else` branch writes a different bit, so the
vector-wide enable is high even though each individual bit still needs state.
The safe disjoint lowering now additionally proves that every bit written
anywhere is written on every path before using `Z` outside the owned field.
Closing this row requires per-bit enable propagation through if/case/loop
lowering and value-checked hold/update behavior.

## G26 — constant-only `always_comb` was warned as sensitivity debt — **fixed** (current upstream campaign)

*9.2.2.2.2 [general] — legal time-zero process, false semantic debt.*

An `always_comb` whose right-hand sides are all constants has no event probes,
but IEEE semantics still execute it once at time zero. The compiler already
implemented that behavior and synthesis already classified the empty implicit
event as combinational; a later validation pass nevertheless warned that the
process had no sensitivities. OpenTitan's constant `mhpmevent` construction in
`ibex_cs_registers.sv` was the final Ibex debt line.

The warning is removed for `always_comb` only. The existing regression now
checks the time-zero value without expecting a diagnostic. A sensitivity-free
`always_latch` remains an error, and legacy `always @*` retains its warning
because it has no mandatory time-zero execution.

## G27 — sparse ordinary cases expanded into dense muxes — **fixed** (current upstream campaign)

*12.5 / synthesis lowering [general] — bounded termination and exact matching.*

Ibex's CSR write decoder has 77 explicit values over a 12-bit selector and 19
outputs. The old lowering allocated a 4,096-input data mux and enable mux for
every output. Missing selections all shared the same default nexus, but every
connection searched that growing circular list again and every selector value
rescanned the same default enable. This made a finite decode effectively
quadratic and consumed the complete 600-second bound.

Sparse ordinary cases now lower as exact case-equality comparisons followed by
binary muxes, so the circuit scales with explicit clauses. Undefined and
variable ordinary guards take the same exact-comparison path instead of being
coerced to unsigned mux indices. Dense cases retain their compact mux lowering,
with cached default nexuses and one invariant default-enable check so their
construction is linear. `synth_sparse_case.v` checks the Ibex-shaped 12-bit
decode and an empty default in ordinary and `-S` execution. The pre-existing
`casesynth8.v` regression is now a passing synthesis case for a variable guard,
rather than an expected compile error.

## G28 — procedural loop context lost constant indices and signed decrement semantics — **fixed** (current upstream campaign)

*11.5 / 12.7 [general] — contextualization and bounded termination.*

The synthesis unroller knew each procedural `for` index value, but expressions
such as `matrix[i][i-BASE]` remained dynamic selects because only a literal
`NetEConst` base selected the fixed lowering. Loop-only base expressions are
now evaluated in the current iteration context and become fixed selects.

Ibex also exposed two basic descending-loop defects in
`for (int i = 14; i >= 0; i--)`: subtract-assignment constructed `step-current`
instead of `current-step`, producing `14,-13,14,...`; after correcting the
operand order, constant folding dropped the declared signed `int` context, so
`-1` became unsigned `32'hffff_ffff` and still satisfied `i >= 0`. Initializers
and step results now retain the loop variable's declared signedness.
`synth_for_loop_index_select.v` checks the packed-matrix selection shape;
`synth_for_loop_descending.v` checks both `i--` and `i -= 2` with a signed
termination comparison.

## G29 — empty case default was lost during selector reduction — **fixed** (current upstream campaign)

*12.5.3 [general] — incorrect fallback selection and compiler assertion.*

An empty `default: ;` has a null statement pointer but is still a present
default clause. Dense case lowering used the pointer itself as the presence
test, reduced Ibex's 3-bit selector for explicit values 0 and 1 to one bit, and
asserted because the reduction helper requires a fallback selector bit.

Default presence is now tracked independently of the statement body. A wide
case with no written default uses the exact comparison chain when narrowing
would fold unmatched high values onto an explicit arm. The
`synth_case_wide_select_fallback.v` regression value-checks both an empty
default and the implicit no-default fallback for selector values 0, 1, 2 and 7.

## G30 — synthesized process ownership flowed backward through direct assignments — **fixed** (current upstream campaign)

*6.5 / synthesis lowering [general] — process ownership and structural direction.*

An asynchronous procedural assignment previously connected its synthesized
result directly to the r-value nexus. Ownership was recorded afterward. For a
hierarchical chain such as `always_comb d_o = d_i`, the connection therefore
merged the output variable with its input before the ownership walk and made a
legal upstream process appear to be a second writer of the same variable.
OpenTitan's generic synchronizer and flop wrappers amplified that false overlap
across clock, reset, power, alert and OTP blocks.

Each non-latch synthesized process output now crosses a transparent structural
buffer before reaching its owned variable. The buffer preserves direction,
four-state values and disjoint-field Z composition while preventing ownership
from propagating backward into an input. Genuine same-bit procedural overlaps
remain errors. `synth_process_alias_boundary.v` reproduces a two-instance port
chain and value-checks 0, 1 and X in ordinary and `-S` execution.

In the fresh `process-boundary-v12` replay, the formerly failing Darjeeling
`alert_handler`, `pwrmgr` and `rstmgr` cores are `PASS` with zero hard errors and
zero semantic debt in 46.750, 0.403 and 0.594 seconds respectively. The change
also removes the false multi-process hard errors from `clkmgr` and `otp_ctrl`;
their independent diagnostic debt is recorded separately. Every witness has
`security_vulnerability=false`.

## G31 — explicit always_latch intent was reported as accidental inference — **fixed** (current upstream campaign)

*9.2.2.3 / synthesis diagnostics [general] — diagnostic precision.*

The synthesizer correctly built a latch for `always_latch`, then emitted the
same inferred-latch and synthesized-enable warnings used for an accidental
incomplete `always_comb` or legacy combinational process. This made OpenTitan's
intentional generic clock-gating latch semantic debt even though the construct
explicitly requests that storage behavior.

Explicit `always_latch` processes now synthesize the intended latch without
those inference warnings. Accidental latch inference retains both diagnostics;
`basiclatch.v` verifies that boundary, while `synth_always_latch_intent.v`
value-checks capture and hold behavior in ordinary and `-S` execution. The
exact `clkmgr-latch-intent-v13` Darjeeling replay is `PASS` in 0.456 seconds,
with exit 0, zero hard errors, zero semantic debt and
`security_vulnerability=false`.

## G32 — constant aggregate member selects emitted false sensitivity debt — **fixed** (current upstream campaign)

*9.2.2.2.1 / 11.5 [general] — implicit sensitivity and nested selects.*

OpenTitan indexes the constant packed `PartInfo` partition table with a runtime
partition index and then selects individual struct fields. Elaboration lowers
that shape to nested selects. The sensitivity walk correctly included the
runtime index and found no signal dependency in the constant data, but the
outer constant member select only recognized a direct signal as precise and
emitted a conservative-sensitivity warning for every use. Darjeeling OTP
therefore compiled successfully with 37 identical debt diagnostics.

The sensitivity walk now recognizes nested selects whose innermost data source
is constant. Their runtime dependencies are exactly the nested base/index
expressions already collected by the walk, so no conservative fallback or
warning is needed. `synth_constant_array_select_sensitivity.v` value-checks a
runtime index followed by a constant member-field select in ordinary and `-S`
execution. The exact `otp-constant-sensitivity-v15` Darjeeling replay is `PASS`
in 21.432 seconds, with exit 0, zero hard errors, zero semantic debt and
`security_vulnerability=false`.

## G33 — whole unpacked-array assignments were mapped as one packed word — **fixed** (current upstream campaign)

*7.4 / 10.9 / synthesis lowering [general] — unpacked arrays and assignment patterns.*

A whole unpacked-array l-value contributed only word zero to the process
output map. Its array-pattern r-value correctly synthesized to one net pin per
word, but the packed-vector assignment path then compared the map's aggregate
width with one element's packed width and aborted. This was the common
`nex_map[ptr].wid == lsig_width` assertion in Ibex, SHA3, KMAC and OTBN-family
cores.

Whole unpacked-array assignments now claim every destination word and lower
each r-value pin to the corresponding word nexus with its own vector width,
enable and driven mask. `synth_unpacked_array_whole_assign.v` value-checks a
two-word array pattern through two input updates in ordinary and `-S`
execution. A fresh Darjeeling `rv_core_ibex` replay advances past the former
Ibex ALU abort to the separately tracked partial-reset and run-time memory-word
gaps; the old whole-array assertion is absent and
`security_vulnerability=false`.

## G34 — nested synthesized procedural loops discarded the outer index — **fixed** (current upstream campaign)

*12.7 / 11.5 / synthesis lowering [general] — nested loop contextualization.*

The procedural-loop unroller required its contextual index map to be empty at
entry, so an inner loop aborted while an outer loop index was active. Merely
removing that assertion would still be wrong: signal and select synthesis only
recognized the most recent index, so an outer unpacked-array word select could
remain a run-time net instead of the constant for the current unrolled
iteration.

Nested loops now inherit and restore their enclosing index values, index-net
identities and generate scratch state. Constant substitution is keyed by the
exact loop-index net rather than by a possibly shadowed name, and select-base
folding accepts expressions whose inputs are any combination of active loop
indices. `synth_nested_for_loop_select.v` combines a whole unpacked-array
assignment with outer word and inner packed-field selects and value-checks two
updates in ordinary and `-S` execution. The exact `nested-sha3-v20` OpenTitan
replay is `PASS` in 0.263 seconds, with exit 0, zero hard errors, zero semantic
debt, no timeout and `security_vulnerability=false`.

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
