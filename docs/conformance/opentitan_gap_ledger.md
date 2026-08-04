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

## G13 — non-literal cycle-delay bounds — **fixed** (current upstream campaign)

*16.9.2.* `##[SkewCycles+2:SkewCycles+3]` where the bounds are parameters
rather than literals:

```
sorry: sequence cycle delays must be literal constants
```

The early SVA constant folder already handled local and explicitly imported
parameters, but it ran before ordinary wildcard-import pinning and did not
fold integral exponentiation. It now resolves an unambiguous parameter or enum
through `potential_imports` (including package re-exports) and folds `**` with
defined machine-width arithmetic. `sv_assert_wildcard_parameter_delay.v`
checks a wildcard-imported package parameter used through a localparam and
exponentiation, including the exact upper-window runtime boundary. The exact
Earl Grey and Darjeeling `alert_handler_ping_timer_fpv` jobs now compile with
zero diagnostics and are `PASS`.

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

## G35 — asynchronous-reset synthesis required every bit of a shared packed variable — **fixed** (current upstream campaign)

*9.2.2.4 / synthesis lowering [general] — disjoint sequential ownership and mixed reset behavior.*

The synchronous-process pass created one full-width flip-flop for every
process touching a packed variable and required each asynchronous branch to
assign every bit of that variable. OpenTitan legitimately uses generated
`always_ff` processes that own disjoint static fields, and also groups reset
and unreset flops in one process. The first shape was rejected as a partial
reset even when every bit owned by that process was reset. The second was
rejected when an output was intentionally omitted from the reset branch.

Reset coverage is now checked against the exact static bits written by the
conditional process. A synthesized flip-flop output is masked to Z outside
its process-owned fields, so disjoint sequential drivers compose without
claiming or changing neighboring fields. After every process has claimed its
fields, one masked baseline preserves the source variable's globally unwritten
bits as X for four-state types or zero for two-state types; it remains absent
when a pre-existing structural driver gives the object net semantics. An
output wholly omitted from the
asynchronous branch is modeled as an unreset flip-flop whose clock enable is
qualified by reset deassertion; it therefore holds both on the reset edge and
on clocks while reset remains asserted. A nonempty reset that covers only
some bits owned by the same process remains an explicit error.

`synth_disjoint_partial_async_reset.v` value-checks two field owners through
reset, simultaneous updates and an enabled/held split.
`synth_mixed_async_reset_outputs.v` checks a reset and unreset output in one
process, including a clock while reset is active.
`synth_unwritten_packed_initialization.v` differentially checks raw and `-S`
behavior for four-state holes, two-state zero initialization, reversed process
order, ascending packed ranges, a logic-typed child alias, and a disjoint
continuous driver.
`synth_partial_async_reset_reject.v` preserves the genuine partial-reset
negative boundary. All positive checks pass in ordinary and `-S` execution.
The exact `partial-reset-gpio-v22` and `mixed-reset-edn-v25` OpenTitan replays
are `PASS` in 0.478 and 1.463 seconds respectively, with exit 0, zero hard
errors, zero semantic debt, no timeout and `security_vulnerability=false`.
The Darjeeling `rv_core_ibex` witness drops from 11 hard diagnostics to the two
separately tracked run-time RAM-word diagnostics.

## G36 — run-time-selected memory-word writes were rejected by synthesis — **fixed** (current upstream campaign)

*7.4 / 10.6 / synthesis lowering [general] — unpacked-array word selection and procedural assignment.*

A procedural assignment to an unpacked-array word was synthesizable only when
the canonical word index was constant. OpenTitan's generic single-port RAM
uses a request-qualified whole-word write, `mem[addr_i] <= wdata`, so the
Darjeeling Ibex wrapper stopped after otherwise completing its synthesis
lowering.

The run-time word select is now lowered to one shared data path and an exact
per-word address decoder. The ordinary conditional-enable machinery combines
the decoder with enclosing request and write guards, producing a distinct
enable for every possible destination word. An out-of-range address, or an
address containing X or Z, matches no word and therefore performs no write.
Synthesis ownership walks conservatively claim every possible destination,
while the separate `always_comb` sensitivity-subtraction walk retains its
word-precise behavior. A packed partial write through a run-time word select
remains a separate, explicit unsupported boundary rather than being widened
silently to a whole-word write.

`synth_runtime_memory_word.v` value-checks the OpenTitan-shaped shared
synchronous read/write process, repeated writes, request holds, a non-power-of-
two depth, an out-of-range address and a four-state unknown address in ordinary
and `-S` execution. `synth_runtime_memory_partial_reject.v` pins the distinct
packed-partial-write diagnostic.

## G37 — a statically empty memory-preload initial process remained semantic debt — **fixed** (current upstream campaign)

*9.2.1 / constant folding / synthesis classification [general] — initial procedures.*

OpenTitan's memory preload helper retains an `initial` process under
`SYNTHESIS`, but with the default empty `MemInitFile` its only conditional path
contains no live statement. The synthesis classifier warned about the process
without first following the already folded constant condition, leaving a
false semantic-debt result after the RAM itself compiled cleanly.

Synthesis now removes an initial process only when recursively following its
statically selected block/conditional path proves that path empty. A live
preload path is not suppressed and still reports `Process not synthesized`.
`synth_inert_initial.v` covers the empty-file shape and the focused override
check preserves the live-path diagnostic.

Together, G36 and G37 move the final exact `runtime-memory-rv-core-v28`
Darjeeling `rv_core_ibex` replay to `PASS` in 11.985 seconds, with exit 0, zero hard
errors, zero semantic debt, no timeout and `security_vulnerability=false`.

