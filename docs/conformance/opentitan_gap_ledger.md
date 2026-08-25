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

The first clean-corpus micro replay at that revision was recorded on
2026-08-08 from a detached worktree whose pre/post status (including ignored
files) was empty. `lowrisc:ip:soc_dbg_ctrl_decode:0.1` in the RTL lane and
`lowrisc:prim:max_tree:0` in the SVA lane compile/elaborate with zero hard or
debt diagnostics. Those lanes do not execute synthesis equivalence or assertion
semantic oracles, so they are **PARTIAL frontend evidence**, not closure. The
clean `lowrisc:dv:tl_agent_sim:0.1` UVM replay is documented in G67. All 131
older JSON reports found in the inherited workspace record
`opentitan_dirty=true`; they remain useful for discovery but are not
clean-corpus evidence.

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

Backbone of OpenTitan's multi-bit control hardening (`mubi4_bool_to_mubi`,
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

## G10 — variable-length implication antecedents — **supported by NFA endpoint fan-out**

*16.9.2 / A.2.10. [general]*

The original campaign rejected every variable-length antecedent:

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

**2026-08-24 closure:** antecedent matching and consequence execution now use
separate NFA pools. Every accept endpoint of a variable-length or combinator
antecedent allocates its own consequence record, so one consequence verdict
cannot clear a later sibling endpoint. Overlapped records consume the endpoint
tick; nonoverlapped records start on the next sampled tick. Per-tick verdict
counters dispatch one action and success/failure callback per resolved record,
including coincident outcomes; step callbacks remain once per checker per tick.
A local assignment that occurs exactly once on a
deterministic leaf prefix is copied into the record at allocation and remains
private while later antecedent attempts reuse their slots. A later prefix
assignment may read an earlier local through the structural no-call subset;
nonlocal operands are sampled Preponed and the local reads are substituted with
the current attempt/obligation carrier on the assigning edge. Calls, selected
local objects, self/future/unassigned dependencies, and unknown shapes stay
loud instead of resolving through a module-name collision. The audit uses all
declared property-local names, not only assignment destinations; the paired
`sva_endpoint_dependent_local_rhs_unassigned{,_collision}` negatives pin that
shadowing rule, and `sva_endpoint_dependent_local_rhs_future_collision` pins
the assigned-later case. Branch-local,
post-branch, repeated, duplicate, and interior-tree assignments also stay
loud. So does a read after any zero-inclusive continuation (`##0`, `##[0:n]`,
or `##[0:$]`) until same-edge captures precede their continuation guards;
lower-bound-one ranges remain admitted.
`endpoint_obligation_fanout_nfa_only`
pins mixed early-pass/late-fail and early-fail/late-pass outcomes for both
operators, multi-step and tree consequences, combinator antecedents, and local
snapshots. It is registered in the hard legacy and JSON ivtest manifests and
also pins two live strong consequences producing `EOS_FAILURE 2`. Loop-free
shapes have a compile-time exact capacity bound;
unbounded/cyclic shapes retain the NFA engine's finite pool with a loud
run-time overflow diagnostic rather than merging or silently dropping an
endpoint. Empty consequences remain a loud residual. Parameter-valued bounds
remain governed by the focused M9-15 path. The exact local-topology boundary
is pinned by `sva_endpoint_{branch,fused}_local_{antecedent,consequence}`, the
bounded/unbounded zero-inclusive negatives, and the dependent-RHS call
negative;
`m12_endpoint_fanout_cb` pins run-time success/failure and strong-end failure
callback multiplicity. `m12_endpoint_fanout_step` pins `|=>` antecedent
StepSuccess on the endpoint tick while an older consequence failure coexists.

This is no longer an endpoint-merging blocker for `prim_alert_receiver` or
`prim_diff_decode`.

## G11 — sequence combinators as an implication operand — **partial**

*A.2.10. [general]*

```systemverilog
assert property (@(posedge clk) (a or b)  |-> c);          // supported
assert property (@(posedge clk) (a and b) |-> c);          // supported
assert property (@(posedge clk) a |-> (b or c));           // supported
assert property (@(posedge clk) (a or b) |-> (c or d));    // syntax error
```

Current implication productions accept an `sva_property_t` combinator tree on
either the antecedent or consequence side when the opposite operand uses the
sequence-expression carrier. `tree_implication_nfa_only` pins both directions;
`endpoint_obligation_fanout_nfa_only` additionally proves that a combinator
antecedent can launch independent multi-step obligations from all of its match
endpoints. A combinator tree on **both** sides still has no grammar production
and remains a loud syntax residual.

## G12 — the other property-expression consequents — **open**

*A.2.10.* `a |-> always b`, `a |-> nexttime b`, nested `a |-> (b |-> c)`.
G8 deliberately sidesteps the general case with dedicated op types; these need
the real nested-consequent field in `sva_property_t`.

## G13 — non-literal cycle-delay bounds — **partial (focused subset)**

*16.9.2.* `##[SkewCycles+2:SkewCycles+3]` where the bounds are parameters
rather than literals:

**2026-08-08 update:** supported focused implication/cover forms now retain
parameter expressions to instance elaboration rather than folding declaration
defaults. Overrides size each checker independently; negative, X/Z, and
reversed finite bounds fail elaboration. General symbolic compositions,
including standalone `a[*LO:HI]`, remain loud unsupported.

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

*[general] — bounded-termination/performance defect.*

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
and no leaked descendant. This closes the bounded-termination and
synthesis-conformance defect.

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
their independent diagnostic debt is recorded separately.

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
with exit 0, zero hard errors, and zero semantic debt.

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
in 21.432 seconds, with exit 0, zero hard errors, zero semantic debt, and no
timeout.

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
gaps; the old whole-array assertion is absent.

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
debt, and no timeout.

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
errors, zero semantic debt, and no timeout.
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
errors, zero semantic debt, and no timeout.

## G38 — loop-expanded packed-field writes were widened after synthesis — **fixed** (current upstream campaign)

*9.2.2.2 / 10.6 / 11.5 / synthesis lowering [general] — exact write coverage and process ownership.*

The v29 whole-RTL census completed all 267 candidates at the pinned upstream
revision: 58 `PASS`, 153 `DEPENDENCY_ONLY`, 39 `FAIL`, 8
`COMPILE_TIMEOUT`, 6 `SETUP_FAIL`, and 3 `DEBT`. Its 209 non-pass records
partition exhaustively into 11 compiler/IEEE defects, 12 synthesis-lowering
defects, 3 semantic-debt records, 8 bounded timeouts, 22 provider/source-list/
top-selection harness defects, and 153 dependency-only cores. The highest-
multiplicity synthesis family was a false bit-level-latch rejection in eight
standalone cores and three larger top-level witnesses.

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
error. The compiler engine fingerprint is
`287c40f65ff77e90c2c7c50521fa6d2ea0f95587f6461f70e09c510b4cae8cd0`.

The companion exact replays remain bounded non-pass evidence, not clean-corpus
claims. CSRNG 0.1 produces no diagnostic before its 600.077-second compile
timeout. Darjeeling and Earl Grey likewise time out after 600.566 and 600.261
seconds; English Breakfast advances to the separately classified `pinmux`
asynchronous-load synthesis rejection in 253.606 seconds. None of those four
logs contains the former packed-loop/latch diagnostic.

## G39 — loop-index-constant reset branches were mistaken for asynchronous data loads — **fixed** (current upstream campaign)

*9.2.2.4 / constant folding / synthesis lowering [general] — contextually constant reset selection in unrolled procedural loops.*

The v33 whole-RTL census completed all 267 candidates at OpenTitan revision
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19`: 63 `PASS`, 153
`DEPENDENCY_ONLY`, 31 `FAIL`, 9 `COMPILE_TIMEOUT`, 6 `SETUP_FAIL`, and 5
`DEBT`. Its 204 non-pass records partition exhaustively into 11 compiler/IEEE
defects, 4 synthesis-lowering defects, 5 semantic-debt records, 9 bounded
timeouts, 22 provider/source-list/top-selection harness defects, and 153
dependency-only cores.

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
seconds; both exit 0 with zero hard errors, zero semantic debt, and no timeout.
The compiler engine fingerprint is
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
drivers. The record contains no pinmux asynchronous-load diagnostic. Its JSON
and Markdown evidence are under
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
harness defects, and 153 dependency-only cores.

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
gap, each with six unique hard diagnostics after deduplication. This focused
replay proves the parser family is retired, not that the larger cores are clean.

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

First full SVA census (sva-v1, 128 records): 92 PASS, 28 FAIL, 4
DEPENDENCY_ONLY, 2 DEBT, 1 SETUP_FAIL, 1 UPSTREAM_INVALID. First
classified family: the three `rv_core_ibex_sva` cores connect
`tlul_assert` to `tl_i_o`/`tl_i_i`/`tl_d_o`/`tl_d_i`, signals that do
not exist in the pinned `rv_core_ibex.sv` (its TL ports are
`cfg_tl_d_i`/`cfg_tl_d_o`) — stale upstream bind collateral, now
`UPSTREAM_INVALID`. The remaining families (fpv wrapper multi-drivers,
pinmux_fpv assignment-pattern typing, aes_sva property grammar,
keccak_2share case grammar, i2c_sva `$root()` r-values, otp_macro /
top_*_pkg / prim_alert-tb source gaps, sha3 `.*` port skew) are the
open SVA work queue, each to be slang-differentialed before
classification.

---

## G56 — `$root`-prefixed hierarchical references unsupported — **fixed** [general]

The front end had no `$root` handling (IEEE 1800-2017 23.8): in
expression position the lexer's SYSTEM_IDENTIFIER made
`$root.tb.dut...q` parse as a system function call `$root()` followed
by member access. A new primary rule maps `$root '.'
hierarchy_identifier` onto the ordinary hierarchical-reference path.
OpenTitan `i2c_sva` (`` `define I2C_HIER $root.tb.dut.i2c_core ``)
goes from FAIL to PASS with zero errors and zero debt. Test:
`sv_root_hierarchical_ref`.

