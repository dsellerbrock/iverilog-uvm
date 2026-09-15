# L116 first_match ranged source suffix — 2026-09-15

L116 extends L114's finite first-clock `first_match` prefix transport through a finite ranged Boolean/delay suffix. The wrapper still commits at its earliest ending tick under IEEE 1800-2017/2023 §16.9.8. The suffix remains outside that wrapper, so all of its finite endpoints remain eligible. Plain multiclock sequence evaluation uses existential completion; implication evaluation creates a consequence child for every suffix endpoint and aggregates them under the original parent (§16.12.7 and §16.13).

The source change removes the exact-delay restriction after the retained wrapper boundary and limits immediate full-accept closure to a whole-chain wrapper. Prefix-with-suffix state uses the established dead/depth CLOSE path. L114 boundary-only guards continue to cut the wrapper before a fused `##0` suffix guard, which is why `[0:1]` can reject its zero-delay branch yet retain its one-tick branch.

Evidence:

- reviewed baseline/oracle: `next-sva-after-l114/assessment.md`
- focused initial and boundary results: coordinator evidence under `evidence/application-check-20260915/l115-revised/`
- focused 22-entry validation: both legacy and JSON passed
- unbounded paired diagnostic: `evidence/application-check-20260915/l115-l116-focused/unbounded/result.json`
- L114 migrated negative preserved in `evidence/application-check-20260915/l116-migrated-l114/`

Private focus lists now contain 24 entries each:

- `ivtest/regress-multiclock-first-match-ranged-suffix-legacy.list`
- `ivtest/regress-multiclock-first-match-ranged-suffix-vvp.list`

The bounded scope excludes unbounded/symbolic suffix delays, repetition, match items and local variables, nested or non-prefix wrappers, and scheduler/runtime changes. Depth is capped by the existing finite source-NFA 64-state admission rule; paired 64/65 controls preserve that boundary.

Final focused validation: 24/24 in each harness; 72/72 neighboring cases in each harness; 58/58 NFA parity cases. Broad qualification pending. Exact logs and source fingerprint are in [the validation record](2026-09-15_first_match_ranged_suffix_validation.json).