## G38 — loop-expanded packed-field writes were widened after synthesis — **fixed** (current upstream campaign)

*9.2.2.2 / 10.6 / 11.5 / synthesis lowering [general] — exact write coverage and process ownership.*

The v29 whole-RTL census completed all 267 candidates at the pinned upstream
revision: 58 `PASS`, 153 `DEPENDENCY_ONLY`, 39 `FAIL`, 8
`COMPILE_TIMEOUT`, 6 `SETUP_FAIL`, and 3 `DEBT`. Its 209 non-pass records
partition exhaustively into 11 compiler/IEEE defects, 12 synthesis-lowering
defects, 3 semantic-debt records, 8 bounded timeouts, 22 provider/source-list/
top-selection harness defects, and 153 dependency-only cores. The highest-
multiplicity synthesis family was a false bit-level-latch rejection in eight
standalone cores and three larger top-level witnesses. Every record retains
`security_vulnerability=false`.

Generated OpenTitan register interfaces assign disjoint packed fields in
separate `always_comb` processes, often inside procedural loops. The loop
unroller resolved every index and produced the right data substitutions and
per-bit driven masks. Process ownership was nevertheless collected later by
walking the original statement after the loop context had been restored, so a
field such as `aggregate.fields[i].d` conservatively expanded to the complete
packed nexus. The top-level latch check then mistook legal unconditional field
writes for independently enabled partial writes.

Synthesis now records a separate may-write mask while each assignment is
lowered, when loop indices, unpacked words, and packed bases have their actual
contextual values. The same exact mask controls floating-input tie-off,
process-output Z masking, and global same-bit ownership claims. Guaranteed-
write masks remain deliberately stricter: sequential statements with the same
enable can union their bits, distinct enables retain only their intersection,
and an unconditional statement contributes only its own guaranteed bits.
Run-time packed selects therefore still require unsupported bit-level latch
enables unless a whole-vector default covers them.

Boundary handling is exact rather than width-based. A syntactic packed select
is recognized from its base expression even when its width equals the target;
constant partial overlaps are clipped, wholly out-of-range selects are no-ops,
and run-time selects contribute no guaranteed bits. A selected part may be
wider than its target, including a four-bit write clipped into a two-bit
vector. Decoder constants preserve negative values for signed selectors wider
than 64 bits. Contextually constant X/Z packed indices and unpacked-memory word
indices are exact no-ops rather than being converted to index zero; the memory
path still performs the l-value release bookkeeping needed to preserve earlier
real writes. Concatenated l-values preserve earlier output, enable, and mask
state when a later element is a no-op or run-time select.

`synth_packed_loop_disjoint_fields.v`,
`synth_clipped_constant_part_select.v`,
`synth_concat_select_write_masks.v`,
`synth_common_latch_enable.v`, `synth_noop_packed_write.v`, and the expanded
`synth_variable_packed_lvalue.v` value-check the positive shapes in ordinary
and `-S` execution. The no-op test includes fully out-of-range four-bit
combinational and flip-flop writes plus constant X/Z packed and memory indices,
both after defaults and in standalone processes. The variable-select test
includes a 65-bit signed negative index. `synth_packed_loop_overlap_reject.v`,
`synth_sequential_partial_latch_reject.v`,
`synth_variable_partial_latch_reject.v`,
`synth_variable_full_width_latch_reject.v`, and
`synth_noop_partial_latch_reject.v` preserve genuine overlap and bit-level-
latch rejection boundaries.

Final local validation passed `make check` and the complete vendored regression
with `Total=3351`, `Passed=3346`, `Failed=0`, `Not Implemented=2`, and
`Expected Fail=3`.

The frozen-binary seven-core `packed-loop-write-masks-v32-quick` replay removes
the false latch diagnostic from every focused family witness. HMAC, full and
reduced KMAC, USBDEV, and Earl Grey sensor control are `PASS`; AES reaches only
its independent `uwire` ownership debt, and DMA reaches only its independent
`wdata_intg_i` width debt. All seven compiles exit 0 without timeout or hard
error, and every result has `security_vulnerability=false`. The compiler engine
fingerprint is
`287c40f65ff77e90c2c7c50521fa6d2ea0f95587f6461f70e09c510b4cae8cd0`.

The companion exact replays remain bounded non-pass evidence, not clean-corpus
claims. CSRNG 0.1 produces no diagnostic before its 600.077-second compile
timeout. Darjeeling and Earl Grey likewise time out after 600.566 and 600.261
seconds; English Breakfast advances to the separately classified `pinmux`
asynchronous-load synthesis rejection in 253.606 seconds. None of those four
logs contains the former packed-loop/latch diagnostic, and every record retains
`security_vulnerability=false`.

## G39 — loop-index-constant reset branches were mistaken for asynchronous data loads — **fixed** (current upstream campaign)

*9.2.2.4 / constant folding / synthesis lowering [general] — contextually constant reset selection in unrolled procedural loops.*