## G57 — statement attributes and gate outputs driving variables — **fixed** [general]

Two elaboration-blocking gaps exposed by the chip-level SVA graphs:

1. `always (* xprop_off *) @( * )` failed to parse. IEEE A.6.4 puts
   `{attribute_instance}` in front of every statement_item; the plain
   `always` spelling now consumes them like `always_comb`/`always_ff`
   already did. Test: `sv_always_stmt_attribute`.
2. A gate primitive output could never drive a variable ("Gates can
   never have variable output ports"), rejecting the OpenTitan AST
   models' `buf #(RDLY, FDLY) b1 (logic_var, expr)`. IEEE 6.5 allows
   one primitive output as a variable's single continuous source;
   slang accepts the same shape. The gate-output path now uses the
   same variable-to-uwire promotion as continuous assignments, so
   procedural conflicts still error. Value-checked test:
   `sv_gate_output_variable`.

## G58 — `bind` to a bare target instance unsupported — **fixed** [general]

`bind i_nopass1 prim_fifo_sync_assert_fpv ...` (IEEE 23.11
bind_target_instance) was rejected with "bind target
module/interface 'i_nopass1' is not defined". When the target names no
module, `pform_apply_binds` now searches the parsed instantiations for
that instance name, derives the target module from the unique match,
and binds through the existing plain-name instance filter (ambiguous
names across different module types are an explicit error). OpenTitan
`prim_fifo_sync_fpv` goes from FAIL to PASS with zero errors and zero
debt. Value-checked test: `sv_bind_target_instance` (asserts the
checker lands only in the named instance).

## G59 — SVA census closure: build-mode defines and 24 upstream-invalid records

`aes_sva` needs the `EN_MASKING` build-mode define that dvsim passes
with `+define+`; the census now carries a per-core `SVA_EXTRA_DEFINES`
table mirroring the DUT's default parameterization, and `aes_sva` goes
from FAIL to PASS. Every remaining sva-v1 failure was classified
`UPSTREAM_INVALID` under an exact, per-record-validated diagnostic
fingerprint: stale rv_core_ibex bind collateral (×3), pinmux_fpv
assignment patterns in equality (×2, slang concurs), overlapping FPV
testbench drivers (`prim_lfsr_fpv`, `prim_packer_fpv`,
`rv_timer_fpv`), the syntactically broken `keccak_2share_fpv` (slang
concurs), `otp_macro.sv`'s reference to the nonexistent
`u_state_regs.err_o` (4 system cores), stale `.*` FPV wrappers
(`sha3_fpv`, `sha3pad_fpv`), missing bind-target filesets
(`otp_ctrl_sva` ×2, `prim_alert_rxtx_*_fatal_fpv` ×2), missing
top-package dependencies (`pinmux_chip_fpv` ×3), englishbreakfast
collateral referencing registers its autogen tops lack (`rstmgr_sva`,
`clkmgr_sva`), darjeeling `pinmux_tb` overriding a parameter its
pinmux no longer declares, and `spi_host_sva`'s formal target
requesting a fileset the core never defines (setup phase).

## G60 — a nearer class property could not shadow an outer class-typed name — **fixed** [general]

`pform_test_type_identifier()` walked scopes checking only typedefs and
package imports; a class property or local variable whose name matches
an outer class name (a self-named wrapper, e.g. `max_delay_cg_obj
max_delay_cg_obj[string]`) was never checked for shadowing, so every
later use of the name kept resolving as a type reference instead of
the property. IEEE 1800-2017 6.18 says a nearer declaration of any
kind hides an outer one with the same name. OpenTitan
`xbar_env_cov.sv`'s `max_delay_cg_obj[key] = new(...)` parsed as a
type-cast/declaration attempt instead of an indexed variable
reference, producing a cascade of syntax errors through the class
body. `pform_test_type_identifier()` now checks the current scope's
wires and (for a class scope) its declared properties before
consulting typedefs and imports. Test: `sv_class_var_shadows_type`.

## G61 — `const` declarations after the first block item, and assignment-pattern defaults — **fixed** [general]

Two UVM-lane parser/elaboration gaps, both hit by every OpenTitan
`dv`/`env` package in the first full uvm-v1 census:

1. `statement_item` had plain (non-`const`) alternatives for a
   `data_type` declaration appearing after another declaration or
   statement in a procedural block, but the only `const` alternative
   in that position required a user-defined `TYPE_IDENTIFIER` — a
   `const` of a keyword-spelled type (`const int`, `const string`) or
   a package-scoped type never matched that rule and fell through to
   "Syntax in assignment statement l-value." A `const` declared FIRST
   in a block was fine (it still matched via `block_item_decl` before
   the parser committed to the statement-list path); only a `const`
   after some other declaration or statement needed a rule. Two new
   `K_const` alternatives mirror the existing non-`const` ones.
   `lc_ctrl_scoreboard.sv`'s `process_otp_prog_rsp()` task (three
   ordinary locals, then `const string MsgFmt = ...`) goes from a
   syntax error to compiling clean.
2. IEEE 1800-2017 10.9: an assignment pattern has no self-determined
   type — it takes its type from context. A default port/argument
   value (`= '{...}` in a formal declaration) has no surrounding
   expression to supply that context. The packed case
   (`check_lc_outputs(lc_outputs_t exp_o = '{default: lc_ctrl_pkg::Off},
   ...)`) failed outright ("An assignment pattern needs a context that
   gives it a type"). The unpacked-array case
   (`set_nvm_rma_ack(lc_tx_t val, int delay_lens[NumRmaAckSigs] =
   '{default: 0})`) was worse: a fixed unpacked-array port's
   `NetNet::net_type()` returns only its ELEMENT type (the complete
   type including dimensions is `array_type()` — the same distinction
   the existing explicit-argument path at the call site already
   documented), so elaborating the default against `net_type()` built
   a scalar value; the call-site default-argument path then
   unconditionally padded that value to the port's scalar element
   width, corrupting the resulting array pattern and crashing the vvp
   code generator (`store_vec4_to_lval` assertion) the first call that
   actually used the default. Port defaults are now elaborated against
   `array_type()` when the port has unpacked dimensions, and the
   call-site padding is skipped for such ports (matching the
   already-correct explicit-argument path, which was never broken).
   Value-checked test: `sv_default_arg_assign_pattern`.

## G62 — the symbol-search cache outlived a transient iterator-name alias — **fixed** [general] (regression in G54)

G54's content-keyed symbol-search cache fixed a freed-AST-pointer
staleness bug, but it introduced a narrower one of the same species:
`NetScope::set_signal_alias()` temporarily rebinds a name (e.g. the
default `item` iterator of an IEEE 1800-2017 7.12.4
array-manipulation-method `with` clause) directly in a scope's live
signal map for the duration of one predicate's elaboration, then
`restore_signal_alias()` puts back whatever was there before. The
cache has no visibility into that mutation, so a resolution of `item`
computed and cached during one `with` clause survived into a second,
unrelated `with` clause later in the SAME enclosing scope that reused
the same default iterator name — handing it the first clause's
already-popped iterator net. The call form of the index query
(`item.index()`/`item.index(1)`, which looks its net up by exact
identity in a small context stack) failed outright on the stale net
("Object ... has no method \"index(...)\""); this was caught by CI's
UVM regression count dropping from 337 to 336 (`g10_iter_index_test`),
not by `ivtest`, which has no test that reuses a `with`-clause
iterator name twice in one scope.

`set_signal_alias()`/`restore_signal_alias()` now call
`symbol_search_cache_clear()` on every alias install and restore.
Aliasing is rare relative to ordinary elaboration, so an unconditional
full clear is cheap and — unlike trying to identify exactly which
cache entries an alias could have touched — always correct. Value-
checked test: `sv_iter_ctx_cache_stale`, reduced from
`tests/g10_iter_index_test.sv`. `sv_method_call_cache_identity` and
`sv_class_var_shadows_type` (G54/G60, the fixes this cache also
serves) re-verified passing.

**Lesson for this codebase**: any cache keyed on scope/name resolution
must be invalidated by every mechanism that mutates a scope's binding
table out from under ordinary declaration order — `signals_map_`
aliasing is one; there may be others (parameter overrides, generate-
scope rebinding) worth auditing before the next cache is added here.

## G63 — a `randomize() with {...}` item that could not be translated was dropped with zero diagnostic — **fixed** [general] (was ⚠ silent)

`make_randomize_with_expr()`'s loop over top-level `with` block items
did `if (ir.empty()) continue;` whenever `pexpr_to_class_constraint_ir`
could not translate one item to solver IR — for example a `foreach`
constraint whose target is a plain (non-`rand`) property of the
*enclosing* class rather than the randomized object's own class (IEEE
1800-2017 permits a `with` block to reference enclosing-scope state;
resolving such a foreach target is not implemented). The `randomize()`
call still reported success, silently applying only the constraints it
could translate — no diagnostic anywhere. Found while investigating
OpenTitan `xbar_tl_host_seq.sv`'s
`req.randomize() with {... foreach (xbar_devices[device_id].addr_ranges[i])
{...} ...}` (a currently-unsupported hierarchical/indexed foreach
target — that specific shape remains a syntax error, intentionally
left loud rather than risking a new silent failure in a grammar that
`bison -Wconflicts-sr -Wconflicts-rr` already reports 500+ shift/reduce
and 1186 reduce/reduce conflicts for; see the note below).

