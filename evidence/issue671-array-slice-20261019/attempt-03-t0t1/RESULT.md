## Attempt 03 — T0 stopped in test registration

Slurm job 3148 built and installed commit `750e3e4e2`. The issue legacy list then stopped before JSON, smoke, or T1: the base entry failed at compile time, and the 2023 entry had no matching `ivltests/sv_dynamic_array_slice_class_property_2023.v` source. Review also found the legacy list requested top module `sv_dynamic_array_slice_class_property`, while the source declares `module test`. The runner summary and compiler hashes are preserved under `raw-slurm-3148/`; the per-test compiler log was not copied in this attempt, so the underlying base-entry diagnostic remains unverified.

This is not a feature verdict. The next attempt adds the 2023 include wrapper, corrects both legacy top-module selections, and preserves per-test compiler logs before exiting.
