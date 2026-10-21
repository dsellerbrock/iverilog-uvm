# Normalized Clause 32 SDF probe

Reruns the paired-edition probe from [attempt 03](../attempt-03-remaining/README.md) with output comparisons limited to post-stimulus `Y` events. `$finish` and startup path chatter no longer contaminate checks. A feature mismatch is reported as `FEATURE_EXPECTATION_MISMATCH`; compile/run failures or any `SDF ERROR` make `HARNESS_STATUS` nonzero.

The probe covers timing-check mapping, `mtm_spec`, `scale_factors`/`scale_type`, and SDF interconnect annotation. Sources and dedupe are shared from [attempt 03](../attempt-03-remaining/).
