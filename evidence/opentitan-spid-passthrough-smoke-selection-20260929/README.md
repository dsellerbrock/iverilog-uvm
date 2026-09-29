# SPI passthrough smoke-test selection

The frozen `lowrisc:dv:spid_passthrough_sim:0.1` matrix row ran with only `+smoke_test=1`; the host requested `+TESTNAME` and exited without running a case. Pinned `spid_passthrough_sim_cfg.hjson` lists `spid_passthrough_readbasic` first in the smoke regression with `+TESTNAME=readbasic`. The matrix now admits a regression test with a concrete, test-local `+TESTNAME` run option even when it has no UVM sequence.

- Pre-fix inventory: `dvsim_test=None`, runtime arguments `['+smoke_test=1']`.
- Post-fix inventory: `dvsim_test=spid_passthrough_readbasic`, runtime arguments `['+TESTNAME=readbasic', '+smoke_test=1']`. All other 48 frozen rows kept the same test, runtime arguments, and UVM test/sequence metadata; see `metadata-selection.json`.
- Matrix self-test: PASS on Python 3.13.
- One-core selected replay: VVP exits zero in 4.073 seconds, reaches the pinned `test_readbasic`/`compare_storage` path and prints one `TEST PASSED CHECKS`; zero hard/runtime errors, no 2 GiB footprint cap or 120-second timeout hit. Sampled peak footprint 106,185,184 bytes.
- **Verdict: DEBT.** Nine compile semantic notices and two runtime `$value$plusargs()` task-call warnings remain in `matrix-result.json`, `matrix-compile.log`, and `matrix-runtime.log`. A pass banner does not clear them.

The pinned OpenTitan source and frozen 23 PASS / 49 aggregate remain unchanged.
