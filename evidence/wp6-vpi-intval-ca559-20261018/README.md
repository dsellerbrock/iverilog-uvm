# WP6 VPI integer conversion fast path

**Superseded before PR:** this first candidate used a signed 32-bit temporary.
Review found that the existing conversion helper's signed mask can overflow
for values whose high bit is set. Its screen, gate, and wall evidence below is
retained for audit but does not qualify the final WP6 candidate. The corrected
unsigned temporary is remeasured in
[`wp6-vpi-intval-u32-ca559-20261018`](../wp6-vpi-intval-u32-ca559-20261018/README.md).

Pinned measurement base: `ca559fd97b19bd6a56cc10f0faf8583b4077975f`.

## Profile and change

The current-main profile sampled `vpip_vec4_get_value` at 17.57% self time in
`vpi_callbacks`. That benchmark registers a value-change callback on a one-bit
signal and requests `vpiIntVal` for 32 million value changes. The existing
conversion loop examined all 64 positions of a `long` for every callback.
`vpip_vec4_get_value` is shared by VPI signal, callback, array, constant,
class-member, and dynamic-array accessors, so the change is limited to the
shared `vpiIntVal` branch.

The candidate delegates to the existing `vector4_to_value` helper with a
32-bit result. This preserves low-32-bit VPI integer conversion and its X/Z to
zero behavior; the size check preserves the prior zero-width result without
calling the helper's signed-width path on an empty vector. No test golds or
dependencies changed.

## Pinned-base instruction screen — Slurm jobs 2357 and 2358

The candidate was built from the pinned base and compared with its read-only
reference install. Callgrind ran one interleaved reference/candidate pair per
workload. The JSON runner verified byte-identical outputs for all 18 workloads.

| Workload | Reference instructions | Candidate instructions | Change |
| --- | ---: | ---: | ---: |
| `behav` | 86,006,376,319 | 86,033,410,492 | +0.031433% |
| `classq` | 120,672,499,295 | 120,734,099,217 | +0.051047% |
| `fork_heavy` | 433,053,254 | 433,053,535 | +0.000065% |
| `gate_strength` | 38,952,167,192 | 38,952,188,248 | +0.000054% |
| `io_text` | 1,585,401,317 | 1,592,793,820 | +0.466268% |
| `large_memory` | 3,050,778,898 | 3,050,779,333 | +0.000014% |
| `multi_clock` | 8,544,222,398 | 8,544,223,860 | +0.000017% |
| `randomize_dv_txn` | 42,336,904,388 | 42,336,904,987 | +0.000001% |
| `randomize_z3` | 13,001,227,393 | 13,001,184,613 | -0.000329% |
| `rtl_alu` | 104,999,983,224 | 105,000,039,565 | +0.000054% |
| `rtl_pipe` | 207,780,755,765 | 207,780,781,613 | +0.000012% |
| `strings_aa_queue` | 73,139,201,992 | 73,136,130,413 | -0.004200% |
| `uvm_config_factory` | 6,177,123,866 | 6,176,788,032 | -0.005433% |
| `uvm_traffic` | 40,681,193,398 | 40,704,335,930 | +0.056867% |
| `vpi_callbacks` | 132,420,587,207 | 113,812,587,413 | **-14.052195%** |
| `waveform_fst` | 14,172,750,460 | 14,194,750,973 | +0.155228% |
| `waveform_vcd` | 14,508,085,075 | 14,552,084,898 | +0.303280% |
| `wide_vectors` | 6,538,332,655 | 6,538,333,119 | +0.000007% |

The target clears the 10% instruction gate. The largest non-target increase is
`io_text` at +0.466268%, below the 2% limit. The build and all three profile
groups exited zero; each output-comparison result is marked `yes` in the
machine-readable tables under `screen/groups/`. Full correctness gates are
pending job submission. This corpus-only result does not claim Caliptra
throughput improvement.
