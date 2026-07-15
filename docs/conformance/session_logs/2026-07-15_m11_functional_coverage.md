# 2026-07-15 — M11: functional coverage (PR #76)

Directive: "Let's work on M11 — complete implementation and all
iterations in this session."

Before this milestone, covergroups were a minimum-viable
approximation with several SILENT failure modes: multi-range bins
(`bins b = {1, 5}`) could NEVER be hit (the runtime AND'd all ranges
of a bin — a live silent miscompile, confirmed by probe); arrayed
bins collapsed into one bin; `with` filters deleted the bin's ranges;
wildcard/default/transition bins and every other unrecognized
covergroup item vanished through parser error recovery; ignored bins
were dropped but their VALUES still counted in other bins; option
assignments disappeared; package-level covergroup bodies were
silently discarded; and coverage percentage was flat bin-counting
rather than the clause-19 item model.

## Architecture

The proven synthesized-class design is kept and made real: each
covergroup lowers to a hidden class with one int property per
coverage bin. Bin PREDICATES become metadata records
`(cp, prop, lo, hi, kind, tuple, item)`:

- records sharing `(prop, tuple)` AND together (cross product
  tuples);
- distinct tuples of one prop OR together (multi-range bins — the
  fix for the silent miscompile);
- `item` groups props into coverage items (coverpoints then crosses)
  for the per-item weighted coverage model;
- `kind` = normal / ignore / illegal / default / transition-step,
  plus a wildcard flag (lo=value, hi=care-mask).

Serialized to vvp via widened `.covgrp_bin` records plus a new
`.covgrp_item` directive (at_least/weight/is_cross per item).

## M11-1: bin semantics core (19.5)

- **Arrayed bins**: `b[] = {...}` one bin per value; `b[N] = {...}`
  N distributed bins (evenly chunked). 1024-value/bin cap, loud.
- **with (expr) filters**: constant-evaluated per candidate value by
  an `item`-substitution evaluator (arith/logic/compare/ternary,
  `$countones`/`$onehot`/`$onehot0`); unsupported forms and >4096
  value sets are loud sorries that DROP the bin (never a silently
  unfiltered bin).
- **wildcard bins**: literal patterns with x/z/? treated as
  don't-care masks; composes with ignore/illegal.
- **default bins**: counted for observability, excluded from the
  coverage percentage (19.5.4); `default sequence` is a loud sorry.
- **ignore_bins** now CARVE OUT values (19.5.5): a sampled value
  matching an ignore bin suppresses all counting for that coverpoint
  on that sample, crosses included. (Previously the values still
  counted — a semantic bug.)
- **illegal_bins** fire the runtime error, take precedence over all
  other bins including ignore, and suppress the coverpoint's other
  bins for that sample.
- **iff guards** on coverpoints gate sampling (19.4): guard values
  are pushed at each sample site (`%covgrp/sample` gained a
  has_guards operand); non-1 (incl. x/z) means "not sampled".
  Supported guard forms at sample sites: class property or constant
  (anything else is a loud sorry, guard treated as enabled).
- **Automatic bins** (19.5.1): a coverpoint with no explicit value
  bins gets min(auto_bin_max, 2^M) uniform bins (default 64) over
  the bit-pattern space (signed ranges are covered as bit patterns;
  recorded).
- **Options** (19.7): `option.`/`type_option.` assignments are
  captured at covergroup, coverpoint, and cross level. `at_least`
  and `auto_bin_max` are APPLIED; `weight` feeds the coverage model;
  goal/comment/name/detect_overlap/cross_num_print_missing/
  per_instance and type_option.* are accepted without simulation
  effect (per_instance is a reporting knob — this implementation
  always tracks both instance and type coverage); unknown option
  names are loud.
- **get_inst_coverage** is now the weighted mean over coverage ITEMS
  (each coverpoint and each cross, weight × percentage of its bins
  with count >= at_least) per the 19.11 option model — replacing
  flat bin counting. coverage_cross_test's expectation was updated
  (75% flat model → 83.33% item model) with the reasoning pinned in
  the test.
- Every silent grammar drop replaced by a loud sorry (unsupported
  covergroup items, bins forms, cross body items).

## M11-2: transition bins (19.5.3)

`(a => b)`, multi-step sequences, multiple comma-separated sequences
per bin, and `[lo:hi]` range steps — overlap-correct via per-instance
NFA active-position masks (stored on vvp_cobject, keyed by
(prop<<8)|seq). `b[] = (...)` arrayed transitions get one counter per
sequence. Sequences are capped at 63 steps (loud); ignore/illegal
transition bins and `[*n]`/`[->n]`/`[=n]` repeats inside transitions
are loud sorries. Guard-false and carved-out samples freeze the
transition state (recorded decision; the LRM leaves this
unspecified).

## M11-3: crosses with binsof (19.6)