Every dropped item now emits `warning: constraint '...' could not be
translated and is being ignored (compile-progress fallback)` at the
constraint's own line. This is a general fix: it covers every current
and future case where constraint-IR generation fails, not just the
foreach-target gap that surfaced it. Value-checked test:
`sv_randomize_with_unresolvable_dropped` (confirms the warning fires,
the call still completes, and the resolvable sibling constraint is
still enforced).

**Note on the still-open gap**: fully supporting hierarchical/indexed
constraint-`foreach` targets needs more than a grammar change —
`PEConstraintForeach` stores a bare property name and its IR generator
(`elaborate.cc` ~16735) resolves it only against the randomized
object's own class via `property_idx_from_name()`; the enclosing-scope
case needs real hierarchical-path storage and cross-scope property
resolution. A minimal PARSE-only fix was considered and deliberately
not attempted: a debug-instrumented trace this session found that a
structurally similar existing production for *ordinary* (non-
constraint) `foreach` statements with a mid-chain index
(`foreach (h[idx].v[i])`, parse.y ~4594) compiles clean but the
resulting `PForeach` node never reaches `elaborate_scope()` or
`elaborate()` at all — a silent zero-iteration bug, most likely from
this exact grammar's conflict density swallowing that alternative.
Adding another similar production for the constraint context risks the
same failure mode. Both gaps are tracked for a dedicated pass (bison
`-Wcounterexamples` analysis first) rather than a rushed fix.

## G64 — `q[$-N]` queue index arithmetic unsupported — **fixed** [general]

IEEE 1800-2017 7.10.1: within a queue index expression, `$` stands for
the queue's top bound (`size()-1`) and may be combined with ordinary
arithmetic — `q[$-1]` names the second-to-last element, `q[$-N]` for a
variable `N` the `(N+1)`-th from the end. Only the bare `q[$]` form was
supported (`SEL_BIT_LAST`, parse.y ~10549); `q[$-N]` fell straight
through to a syntax error. Reduced from OpenTitan
`gpio_scoreboard.sv`'s `data_in_update_queue[$ - 1].needs_update`.

`SEL_BIT_LAST` has 17 separate consumer sites across
elab_expr.cc/elab_lval.cc/elaborate.cc (lvalue, rvalue, and sizing
paths). Rather than teach every one of them a second "relative to
last" selector kind — a wide, easy-to-miss-one surface, and this
session already spent real effort recovering from one under-scoped
change (G62) — the new grammar production
(`hierarchy_identifier '[' '$' '-' expression ']'`) rewrites the index
at PARSE TIME into the exactly equivalent ordinary index
`q[q.size()-1-<offset>]`, built on a duplicated copy of the base path
so the original indexed path is untouched. This reuses the
already-correct plain-`SEL_BIT` machinery instead of adding a new one,
touching zero elaboration sites. Verified the new production adds no
grammar conflicts (`bison -Wconflicts-sr -Wconflicts-rr`: 551
shift/reduce, 1186 reduce/reduce, identical before and after — unlike
the untouched G63 gap, this one was checked before committing to it,
given the direct evidence from this same file that this grammar can
silently swallow a structurally similar production).

Confirmed on the real OpenTitan job: `gpio_scoreboard.sv`'s `[$-1]`
error is gone; the file now advances to later, unrelated gaps
(multidimensional associative-array indexing in the same scoreboard,
`Got 2 indices, expecting 1`). Value-checked test:
`sv_queue_dollar_arithmetic` (literal and variable offsets, a compound
offset expression `$-(i+1)`, both read and lvalue-write forms, and
confirms the pre-existing bare `q[$]` form is unaffected).

## G65 — `foreach (a[k].b[i])` was a stub that silently discarded the loop body — **fixed** [general] (was ⚠ silent)

IEEE 1800-2017 11.7 extended to a hierarchical target:
`foreach (a[k1,...].b[i1,...])` declares a FRESH loop variable per
bracket group and iterates every combination — there is no standard
"fixed outer index, loop the inner dimension" reading for a bare
identifier in the outer bracket (that needs a genuine expression,
e.g. `a[k+0].b[i]`, to disambiguate from a loop-variable declaration;
confirmed against slang, which accepts `h[idx].v[i]` and — per the
LRM, the only legal reading — treats `idx` as a fresh loop variable
shadowing any outer one of the same name).

The grammar production for this shape (parse.y, `K_foreach '('
foreach_array_identifier '[' loop_variables ']' '.'
foreach_array_identifier '[' loop_variables ']' ')'`) was a
DOCUMENTED STUB: its comment read "these still elaborate as
hierarchical targets and currently fall back to the existing warning",
but the action built no `PForeach` node at all and did
`delete $14;` — unconditionally discarding the parsed loop body — then
called `pform_requires_sv()`, which is a **silent no-op** once
SystemVerilog mode is active (true for virtually all real input), and
incremented an internal `warn_count` that is never printed anywhere.
Net effect: the construct compiled clean and executed zero times, with
no diagnostic in the common case. Reduced from OpenTitan
`xbar_env_pkg.sv`'s `foreach (xbar_devices[i].addr_ranges[j])`.

Implemented for real by lowering to nested `foreach` statements —
`foreach (a[k1,...]) foreach (a[k1,...].b[i1,...]) BODY` — so each
level reuses the already-correct single-target elaboration path
(`pform_make_foreach`/`PForeach`) instead of adding a second one. The
outer loop variables are declared with `pform_make_foreach_declarations`
typed against `a`'s own dimensions (as usual); the inner loop
variables are typed against the combined, unindexed path `a.b` (a
dimension's shape does not depend on which element of `a` is
selected); the inner target is built by appending one `SEL_BIT` index
component per outer loop variable — each referencing that
variable — to a copy of `a`'s path, followed by `b`'s own components.

This exposed a second, general bug: `Design::find_signal()` — whose
own contract for every other kind of miss is "return 0, say nothing"
(callers, prominently `PForeach::elaborate()`, use it to PROBE whether
a hierarchical name is a signal, falling back to ordinary expression
elaboration when it is not) — hard-errored
("Scope index expression is not constant") when a path prefix's index
was a plain runtime variable rather than a module/generate-block
instance selector, because it unconditionally tries `eval_scope_path`
first. `eval_scope_path`/`eval_path_component` now take an optional
`quiet` parameter (default `false`, preserving the diagnostic for
every genuine scope-path caller) that `find_signal` passes as `true`,
matching its own established silent-miss contract.

Verified the new grammar production changes bison's conflict counts by
zero (551 shift/reduce, 1186 reduce/reduce, identical before and
after) before committing to this approach. Confirmed on the real
OpenTitan job: `xbar_env_pkg.sv`'s errors are gone;
`top_darjeeling_xbar_dbg_sim` advances to the unrelated `xbar_tl_host_seq.sv`
constraint-`foreach` gap (G66) and an unrelated `xbar_error_test.sv`
parse error. Value-checked test: `sv_foreach_hierarchical_dual_dim`
(all six iterations of a real 2×3 double-dimension case, plus a
loop-variable-name-shadows-an-outer-variable case confirming the outer
variable is genuinely unaffected).

---

## G66 — `foreach` over a hierarchical target inside a `randomize() with {...}` constraint — **fixed** [general] (was a hard syntax error)

`foreach (array_name[prefix].member_name[loop_var])` as a constraint
item — the same hierarchical-target shape G65 fixed for an ordinary
statement — was a hard syntax error inside a `constraint`/`with`
block. Reduced from OpenTitan's auto-generated
`xbar_env_pkg__params.sv` / `xbar_tl_host_seq.sv`:
`foreach (xbar_devices[device_id].addr_ranges[i]) { ... }` inside a
`randomize() with {...}` call, where `device_id` is itself a `rand`
property of the class being randomized, not a fresh loop variable.

