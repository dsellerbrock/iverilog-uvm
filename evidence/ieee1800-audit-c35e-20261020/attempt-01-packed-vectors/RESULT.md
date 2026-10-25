# Clause 35 packed-vector and fixed-array ABI results

Slurm job 3595 ran the existing M10 tests on DAN-DESKTOP with Icarus `cc25756d1`
and GCC 15.2.0, using 1 CPU and 1 GiB. Every compile, link, and simulation
command returned 0 under both `-g2017` and `-g2023`; each test printed its
expected `PASS` marker, and stderr was empty.

| Edition | Test | Compile | Link | Run | Result |
|---|---|---:|---:|---:|---|
| 2017 | `m10_dpi_wide_vector_test` | 0 | 0 | 0 | PASS |
| 2017 | `m10_dpi_fixed_packed_array_abi_test` | 0 | 0 | 0 | PASS |
| 2023 | `m10_dpi_wide_vector_test` | 0 | 0 | 0 | PASS |
| 2023 | `m10_dpi_fixed_packed_array_abi_test` | 0 | 0 | 0 | PASS |

The wide-vector test covers 72-bit 2-state and 4-state packed vectors,
preservation of X/Z in `svLogicVecVal`, explicit packed vectors at 32/64 bits,
scalar versus one-bit packed-vector ABI shape, packed aggregates, and related
canonical representations. The fixed-array test covers fixed unpacked arrays
of packed `bit` and `logic` elements, including 40-bit values and X/Z copy-back.

This supports only the listed IEEE 1800-2017/2023 §§35.5.5–35.5.6 and Annex H
cases; it is not a claim of full DPI ABI conformance. Job 3594's wide-vector
compile failure was a probe-harness error: it selected the nonexistent root
`m10_dpi_wide_vector_test` instead of the declared
`m10_dpi_wide_vector_test_top`. The fixed-array case passed in that run too.
The corrected job 3595 passed all four edition/test combinations.

Raw timing, host/tool versions, SHA-256 values, and logs are in
[`remote-3595/`](remote-3595/). The original harness and its failed selection
are preserved in [`remote-3594/`](remote-3594/).
