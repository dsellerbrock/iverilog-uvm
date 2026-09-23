# Caliptra pinned-release exact L0 evidence

Pinned inputs: Caliptra v2.1.2 (`49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e`) and Adams Bridge v2.0.3 (`b77e3d899e828d626cfc2a0d26a6b5704cc121e0`). Scope is exactly 52 selected official L0 tests under Verilator with the recorded KV SVA overlay; this is not the full VCS/UVMF DV suite.

The strict baseline was 49/52: two firmware compile failures and one SVA failure. Both focused overlays passed: `smoke_test_hw_config` and `smoke_test_hmac_errortrigger` (see their `*.overlay.result.json` records). The DOE diagnostic probe still failed: it emitted a pass banner but also one SVA error, so its result is false. See `doe_scan_probe.result.json`; the original patch bytes are preserved as `doe_scan_probe.patch.gz` and the replay runner as `run_doe_probe.py`. Decompress the patch alongside the runner before replaying it.

The original DOE baseline simulator log is preserved byte-for-byte as `smoke_test_doe_scan.baseline.sim.log.gz`. The complete external campaign logs remain at `/Users/danielellerbrock/projects/iverilog_uvm/evidence/caliptra-exact-l0-20260923/`. In particular, DOE build output is `doe_scan_probe.make.stdout` and `doe_scan_probe.make.stderr`; its full simulator log is under `runs/doe_scan_probe/verilator_sim.log`. Baseline per-test logs and build records are under `runs_batch/` in that external directory. Large build artifacts and other logs are intentionally not copied here.

The archived Python runners expect `source/` (a disposable pinned-release copy) and `aliases/` (the verified toolchain executables) beside them. Run them from a separate evidence directory with those inputs; never from a pinned checkout. The exact options, hashes, and per-test classifications are in `baseline_summary.json`.
