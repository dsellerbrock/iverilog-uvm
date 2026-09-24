# OpenTitan Icarus DV baseline, 2026-09-23 local

[results.md](results.md) records all 84 per-row status classifications. The runner also wrote a local `results.json` with exact phase commands and log paths; it can be regenerated with the command below. The fresh matrix used clean pinned Earlgrey-PROD-M6 `a78922f14a8cc20c7ee569f322a04626f2ac6127`, pinned UVM 1.2, the current installed Icarus compiler, and the matrix runner's provider mappings. It applied no application-source overlay. `compiler-hashes-start.json` and `compiler-hashes-end.json` match for the driver, compiler engine, VVP target, and runtime; the engine SHA-256 was `bc817f8f3b5fc9571e2ee0aca7d142a3ed22f5fb8ab9b6c525287a8fcbd13662` throughout.

| Scope | Outcome |
| --- | --- |
| 35 UVM compile rows | 8 compiled with debt; 27 failed compilation; 0 clean passes |
| 49 runtime rows (35 UVM targets, 14 directed targets) | 8 checked completions with `TEST PASSED CHECKS` and debt; 36 compilation failures; 4 runtime failures; 1 timeout; 0 clean passes |
| Full selected matrix | 84/84 rows attempted; 0 clean passes; no selected row left unrun |
| Release signoff outside this matrix | 66 signoff configs, 1,914 runnable UVM named-test entries, and 58,515 configured UVM seed runs remain unrun here; the one-smoke-per-target matrix is a different denominator |

The eight `DEBT` runtime rows exited zero and emitted `TEST PASSED CHECKS`. Their runtime logs provide different strengths of traffic evidence; a banner alone does not prove the intended traffic occurred:

| Runtime core | Observable work | Remaining debt |
| --- | --- | --- |
| `aon_timer_sim` | Pass banner; the log has no transaction or scoreboard count. The pinned sequence calls for timer CSR writes and an interrupt, but runtime traffic is not independently measured here. | FuseSoC mapping warnings; reset-port and `always_comb` warnings |
| `gpio_sim` | Pass banner; the log has no transaction or scoreboard count. The pinned sequence calls for input reads and output writes, but runtime traffic is not independently measured here. | FuseSoC mapping warnings; reset-port and `always_comb` warnings |
| `prim_alert_sim` | Logged alert requests and pings with the pass banner | FuseSoC mapping warnings |
| `prim_esc_sim` | Logged escalation and ping activity with the pass banner | FuseSoC mapping warnings |
| `pwrmgr_sim` | Logged scoreboard CSR activity with the pass banner | FuseSoC mapping warnings; reset-port and `always_comb` warnings |
| `tl_agent_sim` | More than 1,000 logged host requests and 2,614 scoreboard items | FuseSoC mapping warnings |
| `top_earlgrey_xbar_main_sim` | 419 logged requests and 838 scoreboard items | FuseSoC mapping warnings |
| `top_earlgrey_xbar_peri_sim` | 180 logged requests and 354 scoreboard items | FuseSoC mapping warnings |

These are runtime observations, not clean conformance or full DV qualification. The matrix marks every one `DEBT` because FuseSoC reports unknown mapping entries during setup; three also have compiler warnings. No warning was suppressed. The 36 runtime `FAIL` rows stopped at compilation, so they did not exercise their named tests. The four `RUNTIME_FAIL` rows did execute but did not pass; the remaining directed runtime row timed out at 120 seconds. Per-row statuses are in [results.md](results.md); the local `results.json` retains selected test names, exact phase commands, diagnostics, and log paths.

Executed from the campaign checkout:

```sh
/opt/homebrew/opt/python@3.13/bin/python3.13 scripts/opentitan_matrix.py \
  --opentitan-root /Users/danielellerbrock/projects/iverilog_uvm/clean-corpora/opentitan-7a3ad34 \
  --build-root evidence/opentitan-icarus-dv-baseline-20260923/work \
  --result-json evidence/opentitan-icarus-dv-baseline-20260923/results.json \
  --result-md evidence/opentitan-icarus-dv-baseline-20260923/results.md \
  --iverilog local-install/bin/iverilog \
  --uvm-home third_party/uvm-releases/sources/1.2/uvm-1.2/src \
  --fusesoc /Users/danielellerbrock/projects/iverilog_uvm/evidence/arm64-tooling/opentitan-python313/bin/fusesoc \
  --fusesoc-python /Users/danielellerbrock/projects/iverilog_uvm/evidence/arm64-tooling/opentitan-python313/bin/python \
  --lane uvm --lane runtime --jobs 4 \
  --setup-timeout 120 --compile-timeout 120 --runtime-timeout 120
```

The runner returned 1 because the matrix contains debt and failures. This census did not run the released VCS/Xcelium signoff flow or all named test seeds. Separate named pwrmgr/xbar release replays, if performed, require their own denominator and compiler fingerprint.