Root cause was the exact same LALR(1) lookahead ambiguity as G65: the
grammar production's prefix bracket was originally typed as
`expression` (to parse an index like `device_id`), but a bare
`IDENTIFIER` there is indistinguishable — with one token of lookahead
— from a fresh loop-variable declaration via the `loop_variables`
nonterminal, and bison always wins that race by reducing to
`loop_variables` before it can see the following `.` that would
disambiguate. Confirmed definitively with `IVL_PARSE_TRACE=1` on a
minimal repro (`foreach (lookup[idx].size[i])`): the parser reduces
the bare `idx` to `loop_variables` (rule 499) immediately on seeing
`]`, so the `expression` alternative was dead grammar — never
reachable for exactly the real-world case (a bare identifier prefix)
that matters.

Fixed the same way as G65: the prefix bracket is now parsed through
`loop_variables` for both positions, and `PEConstraintForeach`
(PExpr.h/PExpr.cc) stores the prefix as `std::vector<perm_string>
prefix_names_` — names that reference already-declared variables, not
fresh declarations — instead of a single `PExpr*` index. Verified the
new grammar production changes bison's conflict counts by zero (551
shift/reduce, 1186 reduce/reduce, identical before and after) before
committing to this approach.

Full semantic resolution of the iterated array when it is not a rand
property of the object being randomized (the real OpenTitan case:
`xbar_devices` lives in an enclosing package, not in the class doing
`randomize()`) remains a separate, larger gap — the constraint-IR
generator's `foreach` lowering fundamentally requires the array's
element count to be a compile-time constant it can resolve from
either the scope-form or the object's own rand-property table, and
neither currently walks out to package or enclosing-object scope.
Rather than guess, `elaborate.cc`'s `PEConstraintForeach` IR-generator
branch now checks `cfe->has_hierarchical_target()` and returns `""`
unconditionally in that case — which the caller
(`make_randomize_with_expr`, fixed to warn rather than silently drop
in G63) already reports as a loud compile-progress warning naming the
dropped constraint text, rather than either a syntax error or a
silent semantic no-op. `randomize()` still completes normally with
the rest of the constraint block intact.

Value-checked test: `sv_constraint_foreach_hierarchical` (parses and
runs to completion with the expected drop-warning; a class-scoped
`rand` selector, `device_id`, selects one element of an array of
class-typed handles before iterating a `rand` array member of the
selected element — the same two-level shape as the real OpenTitan
constraint).

---

## G67 — lazy subroutine elaboration inherited a caller's `fork` depth — **fixed** [general] (was a false hard error)

A clean pinned `lowrisc:dv:tl_agent_sim:0.1` UVM compile reported nine
primary errors in `uvm_registry.svh` saying that ordinary function/task
`return` statements were inside a fork, followed by four secondary
elaboration errors. The UVM subroutines contain no fork. OpenTitan first uses
`tl_device_seq#()::type_id::create()` from a `fork ... join_none` branch;
that nested typedef can cause the cached parameterized registry class to be
fully elaborated only while the caller branch is being elaborated.

The compiler kept fork depth as `Design` state. `PBlock::elaborate` entered
the caller fork, the lazy class-specialization path directly elaborated every
method body, and `PReturn::elaborate` therefore saw the caller's lexical depth.
IEEE 1800-2017 9.3.2 prohibits a return written within a fork-join block; it
does not move a separately declared callee body into its caller's lexical
fork. Slang 11.0.415 accepts the 16-line reduced legal case and rejects the
direct return-inside-fork control.

`PFunction::elaborate` and `PTask::elaborate` now use a scoped guard that
starts each definition body at fork depth zero and restores the caller depth
on every exit. A fork written inside that body still increments normally, so
the original illegal case remains an exact-gold compile error. The positive
`sv_fork_lazy_param_typedef_return` test first specializes a nested registry
typedef in a caller fork and value-checks both its function and task; the
existing `task_return_fail2` now pins the negative diagnostic exactly.

Clean-corpus replay at OpenTitan
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19` changed the same
`tl_agent_sim` job from compile exit 13 / 13 hard errors to compile exit 0 /
zero hard errors. Its matrix status is still **DEBT**, with 63 explicit
compile-progress/backend diagnostics exposed after code generation completed;
this is compile/elaboration evidence only, not UVM semantic or runtime
closure. The fixed-run JSON SHA-256 is
`5fd7fd4141dfcde7cc5b3b0fc816c109fbd0272704cb52a5df3e10f4cea4d493`,
and the installed `ivl` engine SHA-256 is
`dcdb6c637c383fb8cffb5bb5251e209321017ff7a43de557d97b0074d7724116`.
The detached corpus was clean before and after the serial run.

---

## G68 — nested-VIF packed-field NBAs executed as blocking assignments — **fixed subset** [general] (was a loud semantic fallback)

The clean G67 `tl_agent_sim` compile exposed 13 target warnings at
`tl_device_driver.sv:26,74-82` and `tl_host_driver.sv:134,366-367`. Each
legal nonblocking assignment targets a constant packed-struct field through a
nested virtual-interface receiver such as `cfg.vif.d2h_int.d_valid`. Generated
VVP used immediate `%store/prop/v/bits`, so the warning described a real
Active-region miscompile rather than cosmetic debt. IEEE 1800-2017 10.4.2
requires the RHS and receiver to be evaluated when the statement executes and
the update to occur later in NBA (or Re-NBA for a program process).

`%assign/prop/v/bits` now captures the selected receiver and self-sized RHS.
Its scheduler event reads the current containing property and merges the
constant field only when the event runs. Event-time RMW is essential: taking a
whole-property snapshot at statement execution would make simultaneous
disjoint field NBAs clobber one another. FIFO event order preserves later
overlapping writes as well as whole-property/field ordering. Both the existing
whole-property event and the new field event select NBA versus Re-NBA from the
executing process. Unsupported dynamic/indexed, variable-delay, and
event/repeat-controlled property forms now terminate code generation with a
target error instead of falling back to blocking execution.

`sv_nba_property_field` value-checks Active/Inactive invisibility, disjoint and
overlapping merges, whole/field order in both directions, receiver and RHS
snapshots, the nested `cfg.vif` task shape, constant delay, nested-class wait
wakeup, and the underlying VIF signal event. `sv_nba_property_reactive` pins
Re-Inactive before Re-NBA and direct class-property mutation wakeup with a
finite watchdog. `sv_nba_property_dynamic_fail` pins one legal residual as an
exact nonzero diagnostic; Slang 11.0.415 accepts all three source shapes under
IEEE 1800-2017.

A serial replay from the clean detached OpenTitan worktree at
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19` stayed at compile exit 0 and zero
hard errors while semantic debt fell exactly 63→50. Raw diagnostics contain 61
warning lines, zero errors, zero `sorry`, and zero internal-error/crash lines;
the matrix remains **DEBT** and is compile/elaboration evidence only, not UVM
runtime closure. The report JSON SHA-256 is
`dc3511318325d0a2080af8360e9a98f00e8d60c00f3a00633a40b8010c6efcd7`;
the exact source-list SHA-256 is
`86dfb7eefe8ff65072b93d1e2b18e6d71234e70150df6afa3448a7ec0fa0451a`.
The installed driver/compiler/target/runtime hashes were unchanged before and
after; the target hash for this checkpoint is
`0dbc8a36e2790c8f04485ccc6a0fe5f7a44808904fd304e201bd0bfecbef38bb`.
Compiler diff and corpus status fingerprints were also unchanged across the
run, and the corpus remained clean including ignored-file status.

This is a fixed subset, not full property-NBA closure. Dynamic/indexed and
property-array targets remain loud, full root-net/VPI mutation callback
propagation is not proven, and null-receiver handling retains an older
nonconformant no-op behavior.

---

## G69 — function-contained persistent-target NBAs executed as blocking assignments — **fixed subset** [general] (was a loud semantic fallback)

The clean G68 `tl_agent_sim` compile retained nine frontend warnings at
`tl_device_driver.sv:111-119`. They are legal SystemVerilog nonblocking
assignments inside `invalidate_d_channel()`, a function whose targets are
constant packed fields of the persistent virtual-interface property
`cfg.vif.d2h_int`. IEEE 1800-2017 13.4.4 permits a function to schedule
background work because the function does not suspend; 10.4.2 forbids an NBA
to an automatic variable, not an NBA reached through a captured class or
virtual-interface receiver. The inherited fallback instead constructed
blocking `NetAssign` nodes and updated those fields in Active.

SystemVerilog function bodies now retain `NetAssignNB` and use the normal NBA
lowering, including M4C-8's receiver/RHS capture and event-time packed-field
merge. For direct vec4 locals and intra-assignment controls, the frontend
distinguishes inherited, explicit `static`, and explicit `automatic`
declaration lifetime before accepting a target/reference. It also marks any
function containing an NBA nonconstant before later elaboration can return, so
constant evaluation rejects the function rather than silently treating the
scheduled update as a no-op. IEEE-1364 function NBAs remain compile errors.

