# Fixed multiclock assertion control — 2026-09-15

L92 fixes DD032: fixed multiclock pipelines started new attempts after
`$assertoff` and `$assertkill`. The source start gate now uses the existing
instance-scoped enabled-state helper for both implication antecedents and
plain first-clock prefixes. Pending stages remain ungated, so Off permits
existing attempts to finish. The existing kill-generation reset discards
pending work and On permits fresh starts.

IEEE 1800-2017/2023 20.12 governs controls; 16.12.7 and 16.14 govern the
preserved implication and action behavior. The [focused record](2026-09-15_fixed_multiclock_assertion_control_validation.json)
contains exact commands, fingerprints, baseline failures and paired checks.
Cases cover pending success/failure, disabled vacuity, exact repetition,
plain/implication prefixes, restart, coincident clocks, and selected assertion
and cover isolation. The L86/L91 and NFA checks retain adjacent semantics.
Broad batch gates and whole-application qualification remain pending.
