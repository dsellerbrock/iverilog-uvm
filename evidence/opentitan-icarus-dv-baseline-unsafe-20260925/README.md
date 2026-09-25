# OpenTitan Icarus unsafe DV baseline, 2026-09-25

This is a fresh 84-row, one-smoke-per-target census on Icarus `main` at
`e5eb0901ead2de0fa03ac27d5883d7eac7a2054c` (after PR #371). Every
selected UVM and runtime compile command contains **`-gcommercial-unsafe`**:
84/84, verified in [results.json](results.json) and
[provenance.result.json](provenance.result.json). This is a **nonstandard
compatibility** baseline, separate from IEEE conformance. The pinned OpenTitan
checkout `a78922f14a8cc20c7ee569f322a04626f2ac6127` was clean and
unchanged. No application-source overlay was used in these matrix rows.

| Scope | Status table | Clean matrix passes |
| --- | --- | ---: |
| UVM compile, 35 rows | 8 `DEBT`, 27 `FAIL` | 0/35 |
| Runtime, 49 rows | 8 `DEBT`, 36 `FAIL` at compile, 5 `RUNTIME_FAIL` | **0/49** |
| All selected rows | 16 `DEBT`, 63 `FAIL`, 5 `RUNTIME_FAIL`; no timeout | 0/84 |

The conservative **qualified matrix DV rate is 0/49** under the runner's
zero-debt policy. All eight `DEBT` runtime rows exited zero with one intended
`TEST PASSED CHECKS` marker, no fail marker, and no runtime fatal/assertion
diagnostic. Each retains two unresolved FuseSoC mapping warnings; three also
retain compiler semantic debt. These are checked completions **with debt**,
not clean matrix passes. The matrix does not attempt every released named test
or seed, so 49 is not the full OpenTitan release denominator.

| Completed runtime row | Observed activity | Outstanding evidence/debt |
| --- | --- | --- |
| `aon_timer_sim` | Timer sequence intent and pass marker | No independent transaction count; setup and compile debt |
| `gpio_sim` | Weak-pullup message and pass marker | No independent transaction count; setup and compile debt |
| `prim_alert_sim` | 10 alert-request sequence messages | Setup mapping warnings |
| `prim_esc_sim` | Escalation, ping, and integrity messages | Setup mapping warnings |
| `pwrmgr_sim` | 53 scoreboard entries | Setup and compile debt |
| `tl_agent_sim` | 1,307 host requests and 2,614 scoreboard items | Setup mapping warnings |
| `top_earlgrey_xbar_main_sim` | 838 scoreboard items | Setup mapping warnings |
| `top_earlgrey_xbar_peri_sim` | 354 scoreboard items | Setup mapping warnings |

The per-row [table](results.md) records selected cores, statuses, hard errors,
and debt. [results.json](results.json) records exact setup/compile/runtime
commands, selected tests, diagnostics, and durations. All 181 matrix logs are
in [matrix-logs.tar.gz](matrix-logs.tar.gz), relative to the build root;
[matrix-log-hashes.json](matrix-log-hashes.json) verifies every archived log.
Five cases ran but failed: ADC, pattgen, `prim_present`, `prim_prince`, and
trial1. The earlier [September 23 baseline](../opentitan-icarus-dv-baseline-20260923/README.md)
used a different compiler and default profile. Its `prim_prince` runtime
timeout is now an explicit `dv.stop` runtime failure; the difference cannot
be attributed to the compiler alone because the profile changed too.

The private installed driver/`ivl`/VVP SHA-256 values are
`5e2b9db7ed1068910edef732b59e558463b2521998810041de09884cfbcafb95`,
`20df9f85fbea3da012ffe67b0dff167323a87c20d68f561914d69ceb34c06223`,
and `21ced9054cdb7409534fc73509bf91b0a04d6614736c0a1adb7abd04bb6e49a5`.
The pinned UVM 1.2 source tree fingerprint is
`885ba9f74652494aa132aaaa26c43e9f210f94cdf5a8d3a87064993ec9b35dc0`.
The full seven-component compiler fingerprint remained unchanged throughout
the run, as [provenance.result.json](provenance.result.json) records.

## Separate named compatibility replays

The two previously documented overlay-selected named smokes were recompiled
and run on this same private Icarus image. They are **2/2 selected named
nonstandard compatibility DV**, not additions to the 49 base-source matrix
rows or a full released-suite rate.

| Named smoke | Completed checked result | Remaining limit |
| --- | --- | --- |
| [`otp_ctrl_smoke_vseq`](otp_overlay/result.json) | **1/1**; 1,343 checked TL A and 1,343 TL D pairs; zero UVM warning/error/fatal or assertion failures | 36 explicit unsafe purity warnings; 40 force-RHS and 36 `uwire` compile diagnostics; warned force branches unexercised and no functional coverage-bin hit proven |
| [`csrng_smoke_vseq`](csrng_overlay/qualification.result.json) | **1/1**; checked app-2 instantiate/generate/uninstantiate traffic; zero runtime fatal/assertion errors | One ignored compile-time constraint item and three `uwire` substitutions |

OTP used the documented disposable RAM-path overlay and native DPI. Its
[replay evidence](otp_overlay/README.md) records the hash-checked copied
testbench, exact commands, logs, six retained covergroup bin groups, and all
36 method endpoints.

CSRNG used the documented disposable
[`csrng_blklen_width.patch`](../../docs/conformance/release_overlays/opentitan/csrng_blklen_width.patch)
and native AES DPI. Its [compressed runtime log](csrng_overlay/runtime.log.gz) shows the
checked app-2 sequence. Both original matrix compiles fail without their
respective overlay. The pinned OpenTitan source was not edited.
Generated VVP and DPI binaries remain under
`/private/tmp/ot-dv-baseline-unsafe-20260925/`; overlay records retain their
hashes and rebuild commands.

Run from a checkout of `e5eb0901e` with a private `local-install` and the
native arm64 OpenTitan tool environment:

```sh
OT_PY=/Users/danielellerbrock/projects/iverilog_uvm/evidence/arm64-tooling/opentitan-python313/bin/python
"$OT_PY" scripts/opentitan_matrix.py \
  --opentitan-root /Users/danielellerbrock/projects/iverilog_uvm/clean-corpora/opentitan-7a3ad34 \
  --build-root /private/tmp/ot-dv-baseline-unsafe-20260925/work \
  --result-json evidence/opentitan-icarus-dv-baseline-unsafe-20260925/results.json \
  --result-md evidence/opentitan-icarus-dv-baseline-unsafe-20260925/results.md \
  --iverilog local-install/bin/iverilog \
  --uvm-home /Users/danielellerbrock/projects/iverilog_uvm/iverilog-uvm-campaign-20260908/third_party/uvm-releases/sources/1.2/uvm-1.2/src \
  --fusesoc /Users/danielellerbrock/projects/iverilog_uvm/evidence/arm64-tooling/opentitan-python313/bin/fusesoc \
  --fusesoc-python "$OT_PY" \
  --lane uvm --lane runtime --commercial-unsafe --jobs 4 \
  --setup-timeout 120 --compile-timeout 120 --runtime-timeout 120
```

The runner returned nonzero because debt and failures are present. This run
did not use the separate Caliptra compiler or alter its active job.
