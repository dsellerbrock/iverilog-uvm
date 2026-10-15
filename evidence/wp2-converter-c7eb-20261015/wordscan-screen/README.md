# Converter word-scan screen

Pinned measurement base: `c7ebca768c21c251d9c165c9aff0e363768030b1`.

This variant retains the existing `small_2state_word` and X/Z checks, then
reads the A-plane by machine word instead of calling `value()` for each bit.
It is screened against the existing 100,000-iteration wide-index workload.
The reference install is from the pinned base; the candidate is that same
source plus `input/converter-wordscan.patch`.

| Result | Status |
| --- | --- |
| Focused build/output | PASS, Slurm job 1308; reference and candidate output SHA-256 match |
| Focused process instructions | 2,342,072,014 → 1,863,201,596 Ir (−20.446443%) |
| Focused edge self-check | PASS, job 1351: signed/unsigned overflow, sign extension, and X/Z |
| Broad Callgrind/output screen | PASS: 18/18 measured; all outputs match; worst regression +0.001880% |
| Native corpus | PASS, job 1348: all 18 output files match byte-for-byte |
| `waveform_fst` Callgrind | PASS, job 1350 with `--fair-sched=yes`: outputs match, −63 Ir |
| Candidate function inclusive count | Inlined by `-O2`; use whole-process count for the candidate comparison |

The candidate patch SHA-256 is
`e4661c8aa34607ccccffc4e1cddcbfc4b74bac394a2ed4533adf80ad71595b2f`; the
workload SHA-256 is
`f04be01b9ec8c86983744039c51523aa78883b11f22d810d96d0485b89dc8162`.
The combined instruction rows are in
`callgrind-screen/instruction-counts-18.csv`; only the FST row uses the
fair-scheduler setting to avoid a reference-only pthread crash under default
Callgrind. The PR retains this summary, the aggregate CSV, and the relevant
source/input hashes. Raw profiles, build outputs, and duplicate waveforms
remain in the local revision-scoped evidence archive. The earlier `has_xz()`
screen's compact comparison is recorded in the top-level report.

The fused X/Z-and-overflow word scan follow-up also passed a fresh 18-workload
screen on the same pinned base: outputs match 18/18, with instruction deltas
from -0.026238% to +0.002218%. Its focused result is -20.535627% versus
reference; a targeted narrow-Z edge check passed on both installs. This is not
a matched comparison with the earlier word-plane percentage because the
follow-up input adds a narrow-Z assertion. Broad evidence is in
[`fusedxz-broad-20261015/`](fusedxz-broad-20261015/README.md); the final edge
check is in [`fusedxz-edge-65/`](fusedxz-edge-65/README.md).
