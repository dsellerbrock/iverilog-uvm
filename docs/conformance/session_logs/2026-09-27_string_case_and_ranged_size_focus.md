# String case and ranged scope-queue size checkpoint — 2026-09-27

This record covers the combined source revision
`1838970aae17e2d091a573184d424bd6fd096f68`, including the string-case
commit `51c424cf2678240bf90fe320e471cb277f4931ee`. The results below
belong to this revision and do not establish full IEEE clause or application
DV qualification.

## Corrections and paired focus

- `51c424cf2`: plain and `unique case` with a string selector and string
  labels compare complete run-time values. Constant-function `case` compares
  normalized string values, including empty and zero-byte-normalized strings.
  The paired strict `sv_string_cast_width_and_case_2017/_2023` tests distinguish
  `"write"` from `"xwrite"` and retain explicit narrow integral-cast behavior.
  Mixed-type and `casex`/`casez` lowering is outside this correction.
- `1838970aa`: local integral-queue `std::randomize()` evaluates each probed
  size against the expanded `foreach` and direct element constraints before
  choosing from the feasible set. The paired strict
  `sv_std_randomize_darray_size_range_2017/_2023` tests cover an empty-only
  queue, a declared-bounded range, a guarded element read at sizes zero and
  one, and a sparse `{0,1025}` domain whose larger size is infeasible. Its
  dynamic-array range control predates this commit. The existing paired
  `sv_scope_randomize_local_queue_unsupported` test retains all four stderr
  lines: unbounded enumerable range, exact size 65537, exact bounded size 3,
  and a direct out-of-range read. Focused failed-solve controls preserved the
  queue and RNG state.

## Combined local gates at `1838970aa`

| Gate | Completed result |
| --- | --- |
| Full legacy ivtest | 6,704 total; 0 failures |
| Full JSON/VVP ivtest | 3,851 total; 0 failures |
| Bundled VPI | 131/131 passed |
| Negative diagnostics | 155/155 passed |
| VVP runtime invariants | 15/15 passed |
| Dual SVA | 62/62 passed |
| Real-DPI UVM | 358 passed, 0 failed, 0 skipped; real DPI umbrella loaded |

## Supported boundary

The ordinary queue-size probe covers 0–1024. A complete sparse set of at
most 64 larger candidates can be checked when their combined `foreach`
expansion stays within 16,384 elements. Queue allocation remains capped at
65,536 elements. These are Icarus solver and allocation limits, not IEEE
limits. Declared queue maxima restrict the candidate search, while a uniquely
fixed oversize value retains its exact error. Larger domains whose full
feasibility cannot be proved fail explicitly, so a successful call does not
silently sample only the smaller sizes. A missing-element read is accepted
only when the hard constraint is proved independent of that element at the
candidate size; a read whose type-specific default value could matter
remains explicitly unsupported. Failed calls leave the original queue and
RNG state intact.

No current OpenTitan or Caliptra application DV replay is included in this
checkpoint. The 2017 and 2023 clause matrices remain PARTIAL for these
subsets.
