# Application priority assessment — 2026-09-15

Installed compiler semantic revision `366ef2bf1`; current source HEAD `4b1e74b1c`
has frozen, unbuilt L106/L107 patches. The [record](2026-09-15_application_priority_assessment.json)
contains exact commands, fingerprints, corpus revisions and per-row diagnostics.
Upstream application sources were not changed.

## OpenTitan

Fresh original-UVM-1.2 replay of the pinned Darjeeling debug crossbar
`xbar_smoke` / `xbar_base_test` / `xbar_smoke_vseq` completes setup but fails
compilation at two object-method calls, `mubi_cov.create_cov` and
`mubi_cov.sample`. The diagnostic instead treats the property name as the
unrelated parameterized class `mubi_cov` and requires specialization before `::`.
This is the next name-resolution assessment; no runtime pass is established.

Historical September 11 evidence at workspace
`evidence/campaign-20260908/l17/opentitan/result.json` recorded a successful
original-UVM-1.2 smoke with 152 requests, 288 scoreboard items and zero UVM
warnings/errors/fatals. That result is historical, and the fresh failure above
supersedes any inference that it still passes on the installed compiler.
Restoration requires traffic, scoreboard checking, drained pending work and
normal completion, followed by additional seeds and application coverage.

## Caliptra

Replayed the 32 prior rows stopped by missing `abr_prim_assert.sv`, adding
only the existing Adams Bridge `src/abr_prim/rtl` include directory to each
original assertions-enabled command: 19 clean compilations, two exit-zero
compilations with warnings, and 11 remaining failures. Remaining diagnostics
are retained, including missing additional inputs, top selection and stale
port/parameter references. They require individual triage.

Separate baseline-versus-include probes for `decompose`, `pcrvault` and `aes`
all move from errors to clean compilation. Decompose is already included in
the 32-row result and must not be counted twice. These are build configuration
results, not compiler feature implementations or simulation passes. No updated
whole-census total is claimed; the September 13 105-row record stays historical.

## Resumption

The coordinator preserved exact pending compiler source patches and hashes at
`evidence/application-check-20260915/preserved-l106-l107/`. The two existing
agents assess disjoint OpenTitan lookup and Caliptra build-input causes.
Implementation selection and acceptance criteria belong to ACTIVE_WORK; shared
builds, installation and application harnesses remain coordinator-owned.