`sv_function_nba_persistent` value-checks Active and Inactive invisibility,
the eventual NBA value, two disjoint packed-field updates, receiver and input
snapshots across `cfg.vif` rebinding, an ordinary module target, and an
explicit-static local inside an automatic function. Exact diagnostic tests
retain rejection of inherited and explicit automatic locals, use of an
NBA-bearing function in a constant expression, and an IEEE-1364 function NBA
hidden under a named block. Slang 11.0.415 accepts the positive runtime shape
and rejects the illegal controls under IEEE 1800-2017. The durable differential
summary is workspace-root-relative
`evidence/function-nba-slang-20260808/SUMMARY.md`, SHA-256
`c52ce25981214f0986ce6aa4ce81c219f117dca3a47c6287bf6ed0ead3f64ae3`.

A serial replay from the clean detached OpenTitan worktree at
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19` stayed at compiler exit 0 and zero
hard errors while semantic debt fell exactly 50→41. The matrix runner exits 1
because the job remains **DEBT**; this is compile/elaboration evidence only,
not UVM runtime closure. The compile log contains 52 warning lines, zero error,
`sorry`, internal-error, or crash lines. The nine removed diagnostics are
exactly `tl_device_driver.sv:111-119`, with no additions. Report JSON SHA-256:
`2ffcb09c35d32cd8ddd0dc6c0a03c3b4a315788e88602de7604a97ee5357c7a5`;
compile-log SHA-256:
`709d4df75d691b284a9b1dd58b57306e157356be2e0e3da3e561c4bedd38886e`;
compiler source-list SHA-256:
`8731d9ab6a3959bd85cd930a07a50db463613b895fe3341b42a97aec1a732fc5`
(the raw generated list embeds its evidence-directory name); underlying
FuseSoC source-list SHA-256:
`9555d7985b5266b54399c22dc97e0f42d04fbe23793475313c78dfd126ac99f3`;
installed compiler-engine SHA-256:
`c1c3e9b251d116d8c226bf9cbd2aad134a32618e2bcad0b8caadf3fbee1a9346`.
Corpus status including ignored paths was empty before and after the run;
compiler diff/status fingerprints and every installed compiler component were
unchanged across it. The hashed JSON records the exact setup/compile commands
and complete driver/compiler/target/runtime fingerprints; evidence root:
workspace-root-relative
`evidence/opentitan-7a3ad34-a179a1010/uvm-tl-agent-function-nba`. Its exact
runner-command/provenance summary has SHA-256
`013f5c3fee8fd81d3cffc676a3888442d1bc68b8466db74a9510ae825f284310`.

This is not full 10.4.2/13.4.4 closure. Remaining work includes enforcing
eligible call origins beyond constant-expression use, dynamically sized array
and queue targets, legal automatic aggregates containing captured class/VIF
handles, and runtime evidence for program/Re-NBA and freshly allocated
function-local object receivers.

---

## G70 — queue self-concatenation observed a partially overwritten destination — **verified fixed subset** [general] (silent wrong result)

The clean pinned sv-tests baseline at
`c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7` exposed three silent queue
failures: `q = {q, 4}`, `q = {4, q}`, and
`q = {q[0:1], 10, q[2:$]}` compiled and ran with status zero, but lost most
of the original queue. A scalar-only permutation, `q = {q[1], q[0]}`, also
read the first newly written destination element while evaluating the second
operand. IEEE 1800-2017 7.10.4 explicitly gives `q = {q, value}` as the
assignment equivalent of `push_back`, and 10.10 defines the concatenated
result from the operand values. The destination therefore cannot change while
that right-hand value is being constructed.

The VVP target previously cleared collection-pattern destinations before
splicing operands, while its scalar-pattern path wrote each element as soon as
that operand was evaluated. Bounded scalar patterns additionally stopped
evaluating operands after the destination capacity was reached. Queue patterns
now use the existing object-context builder to create an unbounded temporary,
evaluate every operand exactly once before the destination update, append the
results in source order, and perform one typed `%store/qobj` copy. The final
copy applies the `[$:N]` bound, retains the leftmost `N+1` elements, warns for
the discarded tail, uses the existing typed element-copy policy, and sends
one completed-destination mutation notification. Existing adjacent tests pin
class-handle identity and aggregate value copying separately; a combined
side-effecting object-aggregate capture oracle remains residual work below.

`sv_queue_concat_snapshot` checks scalar self-swap, whole and sliced
self-splices, bounded-prefix retention, evaluation of a discarded tail
operand, and `wait` wakeup. `sv_queue_concat_type_fail` pins an incompatible
string-queue operand in an integer-queue concatenation as an exact compile
error; Slang 11.0.415 accepts the positive source and rejects the negative
under IEEE 1800-2017. The inherited vec4/real/string/packed-array bounded
queue golds intentionally move their static-pattern warning to the common
run-time whole-copy warning because a collection operand can make the result
size run-time dependent.

This is not full queue-reference closure. Direct queue/dynamic-array element
bindings now use stable cells and detach with their prior value when whole
assignment removes the element. An element reached through a class property
or other nested container receiver still takes the companion path, and
side-effecting object-backed aggregate operands still need a dedicated
capture-order oracle.
A clean pinned replay of all 923 self-contained tracked sv-tests cases moved
exactly `push_back_assign`, `push_front_assign`, and `insert_assign` from
`SEMANTIC_FAIL` to `VERIFIED_RUNTIME`: runtime-verified 157→160 and semantic
failures 17→14, with every other Icarus/Slang classification unchanged.
`results.json` SHA-256 is
`88274e0bf22a79075ee943bef4980b6fe99efab7b19d93448769fd8e76075bf4`;
the provenance summary at workspace-root-relative
`evidence/sv-tests-c4229f3/core-safe-queue-snapshot-a34dac77c/SUMMARY.md`
has SHA-256
`72e71deaf32eae65337eec0c171c9c1f9fc958f08ac125c25cba56365a366696`.
Serial project gates passed: `make -j1 check/install`, negative 104/104, SVA
50/50, VPI 94/94, UVM smoke 14/14, full UVM 337/337, legacy ivtest 3,480
passed / 0 failed (two NI and three expected-fail retained), and JSON/VVP
327/327. Clean OpenTitan `tl_agent` compile/elaboration remains DEBT at zero
hard errors / 39 unique warnings, and the four clean Caliptra
assertion-enabled `-tnull` witnesses remain zero-hard-error compile evidence
with warning counts 202/202/0/89; neither is a runtime-closure claim.

---

## G71 — `find_last*` returned all matches, so result `[0]` was not the last match — **verified fixed subset** [general] (silent wrong result)

The clean pinned sv-tests baseline at
`c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7` contained two zero-exit silent
failures. The dynamic-string-array `find-last` test expected one value but
received both matches; `find-last-index` expected the singleton index `{2}`
but received `{0, 2}`. IEEE 1800-2017 7.12/7.12.1 requires `find_last` and
`find_last_index` to return one element/index closest to the rightmost array
element, or an empty queue when no predicate match exists. Array-locator
traversal order is otherwise unspecified, so the fix and tests do not impose
a predicate call-count or side-effect order that the standard does not give.

The target loop previously treated `find_last*` like `find`/`find_index` and
appended every predicate match. It now distinguishes stop-on-match from
replace-the-current-result behavior. Queues and dynamic arrays therefore keep
only the last positional match; direct zero-minimum one-dimensional integral
fixed arrays also account for canonical storage versus declared direction, so
`find_first*` and `find_last*` retain their declared left/right meaning. The
frontend carries the concrete queue result type through the internal function
node and its duplication path. Direct assignment compatibility rejects an
incompatible queue or associative-array destination while preserving the legal
queue-result-to-fixed-array copy exception.

`sv_array_find_last` checks queue and dynamic-string results, typed empty
results, a descending fixed range, a locator queue assigned to a fixed array,
and an extracted OpenTitan-shaped class-property queue whose consumer uses
`[0]` of the assigned `find_last_index` result to obtain the newest pending
write. Exact-gold tests pin
incompatible direct result contexts and require the `with` clause plus an
optional positional iterator identifier. Legal but unimplemented associative
locators, nonzero-base/multidimensional/nonintegral fixed arrays, and fixed
arrays reached through a class property fail loudly instead of returning a
plausible wrong value.

The clean OpenTitan source graph at
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19` has the corresponding consumer in
`hw/dv/sv/mem_bkdr_scb/mem_bkdr_scb.sv:69-72`: its RAW-hazard scoreboard uses
element `[0]` of the assigned locator result as the latest write. The old
behavior could select the oldest matching pending write, which is a DV-oracle
correctness defect rather than a DUT defect. The relevant integration graph
selected for this checkpoint,
`lowrisc:dv:sram_ctrl_sim:0.1`, remained a failed clean compile gate: its
generated Icarus command omitted upstream `INSTR_EXEC` and
`SRAM_WORD_ADDR_WIDTH` definitions (three warnings and three hard errors), so
no OpenTitan DV runtime executed. Evidence summary SHA-256 is
`29d2ad19079bb07fdf63359aae39d554ef7771053d1eaeb8bd433bedea701dfa`
at workspace-root-relative
`evidence/opentitan-7a3ad34-a179a1010/uvm-sram-ctrl-find-last-index/SUMMARY.md`.