Named cross bins: `bins x = binsof(cpa.lo) && binsof(cpb) intersect
{[0:9]};` — select trees (binsof leaves with optional bin name and
intersect value filters, combined with &&/||/!) are captured in the
pform and evaluated per cartesian product tuple at elaboration:

- normal user bins collect their selected tuples under one counter
  (OR of AND-tuples at runtime);
- ignore user bins carve tuples out of the cross entirely;
- illegal user bins take precedence and error at runtime;
- unselected tuples keep automatic per-tuple bins;
- arrayed contributing bins match binsof by stem name (`bin[k]`);
- intersect matches on value-set overlap with the contributing
  bin's ranges.

Cross auto bins now OR correctly across multi-range contributing
bins (range-tuple cartesian expansion; 256 range-tuples per product
bin, 4096 products per cross, loud beyond).

## M11-4: queries, type coverage, reporting (19.8/19.9/19.11)

- **get_coverage()**: TYPE coverage — every counter bump also feeds
  a per-class merged counter; the query returns the item-weighted
  coverage over the merged counts.
- **$get_coverage**: mean of type coverage over all covergroup types
  (registered at .vvp load); returns 100 with no covergroups. The
  system function is registered as real-returning in the compiler.
- **start()/stop()**: per-instance sampling enable (19.8.1).
- **Coverage report + durable serialization**: with
  `IVL_COVERAGE_REPORT=<file|->` set, end of simulation writes a
  text report per covergroup type: per-item structure (kind,
  at_least, weight), per-bin merged counts tagged hit/MISS at the
  at_least threshold, illegal/default bins labeled, and the type
  coverage percentage.

## Bugs found and fixed en route

- **Latent pform teardown double-free** (pre-existing — reproduced
  with the M10-era compiler): one `data_type_t` is shared by every
  declarator of a comma property list (`int a, b;`) and can also be
  owned by a typedef, but `prop_info_t`/`typedef_t` both held owning
  unique_ptrs; exit-time Module destruction double-deleted and
  module-scope classes with covergroups crashed the compiler after
  writing output. Teardown now releases instead of deleting (a
  deliberate exit-time leak; the pform is process-lifetime).
- **Windows link**: the new `ivl_type_covgrp_*` entry points were
  missing from ivl.def, breaking all three MSYS2 CI jobs at the
  tgt-vvp link (caught from the PR's CI failure webhooks).

## Grammar accounting

Zero new useless rules; +7 r/r conflicts, all in pre-existing benign
families (hierarchy_identifier/expr_primary/class_scoped_type_
identifier IDENTIFIER-prefix ambiguities in item contexts, 233/242/
130 instances before the change), validated empirically by the full
ivtest sweep (byte-identical failures).

## Tests

- tests/m11_coverage_bins_test.sv — 17 checks: multi-range OR,
  arrayed per-value, sized chunks, with-filter both directions,
  ignore carve-out, iff gating both directions, wildcard match and
  reject, auto bins full/partial, at_least below/met/full.
- tests/m11_coverage_trans_test.sv — 8 checks: 2-step, 3-step,
  broken sequence, overlap restart, multi-sequence bins, range
  steps hit and miss.
- tests/m11_coverage_cross_query_test.sv — 10 checks: named binsof
  bin, cross ignore carve-out, auto completion, intersect miss/hit,
  instance vs merged type coverage, stop/start, $get_coverage.
- The four legacy coverage tests pass (one expectation updated to
  the item model, documented in-test).

## M11 recorded corners (at close)

- Package/module-scope covergroup DECLARATIONS are stub types with a
  loud sorry (body ignored); class-embedded covergroups (the UVM
  pattern) are the fully supported form. Covergroup sampling events
  (`covergroup cg @(posedge clk)`) are loud syntax errors —
  procedural `sample()` is the supported trigger.
- `with function sample(args)` parses; coverpoints over sample
  formals are loud sorries (coverpoint expressions resolve against
  class properties only).
- Coverpoint expressions beyond a simple class-property name are
  loud sorries (sampled as constant 0 with the message).
- iff guard forms beyond property/constant at sample sites: loud
  sorry, guard enabled.
- Coverage values are 2-state (X/Z bits coerce to 0 at sample;
  recorded).
- Type-coverage merge accumulates counts across instances (sum);
  at_least applies to the merged count.
- Per-coverpoint queries (cp.get_inst_coverage), cross-scope
  option overrides via cg.cp.option.*, `sample` argument pass-through
  in overridden built-in sample, real-valued coverpoints, and
  `binsof` outside cross bodies are not implemented (loud errors or
  sorries).
- The coverage report is a text format; UCDB interchange is out of
  scope.
- Auto bins for signed coverpoints partition the unsigned
  bit-pattern space.
- Caps (all loud): 4096 with-filter values, 1024 arrayed values/
  bins, 4096 cross products, 256 range-tuples per product bin, 63
  transition steps.

## Promotion evidence

Recorded below after the full sweeps.
