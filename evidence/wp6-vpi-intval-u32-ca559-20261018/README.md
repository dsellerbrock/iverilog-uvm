# WP6 VPI integer conversion fast path — unsigned result temporary

Pinned measurement base: `ca559fd97b19bd6a56cc10f0faf8583b4077975f`.

The first screened implementation used a signed 32-bit temporary. Review found that the shared helper's signed mask can overflow when the high bit is set; that predecessor is preserved in `../wp6-vpi-intval-ca559-20261018/` and is not the qualifying candidate. The final implementation uses the existing `uint32_t` specialization, whose mask shifts are defined for all 32 result bits.

## Profile and change

The current-main profile sampled `vpip_vec4_get_value` at 17.57% self time in `vpi_callbacks`. That benchmark registers a value-change callback on a one-bit signal and requests `vpiIntVal` for 32 million value changes. The old conversion loop examined all 64 positions of a `long` for every callback. `vpip_vec4_get_value` is shared by VPI signal, callback, array, constant, class-member, and dynamic-array accessors, so the change is limited to the shared `vpiIntVal` branch.

The candidate delegates to the existing `vector4_to_value` helper with a 32-bit unsigned result. It preserves low-32-bit VPI integer conversion, signed extension, and X/Z-to-zero behavior. The size check preserves the prior zero-width result without calling the helper on an empty vector. No test golds or dependencies changed.

## Pinned-base instruction screen

Callgrind screening used reference and candidate builds from the pinned base. The target `vpi_callbacks` fell from 132,420,586,018 to 113,812,586,195 instructions (−14.052196%). Every non-target row stayed within the 2% regression limit; the largest increase was `io_text` at +0.466298%. All 18 captured outputs were byte-identical.

| Workload | Reference instructions | Candidate instructions | Change | Output |
|---|---:|---:|---:|---|
| behav | 86,006,376,936 | 86,033,411,050 | +0.031433% | identical |
| classq | 120,667,383,970 | 120,728,984,004 | +0.051049% | identical |
| fork_heavy | 433,052,607 | 433,052,863 | +0.000059% | identical |
| gate_strength | 38,952,164,528 | 38,952,185,443 | +0.000054% | identical |
| io_text | 1,585,400,720 | 1,592,793,413 | +0.466298% | identical |
| large_memory | 3,050,778,317 | 3,050,778,760 | +0.000015% | identical |
| multi_clock | 8,544,220,146 | 8,544,221,973 | +0.000021% | identical |
| randomize_dv_txn | 42,335,418,287 | 42,335,588,523 | +0.000402% | identical |
| randomize_z3 | 13,001,276,017 | 13,001,217,548 | −0.000450% | identical |
| rtl_alu | 104,999,990,138 | 105,000,036,801 | +0.000044% | identical |
| rtl_pipe | 207,780,749,265 | 207,780,771,493 | +0.000011% | identical |
| strings_aa_queue | 73,122,700,056 | 73,124,581,383 | +0.002573% | identical |
| uvm_config_factory | 6,176,526,025 | 6,176,440,209 | −0.001389% | identical |
| uvm_traffic | 40,668,212,138 | 40,691,297,807 | +0.056766% | identical |
| vpi_callbacks | 132,420,586,018 | 113,812,586,195 | −14.052196% | identical |
| waveform_fst | 14,172,749,558 | 14,194,749,911 | +0.155230% | identical |
| waveform_vcd | 14,508,084,635 | 14,552,085,008 | +0.303282% | identical |
| wide_vectors | 6,538,332,074 | 6,538,332,594 | +0.000008% | identical |

Raw build and Callgrind artifacts, per-group CSVs, output checksums, and provenance are preserved in `screen-artifacts.tar.gz` (SHA-256 `d5c83f2418b8c10b14b5e96a044938696c9b3e3525876877f096b5c2ed2e122b`). Candidate patch SHA-256: `3f7ae4ef3cd3f0efde80c1b65b2416ac42a26ec11f8b714a9ee0f22f65cac036`.

## Correctness gates

Slurm job 2556 built the pinned candidate and passed `make check`, FPGA target
install, and `.github/ivtest_gate.sh`: 7,477 legacy tests (0 failed), VPI
133/133, negative 152/152, runtime invariants 15/15, and JSON 4,718/4,718. The
real-DPI UVM suite passed 367/367. Its semantic stage did not execute because
the archived wrapper was stored under `semantic/` while the gate script expected
`input/semantic-check.sh`; job 2556 therefore exited 1 before that stage could
run. The packaging failure and original logs are preserved under
`attempts/gates-2556/`.

Slurm job 2575 reran the omitted semantic stage with the wrapper and fixtures at
their archived paths. It passed the reference/candidate VPI integer comparison
using the same pinned candidate build. The semantic run and binary checksums are
in `attempts/gates-2556/semantic-rerun/`. No code or test failure occurred in
either job.

## Final wall-time support

Pending for unsigned candidate.