A clean safe-harness replay of all 923 self-contained tracked sv-tests cases
moved exactly `find-last.sv` and `find-last-index.sv` from `SEMANTIC_FAIL` to
`VERIFIED_RUNTIME`: runtime-verified 160→162 and semantic failures 14→12, with
all other 921 Icarus/Slang classifications unchanged. `results.json` SHA-256
is `dd98928a606ee9013365488efe3aad6931d08f1bcdab2d6c1a8c0baecd98c56c`;
the provenance summary at workspace-root-relative
`evidence/sv-tests-c4229f3/core-safe-find-last-20260808/SUMMARY.md` has SHA-256
`775decea897fa1a8a8627bb7d32be3f47aa0a8d834f8dbf2b3e023b6b633381a`.
Serial project gates passed: `make -j1 check/install`, negative 104/104, SVA
50/50, VPI 94/94, UVM smoke 14/14, full UVM 337/337, legacy ivtest 3,486
passed / 0 failed (two NI and three expected-fail retained), and JSON/VVP
333/333. Four clean Caliptra assertion-enabled `-tnull` witnesses again exited
zero with no hard/`sorry`/internal diagnostics and warning counts 202/202/0/89;
their summary SHA-256 is
`c78de511bc1b7102726c21940a33135c4a0fee1bd6ddf29285c89292311cd1bf`
at workspace-root-relative
`evidence/caliptra-bd316141/assertions-tnull-find-last-clean-20260808/SUMMARY.md`.
Both corpus replays used the same installed compiler artifacts as the sv-tests
replay, and no compiler source edit occurred between those runs. The common
source base/status/diff fingerprints are recorded in the hashed sv-tests
summary above; the per-corpus summaries independently record unchanged
installed-component hashes and clean corpus state before and after.

This is not full locator closure. Associative keyed iteration/index typing and
the broader fixed-array receivers above remain loud. Value-returning locators
over object-backed/unpacked-struct elements can still alias instead of making
the required element-value copy, and a nonconstant ternary or similar wrapper
can still lose the locator's concrete result type. The OpenTitan `_index`
oracle does not exercise that value-copy residual.

---

## G72 — parentheses-free dynamic-array/queue `min` and `max` returned the receiver — **verified fixed subset** [general] (silent wrong result)

The clean pinned sv-tests sources
`tests/chapter-7/arrays/associative/locator-methods/min.sv` and `max.sv`
(despite that directory name, both use dynamic arrays) exposed two zero-exit
silent failures. Their legal `result = values.min` and `result = values.max`
expressions produced the complete receiver rather than the one-element locator
result. IEEE 1800-2017 7.12 Syntax 7-5 makes the iterator-argument parentheses
optional, and 7.12.1 includes the corresponding parentheses-free `IA.min`
form. Pinned Slang accepted both sources; the Icarus runtime values were wrong.
This also corrects an earlier coverage assumption: parentheses-free reduction
tests did not exercise queue-valued parentheses-free `min`/`max` in a typed
aggregate context.

The typed `PEIdent` path previously resolved the receiver as a compatible
dynamic container and returned `NetESignal(values)` before consuming the
terminal method suffix. It now recognizes only an unindexed terminal
`min`/`max` on a direct queue or dynamic-array signal before that fallback,
then uses the existing explicit-call lowering. Width/type resolution and the
internal `NetESFunc` carry the concrete unbounded queue element type, and the
direct assignment checker rejects incompatible or associative contexts rather
than accepting every queue-shaped result. The unindexed-receiver guard is
essential: `array[0].min` and `array[0].max` remain ordinary element-member
accesses when those fields exist.

`sv_array_minmax_parenless` checks signed and unsigned integral dynamic arrays,
unbounded and bounded queues, empty results, explicit-call parity, compatible
queue/dynamic/fixed destinations, source immutability, and aggregate element
fields literally named `min`/`max`. `sv_array_minmax_type_fail` exact-golds
wrong queue/fixed element types and an associative destination.
`sv_array_minmax_residual_fail` exact-golds the current loud handling of legal
real/string dynamic-array and associative-array receivers; Slang accepts those
residual sources under IEEE 1800-2017. These tests establish only the direct
integral parentheses-free subset, not general array-locator closure.

A clean safe-harness replay of all 923 self-contained tracked sv-tests cases
completed all 1,846 serial Icarus/Slang jobs. Exactly `min.sv` and `max.sv`
moved from `SEMANTIC_FAIL` to `VERIFIED_RUNTIME`: runtime-verified 162→164 and
semantic failures 12→10, with every other Icarus, Slang, and differential class
unchanged. `results.json` SHA-256 is
`01d81039e88e9176eb0f87c285da55bb90f08cdba7d7062bafea9420c50300fe`;
the provenance summary at workspace-root-relative
`evidence/sv-tests-c4229f3/core-safe-minmax-20260808/SUMMARY.md` has SHA-256
`66db6efe7827166ea652f6fcb80a18d87c76c1b60e1a51b4f480e0f80fb493b0`.
Focused legacy and JSON tests passed 4/4 and 3/3. Serial project gates passed:
`make -j1 check/install`, negative 104/104, SVA NFA 50/50, VPI 94/94, real-DPI
UVM smoke 14/14, full UVM 337/337, SystemVerilog legacy ivtest 1,334/1,334,
and JSON/VVP 336/336. Both UVM lanes had zero skips.

OpenTitan has adjacent parenthesized min/max uses in the clean
`entropy_src` DV graph, but not the parentheses-free spelling fixed here. The
selected clean `lowrisc:dv:entropy_src_sim:0.1` non-regression attempt therefore
could not establish an exact corpus witness, and it also failed before those
consumers elaborated: setup returned 0, Icarus returned 236, and the matrix
classified 202 hard errors plus 126 debt diagnostics after required
`RNG_BUS_WIDTH`, `RNG_BUS_BIT_SEL_WIDTH`, and `DISTR_FIFO_DEPTH` target
macros were absent. No VVP image or UVM runtime exists. The failed-gate summary
SHA-256 is
`03db260db07a8e205664f3b85af073160323777f0eb50677d187edc7100c3b74`
at workspace-root-relative
`evidence/opentitan-7a3ad34-a179a1010/uvm-entropy-src-minmax/SUMMARY.md`.
This is a target/configuration blocker for that invocation, not an integration
pass and not evidence of a DUT defect.

Four clean Caliptra assertion-enabled `-tnull` witnesses remained exit-zero
compile/elaboration non-regressions with zero error, `sorry`, internal-error,
or crash diagnostics. Warning counts remain 202/202/0/89; only `abr_sha3` is
diagnostic-clean. Their summary SHA-256 is
`e528d9fbbafe1c6e68e41ad71d28bcd274c8f4645ab44e799d6320eaa2481b13`
at workspace-root-relative
`evidence/caliptra-bd316141/assertions-tnull-minmax-clean-20260809/SUMMARY.md`.
This is compile/elaboration evidence only; Caliptra has no exact source witness
for this parentheses-free min/max bug.

Remaining work includes fixed-array nominal queue-result typing, validation of
iterator arguments and `with` variants, class/property/nested/indexed
receivers, call-result and wrapper contexts (including nonconstant ternaries),
and real/string/associative comparison and keyed-iteration semantics. Those
forms are open or exact-gold loud; none is claimed implemented by G72.

---

## G73 — package-qualified calls through a nested class typedef were syntax errors — **fixed** [general]

*8.23 / 26.3 / Annex A [general] — static class methods and explicit package
qualification.*

Ten OpenTitan xbar/full-chip cores, repeated in the UVM and runtime lanes,
stopped at `xbar_error_test.sv:12` on
`cip_base_pkg::cip_tl_seq_item::type_id::set_type_override(...)`. The
unqualified class form already worked. Statement parsing reduced the shared
`package::class::nested` prefix as a package-scoped l-value and had no
continuation for the final static method; expression parsing retained the
package class type but likewise lacked the nested-call continuation.

Expression calls now extend the existing package type path, while statement
calls extend the existing package-scoped l-value directly through the final
method and semicolon. Both preserve class specialization and nested typedef
provenance. The grammar remains at 535 shift/reduce and 1115 reduce/reduce
conflicts with the unchanged 201-state normalized descriptor signature
`b96fa4bf669e73f14ed8748e864e8b3f4cdfbdc61b45ec6d5cab66a7e6946bc8`.

`sv_package_nested_static_call` value-checks the exact UVM spelling and
independent parameter-specialization storage; its negative companion pins
statement/function arity diagnostics. Both focused harnesses pass, and Slang
accepts the positive while rejecting both negative sites.

