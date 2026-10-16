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
- The synthetic hotloop's best variant missed the campaign's 10% bar. A later
  deterministic Caliptra mcycle 100–200 screen on the same pin measured
  −10.259915% instructions. The broad Callgrind corpus matched all 18 outputs,
  with a largest non-target count increase of +0.038453%; the focused legacy
  and JSON lists passed 19/19 each, and malformed metadata returned X for all
  16 reads. Full gates and exact-head CI remain pending. The bounded Caliptra
  screen and its incomplete-run limitation are documented in
  [attempt 1420](../wp2-predecode-caliptra-c7eb-20261015/attempt-1420/README.md).

The final three-run wall-time support table is in
[wall-summary.csv](wall-corpus-c7eb-20261015-r1/results/wall-summary.csv).
It reports every median and spread; the largest candidate spread is 43.445690%
on `large_memory`. Wall-time spread does not block the instruction-count gate.

Pinned-base full gates passed in Slurm job 1457: `make check`, the complete
legacy/VPI/negative/runtime gate, the full JSON differential, and UVM with real
DPI (367/0/0). The candidate JSON run reported 16 failures; the pinned
reference reproduced the same 16 names, with zero new failures and no timeouts.
A4 confirmed these were pre-existing fixture issues and #595 corrected them.
The first gate setup attempt, job 1454, stopped before testing because its
binary-hash command used the wrong `ivl` install path; the corrected fresh run
is documented in [full-gates r2](full-gates-c7eb-20261015-r2/README.md).
Final-head gates and cross-platform CI still need to run after the one
merge-time rebase and any required new-base measurement.

The code patch and focused test inputs are under `input/`. Full Slurm logs and
Callgrind outputs remain in the local evidence archive.