The v33 whole-RTL census completed all 267 candidates at OpenTitan revision
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19`: 63 `PASS`, 153
`DEPENDENCY_ONLY`, 31 `FAIL`, 9 `COMPILE_TIMEOUT`, 6 `SETUP_FAIL`, and 5
`DEBT`. Its 204 non-pass records partition exhaustively into 11 compiler/IEEE
defects, 4 synthesis-lowering defects, 5 semantic-debt records, 9 bounded
timeouts, 22 provider/source-list/top-selection harness defects, and 153
dependency-only cores. Every record explicitly has
`security_vulnerability=false`.

The v33 evidence is under
`matrix/full-7a3ad34/rtl-v33/opentitan-matrix.json` and
`matrix/full-7a3ad34/rtl-v33/opentitan-matrix.md`. Their SHA-256 fingerprints
are respectively
`89d8f1f7c64ca2b58ab934379801345d5f2b0c3cce1adef2ae524557cd003df2`
and
`5e95e46ebbe1525d8ae25ca99f5a627bb36c0e9fb30cd235520a1afaf344ee18`.
The frozen compiler engine fingerprint is
`287c40f65ff77e90c2c7c50521fa6d2ea0f95587f6461f70e09c510b4cae8cd0`.
The report metadata records the OpenTitan worktree as dirty, so this is pinned
revision and binary evidence rather than a pristine-source claim.

Two of the four v33 synthesis-lowering failures were the Earl Grey and English
Breakfast `pinmux` cores. Both stopped at the generated reset process with
`Asynchronous load is not currently supported in synthesis`, followed by the
synchronous-process and `always_*` fallback diagnostics. Earl Grey exited 3
after 89.996 seconds with three hard diagnostics; English Breakfast exited 3
after 69.643 seconds with the same three diagnostics. Neither result timed out
or carried semantic debt.

The asynchronous reset branch initializes each packed pad attribute inside a
procedural loop. Its condition compares the unrolled loop index against a
packed-structure parameter, so the selected reset value is constant in every
iteration. The loop synthesizer already retained the contextual value of the
index, but conditional synthesis still built a run-time mux between the two
constant reset clauses. The asynchronous-storage recognizer did not treat that
mux as a constant reset driver and consequently misclassified it as an
asynchronous data load.

Conditional synthesis now checks whether the condition can be folded using
constants and the active unrolled-loop context. Loop locals are recognized by
the identity of their elaborated `NetNet`, then mapped to the corresponding
context value; matching a signal merely by basename is insufficient. The
aggregate identity map remains on the process synthesis scope, while a scoped
guard mirrors the active entry into the index declaration scope for expression
evaluation and restores it before the iteration value is replaced. This covers
both a loop local declared below the process scope and an ancestor-declared
index used by a process in a generate child. When evaluation produces a defined
constant, synthesis follows only the selected clause instead of retaining a
mux. A run-time signal, an unknown result, or an unsupported expression form
retains the existing run-time path and its asynchronous-load rejection
boundary.

`synth_loop_constant_async_reset.v` models the OpenTitan packed configuration
parameter, packed pad-attribute array, assignment-pattern reset value, and
loop-index comparison. It value-checks the selected reset element and
independently enabled updates. `synth_runtime_async_load_reject.v` deliberately
gives a module input and the procedural loop local the same basename,
`index`, then references the run-time input as `main.index`. Signal-identity
matching keeps that reference dynamic and preserves the expected
asynchronous-data-load compile rejection.

`synth_nested_loop_shadow_index.v` exercises two distinct active loop variables
with the same basename. It value-checks both scope directions: an outer local
declared below the process synthesis scope, and a module-scope outer index used
by an `always_comb` in a generate child. The latter was an independently
confirmed silent counterexample before the declaration-scope guard: ordinary
execution produced `1010`, while `-S` produced `1000`. The same test also
reuses the module-scope index in a later, non-nested loop to prove restoration.
`synth_loop_unknown_async_reset.v` makes a context-only condition evaluate to
X and preserves the expected asynchronous-load rejection rather than choosing
a branch accidentally.

Final local validation passed `make check` and the complete vendored regression
with `Total=3356`, `Passed=3351`, `Failed=0`, `Not Implemented=2`, and
`Expected Fail=3`.

The final frozen-binary two-core `context-constant-pinmux-v38` replay is
`PASS=2`. Earl Grey compiles in 65.029 seconds and English Breakfast in 55.806
seconds; both exit 0 with zero hard errors, zero semantic debt, no timeout, and
`security_vulnerability=false`. The compiler engine fingerprint is
`00650942adb5412768247ddc0f3c134bc5ec1690aaae623ec22a8b69bfdfc35c`;
the driver fingerprint is
`1fa9b330b6aefd694e41b2699db956b208ffedcf60b5c615d38084aa47e60500`.

The focused evidence is under
`matrix/full-7a3ad34/context-constant-pinmux-v38/opentitan-matrix.json` and
`matrix/full-7a3ad34/context-constant-pinmux-v38/opentitan-matrix.md`, whose
SHA-256 fingerprints are respectively
`c08d35fa16d513ba88a67bd933e8b8e5aaca3729e629480a9e4e3dd2f935fd81`
and
`91ed8cab38a9456f314722b718572da128973f03e96a67c0baffc7d4fc98dd48`.

The companion final-engine English Breakfast top replay completes rather than
failing at `pinmux` or timing out. It exits 0 after 186.627 seconds with no hard
error and no timeout, but remains `DEBT` because of four independent findings:
two `sram_ctrl` configuration-port width mismatches (416 versus 13 and 32
versus 1), one unsynthesized Ibex process, and the AES `hw2reg` `uwire` with 28
drivers. The record has `security_vulnerability=false` and contains no pinmux
asynchronous-load diagnostic. Its JSON and Markdown evidence are under
`matrix/full-7a3ad34/context-constant-pinmux-v38-eb-top/`; their SHA-256
fingerprints are respectively
`d811ecf7df4346369f8a48730944a025674fda6aa57c53b833abfc633dcb8000`
and
`b735c86af35bfb7c8df2653b63f5630193343584003388cd1c0c7edc0633bade`.

The fresh final-engine v39 whole-RTL census confirms those transitions across
all 267 candidates: 65 `PASS`, 153 `DEPENDENCY_ONLY`, 29 `FAIL`, 9
`COMPILE_TIMEOUT`, 6 `SETUP_FAIL`, and 5 `DEBT`. The Earl Grey and English
Breakfast pinmux records are the only two status changes from v33; all other
265 records retain the same status. The 202 non-pass records partition
exhaustively into 11 compiler/IEEE defects, 2 synthesis-lowering defects, 5
semantic-debt records, 9 bounded timeouts, 22 provider/source-list/top-selection
harness defects, and 153 dependency-only cores. Every result again has
`security_vulnerability=false`.

The v39 evidence is under
`matrix/full-7a3ad34/rtl-v39/opentitan-matrix.json` and
`matrix/full-7a3ad34/rtl-v39/opentitan-matrix.md`. Their SHA-256 fingerprints
are respectively
`5af606030d0ca8a87d0375c0398354a55b0ab894bb70160647e07c6a6c940623`
and
`ae53cc264ea810197f97981ec88b029044584e6cb4c1da67d9453abd12a5aaee`.
The report records the final driver fingerprint
`1fa9b330b6aefd694e41b2699db956b208ffedcf60b5c615d38084aa47e60500`
and compiler-engine fingerprint
`00650942adb5412768247ddc0f3c134bc5ec1690aaae623ec22a8b69bfdfc35c`.
It remains pinned-revision evidence from a deliberately preserved dirty
OpenTitan worktree. The census does not reclassify the remaining OTBN width
assertion or RRAM array-parameter part-select defects.

## G40 — nested synthesis loops sharing one index require shared-state propagation — **diagnosed; explicit rejection remains** (current upstream campaign)

*12.7 / procedural loops / synthesis lowering [general] — one variable reused
as the control variable of active nested loops.*

A legal nested loop can reuse the exact same `integer` as both control
variables. The inner loop then changes the outer loop's state, but the current
unroller represents the two active iterations independently. During the G39
identity review, an intermediate exact-identity implementation made that
divergence observable as a silent X result. A first local rejection also
exposed that `NetForLoop::synth_async` ignored a false return from a nested body
and allowed code generation to reach an internal assertion.

Synthesis now detects an already-active exact `NetNet` before evaluating the
nested loop initializer or condition and emits an explicit unsupported
diagnostic. A failed nested body is propagated after restoring all loop and
genvar context, so compilation terminates normally instead of asserting.
`synth_nested_loop_same_index_reject.v` documents the ordinary language
behavior and proves the expected `-S` compile rejection. This is not an IEEE
conformance pass: full modeling of the inner loop's terminal value as the
enclosing loop's live state remains open.

## G41 — a package-qualified assignment-pattern expression type was rejected or discarded — **fixed** (current upstream campaign)

*6.24 / 10.9.1 / A.6.7.1 [general] — typed assignment-pattern parsing,
contextual typing, and self-determined width.*

The v39 census exposed one parser family in eight records: the three
standalone `top_{darjeeling,earlgrey,englishbreakfast}_ast` cores plus five
chip wrappers. Every record exited 10 with ten hard diagnostics, for 80 hard
diagnostics in total. The first error was `ast.sv:757` for Darjeeling or
`ast.sv:293` for Earl Grey and English Breakfast. All five replicated memory-
configuration expressions in each AST source used the legal shape

```systemverilog
{N{prim_ram_1p_pkg::ram_1p_cfg_req_t'{req: spram_rm.cfg}}}
```

The lexer already returns `'{` as the single `K_LP` token. The expression
grammar nevertheless accepted only an unqualified `TYPE_IDENTIFIER` directly
before an assignment pattern; a `package_scope TYPE_IDENTIFIER` could not
reach that production. Worse, the accepted production deleted the type and
returned only the untyped pattern. That loses required semantics even when
parsing succeeds: an assignment pattern has no self-determined type or width,
while its explicit prefix must shape it before it participates in the enclosing
replication concatenation.

The grammar now implements the supported forms of
`assignment_pattern_expression_type` directly: `ps_type_identifier`, the six
integer atom types (`byte`, `shortint`, `int`, `longint`, `integer`, and
`time`), and `type(expression)`. The result is represented as `PECastType`
around the pattern instead of dropping the prefix. Package-qualified typedefs,
local typedefs, type parameters, atom types, and type references therefore all
carry their target into elaboration. Parse-form dumping also emits the original
`T'{...}` shape rather than the ordinary `T'(...)` cast punctuation.

Typed-pattern elaboration resolves the cast target before the generic
width-driven path and gives that type directly to `PEAssignPattern`. This is
required for packed aggregates inside replications and for unpacked structs,
static arrays, dynamic arrays, and queues; it also avoids the generic dynamic-
container cast path trying the deliberately invalid context-free pattern
overload. A parse-form expression is shared by all specializations of a module,
so a direct pattern using `parameter type T` refreshes the target in each
instance scope rather than reusing `PECastType`'s earlier cached type.

`synth_typed_assignment_pattern.v` value-checks package-qualified and local-
typedef packed structs inside concatenation replication, reversed named
members, integer-atom and `type(expression)` prefixes, a static unpacked array,
a dynamic array, a queue, and default and overridden type parameters. The two
packed type-parameter specializations reverse member declaration order. Two
additional nonpacked specializations exercise the direct typed-rvalue path
without a preceding concatenation width test, proving that scope-specific
target resolution is not cached across instances. Ordinary and `-S` execution
both print `PASSED`.

An exact Bison 3.8.2 comparison against `HEAD` reports no parser-ambiguity
growth: both grammars have 504 shift/reduce conflicts, 1186 reduce/reduce
conflicts, and 209 conflict states. Final local validation passed `make check`
and the complete installed-backend regression with `Total=3357`,
`Passed=3352`, `Failed=0`, `Not Implemented=2`, and `Expected Fail=3`.

The pinned-revision eight-core v40 replay removes every former `ast.sv` typed-
pattern syntax diagnostic. Four chip wrappers advance from immediate `FAIL` to
the explicit 600-second `COMPILE_TIMEOUT` bound without a recognized hard
diagnostic. The English Breakfast Verilator wrapper advances from ten syntax
errors to one independent explicit-cast error after 29.542 seconds. The three
standalone AST cores compile past their typed patterns in under half a second
and reach the separately classified multiple-asynchronous-set/reset synthesis
gap, each with six unique hard diagnostics after deduplication. All eight
records retain `security_vulnerability=false`; this focused replay proves the
parser family is retired, not that the larger cores are clean.

The v40 evidence is under
`matrix/full-7a3ad34/typed-assignment-pattern-ast-v40/opentitan-matrix.json`
and `opentitan-matrix.md`. Their SHA-256 fingerprints are respectively
`49c42bcb85c526c21ec55bf0e794eb2502d72ac9110bcb218425ff6ef77bb30a`
and
`4b75a2b908b9da50c7d54adfda8ff19b4f83eaaa6116fd9d6d7c10b817e2da37`.
The isolated replay wrapper fingerprint is
`e25b50fb9d7a07fcecdb693bb984dd965d143444aebc4936a9306f0d4893d23c`,
and its compiler-engine fingerprint is
`0bca372584e8bcc851abda4361775ebb35f59f44f266ac353182132e210317b1`.
The report records the OpenTitan worktree as deliberately dirty at revision
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19`.

## G42 — a value-parameter assignment-pattern prefix — **retired; incorrect premise** (current upstream campaign)

*6.24.1 / 10.9 / A.6.7.1 / A.9.3 [general] — assignment-pattern expression
types versus size casts.*

The earlier entry incorrectly treated `W'{default: value}` as a size-cast form
when `W` is an ordinary value parameter. Clause 10.9 requires an explicit
assignment-pattern prefix to name a data type. Clause 6.24.1 applies size-cast
semantics to `casting_type'(expression)`; it does not extend them to an
assignment pattern. The legal value-parameter size cast is therefore
`W'(expression)`, not `W'{...}`. The `ps_parameter_identifier` grammar route
can denote a parameter that is itself a type; it does not turn an ordinary
value parameter into an assignment-pattern type.

A differential probe confirms the corrected interpretation. The current
compiler, Slang `11.0.415+8acc660a2`, and Verilator `5.050` all reject an
ordinary value-parameter prefix, while all accept the legal `W'(8'b1010_1100)`
control. The current compiler value-checks that control as `4'b1100`. No
`PECastSize` assignment-pattern implementation is required, and G42 is retired
rather than counted as an open conformance gap.

## G43 — class-scoped assignment-pattern expression types are rejected — **fixed** (current upstream campaign)

*6.20.3 / 8.23 / 10.9 / A.6.7.1 / A.9.3 [general] — class-scoped typedef and
type-parameter prefixes.*

A class-scoped data type is legal as an assignment-pattern expression type.
Both `C::typedef_t'{...}` and `C::type_parameter_t'{...}` are accepted by the
independent pinned Slang and Verilator baselines. The current compiler accepts
the same `C::T` as a declaration type and value-checks an untyped pattern in
that context, but rejects `C::T'{...}` during parsing. A package-scoped type
parameter already parses and value-checks correctly.

The isolation was exact: the typed assignment-pattern production used the
narrowed `ps_type_identifier` route, while a working
`class_scoped_type_identifier` production already existed elsewhere in the
grammar. The typed-pattern production now admits that existing class-scoped
data-type form without broadening ordinary identifiers into ambiguous or
invalid assignment-pattern prefixes.

`synth_typed_assignment_pattern.v` now value-checks both a class-scoped typedef
and a class-scoped type localparam. The two types deliberately use different
packed-struct member declaration orders, and the test changes the source values
after time zero, so a context-width fallback or cached wrong type cannot pass.
Ordinary and `-S` execution both print `PASSED`.

## G44 — unpacked-array parameter values lost slices or declaration direction — **fixed** (current upstream campaign)

*7.4.2 / 7.4.6 / 10.8 [general and synthesis] — unpacked-array assignment,
array slices, and left-to-left element correspondence.*

Whole unpacked-array parameters were materialized only for one exact target
shape. A partially indexed parameter or array slice could not become a typed
array value, and copying between ascending and descending declarations risked
using numeric-index order rather than the standard's left-to-left assignment
order.

Parameter expression elaboration now materializes whole arrays, partial
indices, and slices against the target array type. Source and destination
bounds and directions are tracked independently, with elements paired from
the left bound of each dimension. `sv_param_unpacked_array_slice_port.v`
value-checks all four ascending/descending whole-array combinations plus slices
in both directions. `synth_unpacked_array_slice_assign.v` covers the equivalent
synthesis path. Every ordinary and `-S` variant passes.

## G45 — a finite run-time loop bound was rejected by synthesis — **fixed** (current upstream campaign)

*12.7 [synthesis] — finite-width run-time loop limits.*

OpenTitan's RRAM controller copies a run-time-selected number of fixed-width
chunks. The loop starts at a constant, has a constant monotonic step, and its
limit is a finite-width signal, but synthesis required the comparison operand
itself to be constant.

The loop synthesizer now expands the finite representable iteration domain and
guards each iteration with the original run-time comparison. It retains the
existing rejection for a nonconstant initializer or step and for conditions
that do not establish a finite monotonic bound. `synth_runtime_for_bound.v`
checks limits zero through three, a run-time destination offset, and both
ordinary and synthesized execution. The three legacy diagnostic gold files for
`always_comb`, `always_ff`, and `always_latch` no longer expect the retired
"compare against a constant" warning; their focused replay is `3/3` clean.

The exact pinned RRAM controller synthesis job now exits zero with no output.

## G46 — packed string concatenation lost contextual conversion; int2 casts regressed — **fixed** (current upstream campaign)

*5.9 / 6.11 / 10.8 [general and synthesis] — string bit sequences,
context-determined packed assignment, and two-state conversion.*

A concatenation of string literals assigned to a packed integral parameter did
not retain its constant packed value through contextual casting. Extending the
four-state cast evaluator to accept constant bit sequences initially exposed a
second bug: the intentional `int2`-to-vector fallthrough overwrote an already
coerced two-state result with the original X/Z value.

The vector cast now preserves the constant string bit ordering and target
width. The two-state case stops after `cast_to_int2`; only a real source falls
through to the real-to-vector conversion. `sv_string_concat_packed_param.v`
checks three four-byte strings in ordinary and `-S` execution. Existing
`br_gh1074a` and `br_gh1074b` independently prove that X and Z driven into
`bit` nets become zero. The exact `bkdr_loader` synthesis job is clean.

## G47 — an unobservable declaration initializer produced Ibex synthesis debt — **fixed** (current upstream campaign)

*6.8 / synthesis dead-process elimination [synthesis] — declaration
initializers whose results have no observable consumer.*

The last Ibex `Process not synthesized` warning was an `initial` process made
from a declaration initializer in a disabled scramble generate branch. Its
single destination existed only to consume otherwise unused inputs and had no
port, structural, passive, bidirectional, or behavioral read consumer.

Synthesis now drops an `initial` process only when it has at least one output
and every output is proven unobservable by all of those consumer classes. Live
initial values remain untouched. `synth_dead_declaration_initializer.v`
passes normally and under `-S`, and exact `ibex_core`, `ibex_formal`, and
`ibex_top` jobs now exit zero without diagnostics.

## G48 — fresh whole-RTL census separates compiler failures from invalid standalone jobs — **classified; corrected replay complete** (current upstream campaign)

The pinned-revision v51 census completed all 267 selected records without a
setup or compile timeout: 88 `PASS`, 153 `DEPENDENCY_ONLY`, 18 `FAIL`, 6
`SETUP_FAIL`, and 2 `DEBT`. Four exact status changes from v47 are all real
compiler progress: `ibex_formal`, `ibex_top`, `bkdr_loader`, and `rram_ctrl`
are now `PASS`.

The 18 failures do not represent 18 remaining RTL compiler defects. Three are
simulation wrappers that the RTL selector admitted only because their library
names also matched synthesizable libraries: `ibex_top_tracing`,
`otbn_top_sim`, and `prim:crc32_sim`. The matrix now excludes names ending in
`_sim` or `_tracing` from the RTL lane, with self-tests for all three exact
cores.

Thirteen further failures are provider, source-list, or top-selection defects:
missing `otp_ctrl_macro_pkg`; missing `alert_handler_pkg` in the generated
English Breakfast `rstmgr.core`; roots named `lc_ctrl`, `ascon`, or
`tlul_payload_chk` that are absent from the generated list; and standalone
TLUL/primitive records missing their structural child dependencies. Comparing
the English Breakfast `rstmgr.core` with the Earl Grey and Darjeeling versions
proves the omitted `alert_handler_pkg` dependency directly.

The remaining two failures, standalone `aes_wrap` and `ascon`, are rejected by
the independent strict Slang baseline as well; they are upstream-invalid
standalone source shapes, not grounds for weakening Icarus type or driver
rules. The six setup failures are FuseSoC/external-system jobs rather than HDL
compile witnesses.

The only two semantic-debt records are the English Breakfast top and chip
wrapper. Their SRAM configuration supplies one 13-bit request and one response
bit to a nested RAM primitive that derives 32 instances, hence formal widths
416 and 32. Verilator reports the same two width expansions, while Slang's AST
confirms `NumRamInst=32`. This is generated English Breakfast configuration
debt, not an Icarus width calculation defect.

The corrected v52 census completed all 264 RTL records without a setup or
compile timeout: 88 `PASS`, 153 `DEPENDENCY_ONLY`, 15 `FAIL`, 6 `SETUP_FAIL`,
and 2 `DEBT`. Removing the three simulation wrappers from the v51 inventory is
the only status-count change, so the classifications above are stable. The
final JSON and Markdown reports are under
`opentitan-upstream-build/matrix/full-7a3ad34/rtl-v52/`. Their SHA-256
fingerprints are respectively
`d1659ee3e4599d85b3bcb6e3d708615b56958c339d14df8a619e9bf730d05405`
and
`c95c6abd0930ddfd111ca44d9815be4ef4142facd745c5f9a375d1a4344cb118`.

## G49 — the standalone OTBN wrapper uses Verilator compatibility extensions — **runtime compatibility open; not an RTL blocker** (current upstream campaign)

OpenTitan's standalone OTBN simulation binds an interface with
`#(.ImemAddrWidth, .DmemAddrWidth)` and lists the tracer before the interface
declaration. Icarus now has isolated compatibility grammar for the implicit
named-parameter form and a forward-referenced unqualified interface port.
`sv_implicit_named_parameter.v` checks both ordinary instantiation and bind
target-scope lookup; `sv_forward_interface_port.v` checks the source ordering.

This syntax is not a clean IEEE differential. Slang
`11.0.415+8acc660a2` rejects the two implicit parameter items and then reports
ten additional errors in this Verilator-specific wrapper, including
declaration-after-use, procedural writes to implicit output nets, and a
hierarchical `$bits` call. Verilator `5.050` accepts the same exact fileset and
exits zero, with only two independent width warnings in `otbn_lsu`.

The two Icarus compatibility additions advance the real OTBN compile past both
parser failures, but it then reaches four of those source-level/runtime
compatibility errors. The target therefore belongs in the future runtime/tool-
compatibility audit, not in the synthesizable RTL census. Factoring optional
ANSI-port attributes into explicit empty and nonempty productions removed both
new ambiguities and one older one: the generated parser is now at 503
shift/reduce and 1186 reduce/reduce conflicts, versus the historical
504/1186 baseline.

## G50 — the SVA inventory and formal-mode defines were not authoritative — **harness fixed; 128-job census pending** (current upstream campaign)

Suffix selection found 109 apparent SVA jobs, but FuseSoC's loaded core
database exposes 127 actual `formal` targets. Nineteen valid formal targets do
not end in `_sva` or `_fpv`; conversely `prim_keccak_fpv` has no `formal`
target and must use `default`. The matrix now queries the pinned FuseSoC Python
API once, selects all 127 target-backed jobs plus that one default-target job,
and records a hash of the discovered target set. The resulting inventory is
128, not 109.

The prior command also defined `ASSERT_ON`, which has no consumer in the
pinned OpenTitan tree. OpenTitan's JasperGold and VC Formal modes define
`FPV_ON`; `prim_assert.sv` uses it to select assumptions, covers, and
formal-specific RTL. The SVA lane now defines `FPV_ON`. Only
`adc_ctrl_sva` and `spi_host_sva` transitively import UVM, so only those two
jobs receive `-uvm --uvm-no-dpi -DUVM`; injecting UVM into every formal job
had created unrelated semantic debt.

One pure-FPV probe demonstrates the measurement correction directly:
`prim_count_fpv` changed from `DEBT` with 41 unrelated UVM diagnostics to a
clean `PASS`. A preliminary 55-core suffix-only FPV census, run before the
`FPV_ON` correction, is retained only as gap-discovery evidence and is not a
closure result.

## G51 — runtime status could false-pass a UVM fatal or an empty job — **false-pass gate fixed; job model open** (current upstream campaign)

The runtime lane previously treated a zero `vvp` exit with no generic
`error:` line as success. It did not match OpenTitan's `UVM_ERROR`,
`UVM_FATAL`, `TEST FAILED`, or assertion-failure patterns and required no pass
marker, so `run_test()` with no selected test could emit `UVM_FATAL NOCOMP`
and still be recorded as `PASS`. Runtime classification now imports the exact
pass/fail contract from `common_sim_cfg.hjson`: an OpenTitan runtime must print
`TEST PASSED CHECKS` or `TEST PASSED UVM_CHECKS`, and any OpenTitan failure
pattern is fatal.

The larger runtime inventory remains open. There are 91 literal `sim` targets,
not the 80 suffix-selected jobs: 61 UVM, 16 finite directed-SV, 8
Verilator/native, and 6 elaboration-only targets. Twenty-five use OpenTitan
user DPI and 24 contain native C/C++ that Edalize's Icarus backend currently
drops. Per-test Dvsim arguments, build modes, pre-run commands, software
images, and native-library loading must be represented before a full runtime
census is authoritative.

---

## G52 — concat operand "indefinite width" false positive for unsized-literal expressions — **fixed** [general]

`PEConcat::elaborate_expr` rejected every concatenation operand whose
width mode was not `SIZED`, so any expression *containing* an unsized
literal — `{1'b0, 32-BlockAw}`, `{4'hF, -1}`, `{1'b0, 2**34}`, an
untyped-parameter operand, or OpenTitan `aes_wrap.sv`'s
`{{{32-BlockAw}{1'b0}}, AES_STATUS_OFFSET}` — failed with
`Concatenation operand ... has indefinite width.` IEEE 1800-2017
11.4.12.1 only forbids bare unsized constant *numbers* as concatenation
operands; expressions take their self-determined width (11.6/11.8), and
slang 11.0 accepts all of the above shapes.

Now a non-`SIZED` operand that is not a bare `PENumber` literal is
re-tested with strict IEEE sizing (32-bit integer arithmetic, so
`{1'b1, 2**34}` truncates to `33'h1_0000_0000` exactly like the
reference tools) and elaborated at that width. A bare unsized literal
(`{1'b0, 5}`) still gets the 11.4.12.1 error. Value-checked tests:
`ivtest/ivltests/concat_unsized_expr_operand.v`,
`synth_concat_unsized_expr.v` (through `-S`), and the expected-error
`concat_unsized_literal_reject.v`.

## G53 — rtl census misclassified stale-metadata and sim-harness cores — **fixed** (matrix driver)

Four census defects hid the true compiler state of the rtl lane:

1. Cores whose CAPI `toplevel` names a module absent from their own
   fileset (upstream copy-paste: `lc_ctrl_pkg.core`,
   `lc_ctrl_state_pkg.core`, `otp_ctrl_pkg.core` all name `lc_ctrl`;
   `prim_ascon.core` names `ascon`; `trans_intg.core` names
   `tlul_payload_chk`) failed elaboration as
   `Unable to find the root module`. The driver now validates `-s`
   roots against the generated source list, substitutes the core's own
   module when one matches, roots the core's own-directory modules
   otherwise, and gives package-only lists a synthetic empty root so
   the packages still compile. All five cores now `PASS`.
2. Simulation harness cores (`ibex_top_tracing` with its `$fwrite`
   tracer, `prim_crc32_sim`, `otbn_top_sim`) were pushed through `-S`
   in rtl-v29 and failed as unsynthesizable. The driver's inventory
   predicate (landed with PR #150) now excludes `*_sim`/`*_tracing`
   cores from the synthesis lane; they are exercised by the simulation
   lanes instead.
3. Pinned-revision upstream source/metadata defects are now classified
   `UPSTREAM_INVALID` with an evidence note, and only when *every*
   hard diagnostic matches the recorded fingerprint — any new failure
   mode still surfaces as `FAIL`. The sixteen records at
   `7a3ad34`: `ascon` (enum assignment without cast, IEEE 6.19.3,
   slang rejects identically), `aes_wrap` (overlapping continuous
   drives of `h2d_intg`, IEEE 10.3, slang rejects identically),
   `otp_ctrl_top_specific_pkg` ×2 (fileset omits
   `otp_ctrl_macro_pkg`), `englishbreakfast rstmgr` (fileset omits
   `alert_handler_pkg`), `flash_ctrl_prim_reg_top` ×2 (fileset omits
   tlul adapter/integrity and `prim_reg_we_check`),
   `prim_dom_and_2share` (fileset omits prim `xor2`/`flop_en`),
   `tlul_lc_gate`, `tlul_request_loopback` (fileset omits instantiated
   tlul/prim providers), and six setup-phase records whose
   dependencies or targets do not exist at the pinned revision
   (`ibex_riscv_compliance`, `tb_cs_registers`,
   `ibex_simple_system_cosim`, `i3c`, `chip_earlgrey_cw340`,
   `chip_englishbreakfast_cw305`).
4. The eight `COMPILE_TIMEOUT` and three `DEBT` records of census
   rtl-v29, and the entire `always_*`/latch/async-process and
   chip/ast typed-assignment-pattern failure families, were already
   closed by the dual-control DFF work (PR #150); the census binaries
   predated it.

Follow-up findings at the same revision: the englishbreakfast autogen
top declares `SramCtrlMainInstSize = 4096` with
`SramCtrlMainNumRamInst = 1`, which is internally inconsistent for its
main SRAM (32 instances would be needed; earlgrey uses
`InstSize = 131072` and is consistent). Only an `ASSERT_INIT` that
`-DSYNTHESIS` strips guards the relation, so the
`sram_ctrl`/`prim_ram_1p_scr` cfg ports genuinely mismatch
(416 vs 13 bits) — classified `UPSTREAM_INVALID` on both
`top_englishbreakfast` and `chip_englishbreakfast_verilator`. The
driver's englishbreakfast mapping core now also pins
`lc_ctrl_token_pkg` to the earlgrey testing constants so FuseSoC's
virtual-core selection is deterministic (it previously grabbed the
darjeeling variant and emitted a non-determinism warning that polluted
those records with `DEBT`).

None of this is a compiler accommodation: every `UPSTREAM_INVALID`
fingerprint records a defect other tools reproduce or a fileset that
cannot elaborate anywhere.

With these classifications the full rtl census at `7a3ad34` reports
**zero FAIL, zero DEBT, zero timeouts**: every one of the 264 rtl
records is `PASS` (93), `DEPENDENCY_ONLY` (153), or an evidence-backed
`UPSTREAM_INVALID` (18).

---

## G54 — symbol-search cache keyed on AST node address caused silent method mis-dispatch — **fixed** [general] (was ⚠ silent)

The elaboration symbol-search cache keyed its entries on the ADDRESS of
the caller's `pform_scoped_name_t` path object. PExpr nodes are created
and deleted during elaboration, so a later AST node can be allocated at
a freed node's address; the cache then returned the earlier, unrelated
query's result. Observed in the OpenTitan `adc_ctrl` SVA graph:
`intr_state_fld.predict(predict_val, .kind(UVM_PREDICT_READ))` in
`dv_base_reg_field.sv` resolved to the neighboring
`uvm_reg_field::get_access` (looked up seven lines earlier), producing
`Too many arguments (2, expecting 1)` / ``No argument called `kind` ``.
The failure was input-layout dependent — the 261-file source list
reproduced it deterministically, but no 1-minimal subset did, because
removing any file shifted heap reuse — and the same mechanism could
just as well have bound a WRONG method silently with a compatible
arity, making this the worst diagnostic class.

The cache key is now the query content: scope, prefix flag, and the
interned component names of the path. Paths carrying index expressions
are not cached at all, because their results embed expression pointers
whose lifetime a content key cannot guarantee. Only positive results
were and are cached. Compile time on the 261-file SVA graph is
unchanged (~3 s). The `Too many arguments` diagnostic now names the
resolved function scope, which is what exposed the mis-dispatch.
Witness: `sv_method_call_cache_identity` plus the adc_ctrl SVA census
record going from FAIL to zero hard errors.

## G55 — standalone SVA jobs cannot bind `tb.dut` references — **fixed** (matrix driver)

OpenTitan SVA collateral is written for the dvsim simulation topology
(`module tb` containing the IP instance `dut`); assertion interfaces
reference `tb.dut...` hierarchically, and upstream's own `formal`
fusesoc targets mix those DV files with `toplevel: <ip>`, which no
strict elaborator can satisfy. The census driver now wraps the declared
SVA top in a generated `tb`/`dut` pair (unless the sources already
declare `tb`), reproducing the topology the collateral was written for.
`adc_ctrl_sva` goes from a hard bind failure to zero errors (its
remaining 133 UVM compile-progress warnings are the M14B debt), and
`prim_keccak_fpv` stays PASS under the wrapper.

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
