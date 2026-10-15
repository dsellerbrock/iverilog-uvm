# `%prop/index/check` predecode screen

Pinned base: `c7ebca768c21c251d9c165c9aff0e363768030b1`.

The prototype cached parsed dimension metadata in the compiled opcode and
preserved the stack-pop count for malformed descriptors. The paired reference
and candidate focused checks passed all 32 valid and malformed cases.

- One access per case, aggregate process instructions: 5,675,670 → 5,658,644
  (−0.3000%). The process was mostly dynamic-loader work.
- 100,000 repeated property accesses on the pinned base, Callgrind:
  predecode alone reduced instructions by 6.7443%; adding packed-result
  construction improved the reduction to 9.212159%; a single-dimension
  zero-based/unit-stride fast path regressed 0.322130% versus that best variant.
  All 32 valid/malformed focused cases and all hotloop outputs matched.
- The best variant missed the campaign's 10% keep bar. Reject this predecode
  design; do not add it to a PR. The checked-in evidence keeps the summary
  tables and source patches; raw profiles and run bundles stay in the local
  experiment archive.

The code patch and focused test inputs are under `input/`. Full Slurm logs and
Callgrind outputs remain in the local evidence archive.
