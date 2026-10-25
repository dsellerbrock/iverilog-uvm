# Open/closed issue dedupe — §§16.6–16.7

Snapshot: `dedupe-all-issues.json`, fetched from `dsellerbrock/iverilog-uvm` with `gh issue list --state all --limit 1000`; 416 issues (289 open, 127 closed). Titles and bodies were searched for the lead's terms: `16.6`, `16.7`, `chandle assertion`, `side effect assertion`, `class property assertion`, `ref argument assertion`, `inout`, `cycle delay range`, `##[`, and `X false assertion`.

Potentially related hits:

- #713 (open, §16.9.8): `first_match` of variable-length sequence with continuation; this is not the fixed/ranged cycle-delay behavior tested by Q1–Q8.
- #717 (open, §16.10): sequence match items on composite expressions, distinct from the sequence delay ranges and expression restrictions probed here.
- #18 (closed, broad SVA feature phase): historical coverage request, without a probe-specific assertion-function restriction or cycle-delay semantics claim.
- #726 (open, §16.12.19): local variable formal arguments in property declarations, different from output/ref/inout subroutine function arguments in §16.6.
- #635 (open, §13.4): output/inout/ref function calls outside procedural statements, not the separate restrictions on function arguments inside assertion expressions; #633 is about defaults for output/inout subroutine arguments.
- #704/#705 (open, §14.11): clocking cycle-delay scheduling and non-positive expression-valued delays, not property-sequence `##` ranges.
- Closed #13 mentions `chandle` only for DPI pointer round-tripping; it does not cover chandle references in Boolean expressions.

Other term hits were unrelated uses of `inout`, `chandle`, `16.7`, or `##[...]` (e.g. covergroup formals and specify paths). Targeted follow-up terms `reversed range`, `3:1`, `sequence delay`, `vector::reserve`, and `length_error` found no existing reversed-range compiler-crash report; literal `3:1` hits #860, #837, and #835 are unrelated examples. After reviewing the same 416-issue snapshot and performing additional searches, the lead confirmed no duplicate and filed #913 (side effect dropped), #914 (chandle and non-static property live reads), and #915 (reversed-range compiler crash). The full snapshot is retained to support rechecking.
