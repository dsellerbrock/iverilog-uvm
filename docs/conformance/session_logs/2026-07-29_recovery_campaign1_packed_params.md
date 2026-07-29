# Recovery Campaign 1 — multi-dim packed parameter selects (2026-07-29)

Repository recovery after the Campaign 7 / OpenTitan agents were
retired mid-flight. Ground truth was re-established from a fresh main
(aa82a67): local baseline green (make check; ivtest 3249/0 name-diff
clean; VPI 94/94; negative 80/80; sva_nfa 39/39; UVM smoke 14/14), then
every high-risk finding re-reproduced before entering the plan. The
full lead-verified truth table lives with the session; the reproducers
are committed as the new tests below.

## What this campaign closed (all verified wrong on pre-fix main)

| shape | pre-fix behavior |
|---|---|
| inline `parameter logic [7:0][2:0] P` + `P[i]` | flat BIT select — identity permutation read 8'h77 for 8'ha5, silent (G15) |
| typedef'd multi-dim packed param select | ivl_assert abort netmisc.cc:2599 (G14) |
| `P[6][2]` (any param path, >1 index) | used ONLY the last index: silently computed `P[2]` |
| `P[3:2]`, `P[1+:1]` on multi-dim packed param | flat bits, not elements; silent |
| `AP[2][1]` on unpacked array param | returned whole element `AP[1]`; silent |
| descending `BP[3:0]` array param | elements REVERSED (BP[3] read the [0] value); silent |
| non-zero-based `CP[1:4]` array param | off by base (CP[1] read the second element); silent |
| variable index `AP[i]` | warning + EMPTY STRING value |
| pattern arity mismatch on array param | silently created a short array |
| `$size/$left/$right/$high/$low/$increment/$dimensions` on multi-dim packed param | answered for the flat vector ($size = 24 where a signal answers 8); `$size(P,2)` asserted (eval_tree.cc:2186) |

## Mechanism

`param_select_packed_` (elab_expr.cc) is the single canonical
calculation: strides per packed dimension; constant indices folded
with x-fill when out of range; variable indices normalized per
dimension and scaled (`scale_index_to_bits`); one flattened base
offset plus the addressed slice width. The dispatcher routes any
multi-dim or multi-index parameter select there; 1-D single-index
selects keep their existing paths untouched. The pform flattening of
inline multi-dim packed parameter types is removed (inline ==
typedef). Unpacked array parameters record their evaluated declared
bounds and expand elements under REAL indices; a variable element
index selects from a flattened constant element table at run time.
Array-query functions consult the parameter's declared type.

Salvaged from retired PR #139 after independent verification on a
worktree build: 4d5520b (run-time index in any packed dimension —
value-verified, test discriminates), f7f80c2 (G14 slice-width fix —
code split from its docs; verified by value), f891958 (explicit
verinum). PR #139's own admission that G15 remained open in-family is
resolved by this campaign.

## Verified boundary (do not overstate)

SUPPORTED WITH VERIFIED SCOPE: selects on integral packed parameters of
any dimensionality and on 1-D unpacked array parameters of integral or
string element type, in the forms listed in
`sv_param_multidim_packed_select` / `sv_param_unpacked_array_select`.
Loud errors (not silent wrongs) for: multi-dim UNPACKED array
parameters; part selects across array-parameter ELEMENTS (`AP[1:2]`);
variable array index combined with further selects; variable index
over string elements; too many index components (was silent last-index
use); pattern arity mismatch (was silent short array).

Out of scope, unchanged: packed selects on SIGNALS (already canonical
via collapse_packed_base — 4d5520b), struct-member packed access
(G16, open), class-property packed access.

## Evidence

- Reverted-build comparison: both new ivtests fail against the pre-fix
  build (test 1 aborts on the eval_tree assert; test 2: 19 value
  errors); both new negative tests are silently ACCEPTED by the
  pre-fix build and rejected now.
- Gates on the fixed build: recorded in the campaign PR with the
  actual run outputs (make check, the ivtest name-diff gate including
  the two new tests, VPI, negative, sva_nfa, UVM smoke, full UVM).