A fresh 20-record OpenTitan replay removes every former line-12
syntax/malformed-statement pair. Sixteen jobs advance to a missing standalone
`prim_clock_gating` dependency and four full-chip jobs reach a later
`chip_common_pkg.sv` parser boundary, so this is a precise blocker removal,
not a pass claim. OpenTitan sources were not modified.

---

## G74 — fixed unpacked arrays of queues/maps were rejected as instance class properties — **fixed/verified partial subset** [general]

*7.4 / 7.8–7.10 / 8.5 [general] — fixed unpacked arrays, associative
arrays, queues, and object properties.*

OpenTitan contains direct non-static class properties such as
`dma_intr_pred_t exp_intr_queue[NUM_MAX_INTERRUPTS][$]`, typedef-named queues
indexed by address, per-channel queues of class handles, per-buffer byte
queues, and fixed arrays of string-keyed associative coverage objects. The
frontend formerly rejected every such queue-leaf type before distinguishing
class instance storage from signal-backed storage.

The verified implementation preserves a queue or associative-array leaf below
one or more fixed unpacked property dimensions. VVP class storage constructs
an independent container in each fixed slot. Elaboration keeps the canonical
fixed prefix separate from a trailing queue position or associative key, and
the target carries that separation through typed element reads/writes and
method receivers. A fully selected leaf supports whole-container value copy,
queue/associative methods, r-value queue slices, last-element reads, packed
element selects, and integral, real, string, class-handle, aggregate, and
nested-container values. Bare fixed-array values assigned to scalar or
selected fixed-slot queue properties are materialized as independent queues in
declared order and truncated to the destination bound. Context conversion is
applied to associative keys and integral leaves. Associative vivification
inserts nil dynamic-array values, notifies the outer root, and carries that
root provenance through later child mutation. Arbitrary trailing
queue/associative/dynamic-array chains retain recursive receiver typing and
value-copy behavior, and a
selected nested dynamic array supports `delete()`. Whole fixed-outer
assignment decomposes into
declared-order slot stores and value-copies every queue/map leaf independently.
The selected queue receiver used for `$` and the fixed outer-index expression
are not duplicated. Undefined or out-of-range fixed indices return the
empty/null default on reads and make writes/mutators warned no-ops rather than
aliasing slot zero. Scalar integral/bit, real, string, class-handle and
unpacked-struct properties behind the same fixed prefix use type-appropriate
defaults/no-ops too, including packed read-modify-write and exactly-once
index/RHS evaluation.

This is not full fixed-array/container closure. Signal-backed declarations and
static class properties, a fixed queue/map array nested inside an unpacked
struct property, direct fixed arrays of dynamic arrays, whole-outer property
r-value reads, queue-slice l-values through the selected property, `$` as an
l-value, methods invoked without the complete fixed prefix, and direct
property selection from a function-call result remain loud. Randomization,
`ref` lifetime, VPI and synthesis behavior are not claimed.

Implementation scope, OpenTitan source witnesses, permanent reducer names,
and the final ARM64 evidence are recorded in
[`session_logs/2026-08-23_opentitan_fixed_array_container_class_properties.md`](session_logs/2026-08-23_opentitan_fixed_array_container_class_properties.md).
The new legacy and split focuses pass 15/15 each, the complete manifests pass
1,792/1,792 and 860/860, and the Slang differential agrees with the supported
and deliberately loud boundaries. A final unmodified OpenTitan replay finds
zero occurrences of the former array-of-queue rejection and reaches later
independent blockers in every selected lane. No OpenTitan runtime lane reaches
simulation, so this entry does not claim whole-design UVM/runtime closure.

---

## G75 — locator methods rejected fixed-array class-property receivers — **fixed/verified partial subset** [general]

*7.12.1 [general] — array locator methods on fixed unpacked object
properties.*

OpenTitan GPIO filters the fixed property `stable_cycles_per_pin` with
`find(m) with (m != FILTER_CYCLES)`. Icarus previously rejected the legal
receiver before lowering the predicate. A fixed property is inline class
storage rather than a signal-backed array or dynamic-container handle, while
the shared locator target loop required a signal label.

The supported one-dimensional property is now evaluated once and materialized
as a typed temporary dynamic array. A separate declared-index payload keeps
`item.index` and every `*_index` result in the property's original coordinate
system, including negative and nonzero bases. Declared direction controls the
leftmost/rightmost match chosen by `find_first*` and `find_last*`. Integral,
real, string, and class-handle elements are supported; scalar results are
fresh value snapshots and class results keep normal handle-copy semantics.
The standard leaves general locator traversal order unspecified, so the tests
do not impose an order on `find`/`find_index` results.

Permanent positive and negative tests, exact gold streams, dual focus lists,
and the main manifests are described in
[`session_logs/2026-08-24_opentitan_fixed_property_locators.md`](session_logs/2026-08-24_opentitan_fixed_property_locators.md).
Focused legacy and JSON/VVP gates pass 7/7 each; the complete manifests pass
1,794/1,794 and 862/862. Slang 11.0.448 accepts the supported source under
IEEE 1800-2017 and 1800-2023.

An unmodified `lowrisc:earlgrey:dv:gpio_sim:0.1` witness at OpenTitan commit
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19` returns zero with no occurrence of
the former fixed-property locator diagnostic. Previously triaged
virtual-interface argument-row diagnostics remain in target output, and no
OpenTitan simulation ran; this is not a whole-design pass claim.
The workspace-root-relative evidence summary is
`evidence/opentitan-fixed-property-find-arm64-20260824T0032MDT/SUMMARY.md`
(SHA-256
`dcf72578e3655d287b99f41f24dabe92e01a920c56d73e4fd7dfad116dc0e000`).

Multidimensional fixed-property locators remain loud. Associative keyed
locators, aggregate-element value copying, direct fixed-signal nonzero-base or
nonintegral receivers, and result typing through arbitrary expression wrappers
remain separate boundaries.

---

## G76 — missing implicit randomization hooks were treated as unknown methods — **fixed** [general]

*18.6.2 [general] — implicit `pre_randomize()` and `post_randomize()`
functions.*

IEEE 1800 gives every class implicit zero-argument `void` randomization hooks
with empty default bodies. Icarus instead treated a call as an ordinary missing
method when neither the class nor an ancestor declared that hook. OpenTitan
DMA exposed the gap in `dma_seq_item.sv:491`, where the declared override calls
`super.post_randomize()` and the UVM base class relies on the implicit body.

Missing hooks now lower to their empty standard bodies after the class
hierarchy is complete. Ordinary, implicit-`this`, explicit-`super`, and
arbitrary receiver-expression calls share the behavior. The receiver is
evaluated exactly once even though the body is empty. A parsed declaration in
any ancestor keeps the existing declared-method path, while any argument is a
deterministic error because the implicit prototypes have no formals.

The permanent positive and negative tests, dual focus lists, differential
results, and ARM64 validation are described in
[`session_logs/2026-08-24_opentitan_implicit_randomization_hooks.md`](session_logs/2026-08-24_opentitan_implicit_randomization_hooks.md).
Focused legacy and JSON/VVP gates pass 2/2 each; the complete manifests pass
1,796/1,796 and 864/864. Slang 11.0.448 accepts the positive source and rejects
the three illegal calls under both IEEE 1800-2017 and 1800-2023.

An unmodified frozen `lowrisc:dv:dma_sim:0.1` source graph at OpenTitan commit
`7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19` contains no remaining
`pre_randomize` or `post_randomize` diagnostic. Compilation advances to
exactly two independent fixed-array range-lvalue errors in
`dma_scoreboard.sv:1446` and `:1450`; no simulation ran, so this is not a
whole-design pass claim. Evidence is under
`evidence/opentitan-dma-implicit-hooks-fresh-arm64-validation-20260824T0054MDT/`.

---

## G77 — queue ranges were lowered as packed part selects — **fixed/verified r-value subset** [general]

*7.4.5 / 7.4.6 / 7.6 / 7.10.1 [general] — unpacked-array slices,
queue range expressions, result typing, and array assignment.*

The unmodified OpenTitan USBDEV graph exposed variable queue bounds inside a
streaming expression. Icarus formerly reached the terminal range through the
packed part-select path and rejected the legal queue operands as nonconstant:
`usb20_monitor.sv:578` failed once and the same diagnostic recurred at line
582. The receiver's dynamic-container kind was being recognized after the
wrong width/constant rule had already fired.

The common expression walk now stops at a genuine positional queue range and
uses queue-specific elaboration and runtime operations. Direct, nested,
instance/fixed-slot/scoped-static property, method, untyped formatting, and
streaming paths preserve the complete receiver selection. Colon bounds and
indexed `+:`/`-:` base and width expressions are evaluated exactly once.
Signed, unsigned, narrow, wide, and X/Z values are classified before any host
integer conversion or allocation. Colon endpoints clamp to the live queue;
reversed or unknown ranges are empty. Indexed ranges normalize into ascending
queue order, clamp without over-allocation, and return empty for an unknown
base or a zero, negative, or unknown width. Nested unpacked value elements are
copied rather than aliased.

IEEE 1800-2017/2023 7.10.1 explicitly permits arbitrary integral queue colon
bounds such as `Q[a:b]`. For queue indexed ranges, the implementation follows
Slang's compatible interpretation that the queue exception applies to every
range-selection kind; this is recorded as differential behavior rather than
an unqualified 7.10.1 claim. Slang 11.0.448+e222e7dc0 accepts the positive
colon/`+:`/`-:` source under both 1800-2017 and 1800-2023. A bounded queue
receiver still produces an unbounded queue result, matching Slang's AST type.

The syntax is deliberately discriminated from other unpacked arrays. Sections
7.4.5, 7.4.6, and 7.6 require a dynamic-array slice to be a fixed-size
unpacked-array expression, not a dynamic array. At this G77 checkpoint, legal
dynamic colon and indexed r-values therefore produced the exact loud
`sorry: dynamic-array slice r-values are not yet supported as fixed-size
unpacked-array expressions.` rather than claiming a false dynamic result.
The later G79 increment implements the direct constant-colon blocking-
assignment subset while retaining the loud indexed, nested/property, and
standalone boundaries. Illegal dynamic operands still receive their standard-
specific diagnostics first. Associative colon, `+:`, and `-:` ranges all
produce `associative arrays cannot be indexed by a range.`

The final focus gates pass 14/14 legacy and 9/9 JSON/VVP. The complete runners
report 1,801/1,801 for `regress-sv.list` and 869/869 for `regress-vvp.list`;
these are runner-reported test totals, not raw manifest line counts. Legacy
queue-slice VVP bytecode remains 3/3. The JSON commands used
`python3 vvp_reg.py`, not Perl or direct shebang execution. No RSS cap was
applied to the compiler or tests; only the 45-second per-process CPU runaway
guard remained. Full commands, differential diagnostics, evidence hashes, and
the permanent reducer inventory are in
[`session_logs/2026-08-24_opentitan_usbdev_variable_queue_slices.md`](session_logs/2026-08-24_opentitan_usbdev_variable_queue_slices.md).

At OpenTitan commit `7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19`, the
fresh `lowrisc:dv:usbdev_sim:0.1` replay contains no line-578/582 diagnostic and
no remaining `Part select expressions must be constant integral values.` The
graph advances to ten independent elaboration errors, including hierarchical
`usbdev_timed_regs.timed_reg_e` constant/cast-size uses and three aggregate
`std::randomize()` constraint sites; a later unresolved `ep_default` statement
also remains. No VVP image or USBDEV runtime exists, and no OpenTitan source
was changed. This is a precise compiler-blocker removal, not a whole-design or
UVM pass claim.

Queue range l-values and an indexed `+:`/`-:` range whose base token is `$`
remain explicit G77 boundaries. G79 subsequently implements one direct
dynamic-array fixed-result subset; other dynamic-array slice contexts remain
loud rather than silently represented as the wrong type.

---

## G78 — fixed class-property array ranges were treated as scalar indices — **fixed/verified blocking pattern-lvalue subset** [general]

*7.4.5 / 7.4.6 / 7.6 / 8.5 / 10.4 / 10.9.1 [general] — fixed
unpacked-array slicing, class-property l-values, and assignment patterns.*

At frozen OpenTitan commit `7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19`,
DMA declares `bit [TL_DW-1:0] exp_digest[16]` and assigns
`exp_digest[8:15]` and `[12:15]` from `'{default:0}` at
`dma_scoreboard.sv:1446` and `:1450`. Icarus previously routed those ranges
through scalar property indexing and emitted exactly two
`Array cannot be indexed by a range.` errors.

