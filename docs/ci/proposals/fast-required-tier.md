# Proposal: fast required pull request tier

## Proposal

Require a small Linux smoke tier for pull requests, then run the complete Linux, macOS, and Windows matrix after merge and on manual dispatch. Keep the full matrix available for pre-merge validation when a change needs platform-specific coverage.

Recommend moving macOS and Windows to the post-merge/nightly tier. If they must remain pre-merge, split the macOS workflow so no job approaches GitHub's six-hour job limit.

The smoke candidate covers 55 named SystemVerilog regressions, all 14 standalone root reproducers, VPI, runtime, and negative tests through `ci/run-smoke.sh`. Measure its clean runtime before setting a timeout or promising a merge-time target.

## Evidence

Across the 12 failed main pushes from October 1–8, 9 have confirmed test failures on both Linux lanes (75%). One additional run had a Linux runner shutdown and an Ubuntu 24.04 failure whose log is unavailable, so it is not counted as a confirmed Linux test failure. Another run had runner shutdowns on both Linux lanes; the remaining run failed only on CLANG64 and MINGW64, whose logs are unavailable. The 20 cancellations on October 9–10 were concentrated in two merge bursts (19 pushes and one workflow dispatch); GitHub's run metadata records cancellation but does not expose who or what requested it.

### October 1–8 failed pushes

| Date | Run / PR | Cause recorded in the run |
|---|---|---|
| Oct 1 | `36943239641` / #395 | Both Linux lanes: 26 unexplained legacy ivtest failures, mainly constraint, covergroup, and randomize cases. VPI and negative suites passed. |
| Oct 4 | `37213739987` / #398 | Both Linux lanes: two `sv_assert_control_lookup_stress` failures and one VPI failure. |
| Oct 6 | `37401666432` / #399 | Same two assertion stress failures and one VPI failure on both Linux lanes. |
| Oct 6 | `37479307431` / #400 | Ubuntu 22.04 received a runner shutdown; Ubuntu 24.04 also failed, but its log is unavailable. Cause unclassified. |
| Oct 6 | `37535314710` / #401 | Both Linux runners received shutdown signals before a test verdict. |
| Oct 7 | `37623824656` / #404 | CLANG64 and MINGW64 failed; Linux, macOS, and UCRT64 passed. Windows failure logs are unavailable. |
| Oct 7 | `37629386754` / #409 | Both Linux lanes: 33 unexplained legacy ivtest failures, including array-method and packed-select cases, plus one negative test. |
| Oct 7 | `37658707574` / #410 | Same broad 33-test legacy failure set and one negative test on both Linux lanes. |
| Oct 7 | `37661942350` / #411 | Same broad 33-test legacy failure set and one negative test on both Linux lanes. |
| Oct 7 | `37676854612` / #412 | Legacy ivtest and VPI passed; the negative suite failed 1/153 tests on both Linux lanes. |
| Oct 8 | `37718279104` / #413 | Legacy ivtest and VPI passed; the negative suite failed 1/153 tests on both Linux lanes. |
| Oct 8 | `37840321800` / #464 | Both Linux lanes: 10 unexplained legacy failures (`pr2835632b`, `pr2913927`, `pr3054101a`–`f`, `sel_rval_bit_ob`, `sel_rval_part_ob`) and one negative test. |

### October 9–10 canceled pushes

All 20 workflows ended `cancelled` without a test verdict. The runs clustered around main merge bursts; because the workflow does not record the cancellation actor/reason, attributing them to supersession is an inference.

| Date | Canceled run IDs | Event |
|---|---|---|
| Oct 9 | `37993384595`, `37993359932`, `37978035969`, `37972539936`, `37967303994`, `37951701271`, `37951663257`, `37948145051`, `37945612789`, `37944919915`, `37943163099`, `37943130027`, `37942803421`, `37942530138` | 14 pushes |
| Oct 10 | `38057336322`, `38057241343`, `38057169396`, `38056834824`, `38056730941` | 5 pushes |
| Oct 10 | `38057476573` | 1 manual dispatch |

Median completed job durations across those 12 pushes were 35.9 minutes on Ubuntu 24.04 (n=12), 39.2 minutes on Ubuntu 22.04 (n=12), 155.4 minutes on CLANG64 (n=10), 155.4 minutes on MINGW64 (n=10), 158.0 minutes on UCRT64 (n=10), and 265.8 minutes on macOS (n=10).

On October 12, the main GitHub run for `9cfce137` was cancelled at the six-hour job limit during macOS UVM front-end regression; the other five lanes passed. This shows that a single per-pull-request macOS job can consume the full hosted-runner limit before reaching a verdict.

## Tradeoff

This shortens the default PR feedback path but moves some macOS and Windows failures to post-merge detection. Keep a manual full-matrix path and have the nightly Slurm gate cover the main branch. Splitting the macOS workload preserves pre-merge coverage but adds workflow complexity and still leaves a multi-hour gate.

## Status

Approved implementation is tracked in PR #547. Pull requests run the `Fast Linux` build and smoke job; main pushes, the 10:17 UTC nightly schedule, and manual dispatch run the full platform matrix. macOS runs its SystemVerilog regressions, other regressions, UVM suite, and UVM front-end suite as separate jobs with a 240-minute timeout each.
