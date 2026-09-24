# DOE scan SVA failure disposition

The only failed case in the complete patched-copy L0 run is `smoke_test_doe_scan`. Its command exits are `[0, 0]`, it emits one `* TESTCASE PASSED` banner, and the simulator log contains one `SVA ERROR: DOE STATUS valid bit not set after clear obf secrets cmd`. The runner classifies the case as failed because any SVA error fails the case. Extract `runs_batch.tar.gz` to inspect `runs_batch/smoke_test_doe_scan.result.json` and `runs_batch/smoke_test_doe_scan/verilator_sim.log` (SHA-256 `7117cbc4e8a7e2669fe246c14de82e679005aca1ad86f65079a99658aa6181b7`).

At `source/src/integration/asserts/caliptra_top_sva.sv:198`, the unchanged pinned assertion is:

```systemverilog
@(posedge `SVA_RDC_CLK)
disable iff (~`DOE_PATH.rst_b)
`CPTRA_TOP_PATH.clear_obf_secrets && `DOE_PATH.rst_b |=>
  (`DOE_REG_PATH.field_storage.DOE_STATUS.VALID.value &&
   `DOE_REG_PATH.field_storage.DOE_STATUS.DEOBF_SECRETS_CLEARED.value)
```

IEEE 1800-2017 Clause 16.12, PDF p. 423, and IEEE 1800-2023 Clause 16.12, PDF p. 442, specify that a `disable iff` condition that becomes true between the start and end of a property attempt disables that evaluation; the standard states that such a condition permits “preemptive resets.” Both personal PDFs are recorded by SHA-256 in `csrng_package_order.md`.

The pinned Caliptra property and existing focused `disable_midwindow.sv` reducer align: the DOE clear antecedent starts an attempt, `rst_b` pulses low and high between assertion clock edges, and the consequent must be aborted even though neither sampled edge sees reset low. Icarus 13.0 reports one failure in the control property without `disable iff` and zero failures in the gated property. Verilator 5.050 and the isolated 5.052 source build report one failure in both, indicating a reset-window behavior mismatch. The existing full DOE replay on 5.052 also emitted exactly one DOE SVA error; this 5.050 full L0 run does the same.

The later [passive released trace](../caliptra-doe-root-cause-20260923/assessment.md) confirms this exact stale pre-reset implication caused the one DOE SVA error; no fresh post-reset antecedent was sampled. No overlay was applied to the assertion or test. Keep the Caliptra case failed until a corrected simulator runs the unchanged test with zero SVA errors; the pass banner and exit status alone are insufficient.