Direct one-dimensional non-static fixed properties now preserve the selected
fixed-array l-value type and canonical base for constant colon and
constant-base indexed ranges. Simple blocking assignment patterns are
contextualized by that selected type. Every RHS leaf is captured before the
first store, declaration direction is preserved, receivers are evaluated
once, and unselected words remain unchanged. An explicit target-API slice bit
prevents an ordinary fixed-array-valued property element from being inferred
as a range solely from its type; typedef-nested scalar and range selections
are rejected before target lowering until their storage semantics exist.

`sv_class_fixed_uarray_slice_lval_pattern` covers packed integral, real and
string values, negative/nonzero bounds, indexed polarity, overlap snapshots,
receiver evaluation, and the exact DMA patterns. Its negative companion pins
direction, bounds, runtime-base, NBA, and both nested-fixed-array forms. Slang
11.0.448+e222e7dc0 agrees on the supported subset under 1800-2017 and
1800-2023. The final focused runners pass 18/18 legacy and 15/15 JSON/VVP;
the related OpenTitan fixed-container focuses pass 17/17 in each harness.
Complete runner, UVM, self-check, and unmodified DMA results are recorded in
the [session log](session_logs/2026-08-24_opentitan_dma_fixed_property_slice_lvalues.md).

The frozen DMA compile now returns zero and contains neither former range
error. It advances to later VVP-target virtual-interface method-call errors
whose receiver instances lack argument rows. This closes G76's two exposed
range errors, not the complete DMA graph or runtime: the target still writes
no trustworthy runnable DMA image for that later frontier, and OpenTitan was
not modified.

Runtime-base indexed slices, multidimensional or typedef-nested property
slices, property-slice r-values, NBA and non-pattern/compound stores, and
aggregate/object elements remain explicit loud or unclaimed boundaries.

---

## G79 — dynamic-array fixed slice values stopped at a loud boundary — **fixed/verified direct blocking assignment subset** [general]

*7.4.5 / 7.6 [general] — dynamic-array slice result typing, array assignment,
and self-assignment snapshots.*

At frozen OpenTitan commit `7a3ad34b6d483f4d1d69ac670ddb1c45f1172e19`,
HMAC assigns the direct dynamic array of unpacked `test_vectors_t` structs as
`parsed_vectors = parsed_vectors[0:1]`. The clean pre-fix graph had exactly one
hard error at `hmac_test_vectors_sha_vseq.sv:82`: the frontend correctly said
the slice needed a fixed-size unpacked result, but could not represent it.

An immediate whole assignment between direct one-dimensional plain dynamic-
array signals now lowers a fully defined constant ascending colon range to a
fixed `netuarray_t` array pattern of typed element reads. Equivalent element
types are required, OOB reads retain the element default, and the dynamic
target resizes to the fixed result count. VVP materializes the complete RHS
before replacing the destination, so a self-slice keeps its old receiver.
The aggregate builder also reloads each destination index after evaluating
the source leaf, preventing nonzero source indices from clobbering vector,
real, string, or object placement.

Generated source coordinates are exact signed 64-bit constants rather than
normal 32-bit integer-width constants. The fixed aggregate uses canonical
`[0:count-1]`, since only its sequence and count are observable at the dynamic
target; wide LP64 source coordinates therefore remain exact without depending
on LLP64 `netrange_t`. Object reads check the live size and `UINT_MAX` before
calling the runtime's unsigned-index API. Object-backed value-struct results
also retain their element prototype, so a nil OOB slot materializes the
integer/string/nested-dynamic-array defaults after a class-property copy;
class-handle elements keep reference identity and a null OOB default.

`sv_dynamic_array_slice_rvalue` covers all four store categories, two- and
four-state/real/string OOB defaults, nonzero source bounds, self-assignment,
signed `+/-4294967296` source coordinates, and non-self plus self slices of an
HMAC-shaped unpacked struct. Partial/all-OOB structs are copied through a class
dynamic-array property and check integer, string, and nested-array defaults;
the far-positive case proves the source read cannot wrap onto element zero.
Mutating the copied scalar, nested dynamic-array entry, and string proves
value-copy independence, while class-handle coverage proves identity/null
semantics. Its negative companion distinguishes ten standards-invalid
forms from the still-legal indexed-variable, nested-property, and unpacked-
union-element implementation boundaries. The union case emits a focused
`sorry` before object lowering rather than exposing the current X
initialization where Table 7-1 requires the first member's default; this does
not claim global union runtime semantics.
Slang accepts the shared positive source under both 1800-2017 and
1800-2023 and agrees on those ten invalid forms; its signed-32-bit dynamic-
index restriction is isolated behind the Icarus-only wide checks. Focus gates
pass 15/15 legacy and 10/10 JSON/VVP.

The exact unmodified HMAC compile now exits 0 in 3.10 seconds and emits a VVP
image, with no remaining hard diagnostic. Its real-DPI smoke run reaches the
UVM test but fails at 0 ps on `tlul_rsp_intg_gen.sv:82 RspZero_A`; the next
reduced frontier is a VVP nested-concatenation initialization-order defect,
not another dynamic-array-slice error. The 256 end-of-simulation assertions
are secondary to UVM's zero-time abort. No whole-OpenTitan pass is claimed.
Evidence and full commands are in the
[session log](session_logs/2026-08-24_opentitan_hmac_dynamic_array_slice_rvalues.md).

Indexed `+:`/`-:` slices, property/nested receivers, fixed targets, standalone
and type-query contexts, multidimensional shapes, delayed/event/NBA forms, and
compound assignments remain explicit loud or unclaimed work. Unpacked-union
elements likewise remain an exact loud boundary.

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
