# Issue #834 root-cause note

## Standard and reproducer

IEEE 1800-2017 and 1800-2023 §19.5.1 define a bin's value set with a
`covergroup_range_list`. The prepared regression contains a full 256-bit
range, a bounded 256-bit range with in-range and just-outside samples, and a
64-bit control:
[`sv_covergroup_wide_range_bins.v`](../../ivtest/ivltests/sv_covergroup_wide_range_bins.v).

The current-main baseline is preserved in
[`baseline-current-main/README.md`](baseline-current-main/README.md), from
Slurm job 3572 at `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`. Both `-g2017`
and `-g2023` compilation fail on the two 256-bit bins with the same
elaboration diagnostic. The independent search of open and closed issues for
`"wide covergroup bin"`, `"wide range bin"`, `"explicit wide range"`, and
`"256-bit" covergroup bin` found only the already-filed #834.

## Confirmed limit in the implementation

`elaborate.cc` enables the wide exact-value path for unsigned packed
coverpoints of 65–256 bits (`cp_wide_exact_supported`, around line 42093).
Its `read_value` helper converts each endpoint to 64-bit words, but the range
loop (around line 42900) rejects the bin whenever the lower and upper endpoint
vectors differ. This limits that path to singleton values despite its
wide-width support and diagnostic wording.

Runtime `cov_bin_t` records currently store two 64-bit fields
(`vvp/class_type.h`, around line 277). The matcher in `vvp/vthread.cc`
(around line 7624) supports exact wide words and wide automatic high-prefix
bins, but no arbitrary inclusive multiword interval. The existing prefix
matcher caps its prefix at 64 bits, while a 256-bit interval decomposition can
require deeper prefixes. Supporting `[low:high]` therefore needs both
elaboration metadata and sample-time matching; accepting the source alone
would leave the bin incorrect.

## Scope expansion for design review

`ACTIVE_WORK` initially allowed changes in `elaborate.cc`, `vvp/class_type.h`,
and `vvp/vthread.cc`. The current WIP also changes `netclass.cc/.h`,
`ivl_target.h`, `t-dll-api.cc`, `tgt-vvp/draw_class.c`, `vvp/compile.h`,
`vvp/lexor.lex`, and `vvp/parse.y`.

The violated invariant is that elaborated covergroup bin metadata must cross
the target API and be serialized into VVP without truncation. Existing bin
records have two 64-bit payload fields; directly storing 65–256-bit inclusive
bounds there would lose data, and accepting the source only in `elaborate.cc`
would leave runtime samples unmatched. A prefix decomposition may avoid a new
metadata path, but the existing wide-prefix representation is limited and
must be proven correct for interval and cross-bin semantics before choosing
it.

The design review on 2026-10-20 accepted class-owned unsigned lower/upper
word vectors with a range index as the smallest correct representation. It
confirmed inclusive bounds, X/Z non-matches, OR across alternatives, and AND
across cross-point tuples. The review found that full-carve processing must
advance its cursor to `excluded.high + 1`; the implementation now does so.
Paired regressions cover adjacent ignore ranges, disjoint alternatives,
partial and guarded ignores, illegal-bin denominator removal, X/Z and
cross-bin matching. Slurm T0 and focused T1 results are recorded in
[`T0-T1-STATUS.md`](T0-T1-STATUS.md).

The issue was triaged at
[#834](https://github.com/dsellerbrock/iverilog-uvm/issues/834#issuecomment-6302735764).
