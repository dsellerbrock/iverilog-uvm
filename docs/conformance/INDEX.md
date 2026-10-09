# IEEE 1800 conformance index

**Census date:** 2026-10-08. This is the concise front door for IEEE 1800-2017/2023 gaps. There is **no 50-issue cap**: the 50 pre-census issues below are simply the existing open backlog. Represent each distinct verified gap in GitHub, and file uncertain but actionable standards questions only as clearly labeled validation issues. The list is not a priority queue.

## Current selection

The active campaign item is [issue #415](https://github.com/dsellerbrock/iverilog-uvm/issues/415), in [draft PR #524](https://github.com/dsellerbrock/iverilog-uvm/pull/524) targeting `main`. Its branch is `agent/ieee-nested-array-return-20261009` and includes latest `origin/main` at `0d8815feb`, including the VVP performance changes merged in PR #521. Focused array-return legacy and JSON/VVP lists pass 12/12 each. The broad legacy gate was stopped after five minutes in `sv_randomize_global_uniform` and has no aggregate result. Superseded active PR runs were canceled; checks for the current exact head are pending. **No green CI status is claimed**.

The `ACTIVE_WORK.yaml` and `CAMPAIGN.yaml` updates for #415 are on PR #524. The [issue checkout map](../../.ai/ISSUE_CHECKOUT.csv) on `main` remains a historical checkout record until that PR merges.

## Inventory

There are **93 open IEEE issues**: **50 existing** issues (#414–#463) and **43 new active issues** (#468–#469, #471–#502, #505–#513), of which 41 are new issues for reproduced gaps and #512/#513 are validation-only standards questions. The census created **45 issues total** (#468–#503 and #505–#513); [#503](https://github.com/dsellerbrock/iverilog-uvm/issues/503) was closed after its claimed defect was found fixed, and [#470](https://github.com/dsellerbrock/iverilog-uvm/issues/470) was closed after the current-main reducer and registered SVA controls passed. Thus 43 census-created issues remain open. Six existing issues were refreshed with debt evidence: [#414](https://github.com/dsellerbrock/iverilog-uvm/issues/414) (DD-078), [#419](https://github.com/dsellerbrock/iverilog-uvm/issues/419) (DD-047 and DD-068), [#421](https://github.com/dsellerbrock/iverilog-uvm/issues/421) (DD-109), [#429](https://github.com/dsellerbrock/iverilog-uvm/issues/429) (DD-057), [#439](https://github.com/dsellerbrock/iverilog-uvm/issues/439) (DD-052), and [#440](https://github.com/dsellerbrock/iverilog-uvm/issues/440) (DD-051). A paired clean-main evidence comment was also added to existing [#448](https://github.com/dsellerbrock/iverilog-uvm/issues/448).

The final catalog sweep covers all 111 numbered debt records, the complete 2017 clause matrix, the complete 2023 delta survey, and current open/closed GitHub issue state. There is **no cap**: every distinct verified, actionable IEEE gap in these sources must have one open issue, while fixed, duplicate, unsupported, or non-actionable records are linked or explicitly excluded below. The catalog is complete for this source set; issue state is a tracking status, not selection priority. Details stay in the [blockers registry](BLOCKERS.md), [discovered-debt ledger](DISCOVERED_DEBT.md), [2017 clause matrix](matrices/ieee1800_2017_clause_matrix.md), and [2023 delta survey](ieee1800_2023_delta.md).

### Pre-census issues still open: 50

<details>
<summary>Show #414–#463</summary>

| Issue | Title |
| --- | --- |
| [#414](https://github.com/dsellerbrock/iverilog-uvm/issues/414) | [IEEE 1800] §11 — Guard each dimension of runtime packed selects |
| [#415](https://github.com/dsellerbrock/iverilog-uvm/issues/415) | [IEEE 1800] §§10.9.1/13.4.1 — Accept array-return values in nested assignment patterns |
| [#416](https://github.com/dsellerbrock/iverilog-uvm/issues/416) | [IEEE 1800] §18 — Sample sparse coupled constraints exactly beyond the bounded fallback |
| [#417](https://github.com/dsellerbrock/iverilog-uvm/issues/417) | [IEEE 1800] §18 — Preserve uniformity for constrained dynamic-array tuples |
| [#418](https://github.com/dsellerbrock/iverilog-uvm/issues/418) | [IEEE 1800] §18 — Solve coupled parent and child class constraints |
| [#419](https://github.com/dsellerbrock/iverilog-uvm/issues/419) | [IEEE 1800] §18 — Randomize class-handle and container-member variables |
| [#420](https://github.com/dsellerbrock/iverilog-uvm/issues/420) | [IEEE 1800] §18 — Extend exact randc cycle coverage past current domain limits |
| [#421](https://github.com/dsellerbrock/iverilog-uvm/issues/421) | [IEEE 1800] §18 — Define standard packed-select randomization semantics |
| [#422](https://github.com/dsellerbrock/iverilog-uvm/issues/422) | [IEEE 1800] §7 — Complete locator methods on fixed-array receiver shapes |
| [#423](https://github.com/dsellerbrock/iverilog-uvm/issues/423) | [IEEE 1800] §7 — Copy aggregate elements returned by locator methods |
| [#424](https://github.com/dsellerbrock/iverilog-uvm/issues/424) | [IEEE 1800] §7 — Preserve locator result types through expression wrappers |
| [#425](https://github.com/dsellerbrock/iverilog-uvm/issues/425) | [IEEE 1800] §7 — Support associative-array min/max receivers |
| [#426](https://github.com/dsellerbrock/iverilog-uvm/issues/426) | [IEEE 1800] §7 — Support assignment-pattern keys from expressions and remaining types |
| [#427](https://github.com/dsellerbrock/iverilog-uvm/issues/427) | [IEEE 1800] §7 — Preserve nested container-element ref aliases |
| [#428](https://github.com/dsellerbrock/iverilog-uvm/issues/428) | [IEEE 1800] §7 — Support runtime fixed-array prefixes across aggregate copies |
| [#429](https://github.com/dsellerbrock/iverilog-uvm/issues/429) | [IEEE 1800] §7 — Resolve indexed class-array member operations |
| [#430](https://github.com/dsellerbrock/iverilog-uvm/issues/430) | [IEEE 1800] §10 — Snapshot unpacked-array function results for NBA updates |
| [#431](https://github.com/dsellerbrock/iverilog-uvm/issues/431) | [IEEE 1800] §10 — Snapshot runtime-sized concatenation targets for delayed/NBA updates |
| [#432](https://github.com/dsellerbrock/iverilog-uvm/issues/432) | [IEEE 1800] §10 — Enforce function call contexts for nonblocking assignments |
| [#433](https://github.com/dsellerbrock/iverilog-uvm/issues/433) | [IEEE 1800] §13 — Enforce task/function call restrictions in nonprocedural and final contexts |
| [#434](https://github.com/dsellerbrock/iverilog-uvm/issues/434) | [IEEE 1800] §13 — Preserve automatic aggregate values containing captured handles |
| [#435](https://github.com/dsellerbrock/iverilog-uvm/issues/435) | [IEEE 1800] §6 — Support class-method resolution functions for user-defined nettypes |
| [#436](https://github.com/dsellerbrock/iverilog-uvm/issues/436) | [IEEE 1800] §6 — Resolve selected and generic operands in interconnect concatenations |
| [#437](https://github.com/dsellerbrock/iverilog-uvm/issues/437) | [IEEE 1800] §14 — Support runtime-selected clocking-block output drives |
| [#438](https://github.com/dsellerbrock/iverilog-uvm/issues/438) | [IEEE 1800] §14 — Complete unpacked and selected clockvar output targets |
| [#439](https://github.com/dsellerbrock/iverilog-uvm/issues/439) | [IEEE 1800] §15 — Support explicit triggered() calls on event expressions |
| [#440](https://github.com/dsellerbrock/iverilog-uvm/issues/440) | [IEEE 1800] §15 — Preserve merged-event trigger semantics |
| [#441](https://github.com/dsellerbrock/iverilog-uvm/issues/441) | [IEEE 1800] §15 — Implement wait_order ordering and failure behavior |
| [#442](https://github.com/dsellerbrock/iverilog-uvm/issues/442) | [IEEE 1800] §16 — Capture deferred assertion action subroutine/ref/fixed-array arguments |
| [#443](https://github.com/dsellerbrock/iverilog-uvm/issues/443) | [IEEE 1800] §16 — Account for deferred cover in coverage databases and VPI |
| [#444](https://github.com/dsellerbrock/iverilog-uvm/issues/444) | [IEEE 1800] §16 — Cancel deferred assertion reports on disable and kill |
| [#445](https://github.com/dsellerbrock/iverilog-uvm/issues/445) | [IEEE 1800] §16 — Expose deferred-immediate assertion identity and results through VPI |
| [#446](https://github.com/dsellerbrock/iverilog-uvm/issues/446) | [IEEE 1800] §16 — Support variable-length multiclock antecedents |
| [#447](https://github.com/dsellerbrock/iverilog-uvm/issues/447) | [IEEE 1800] §16 — Apply disable iff across branching multi-boundary sequences |
| [#448](https://github.com/dsellerbrock/iverilog-uvm/issues/448) | [IEEE 1800] §19 — Retain constructor and per-instance coverage expressions |
| [#449](https://github.com/dsellerbrock/iverilog-uvm/issues/449) | [IEEE 1800] §13.5 — Implement ref static task/function arguments |
| [#450](https://github.com/dsellerbrock/iverilog-uvm/issues/450) | [IEEE 1800] §8 — Support associative-array-typed parameters |
| [#451](https://github.com/dsellerbrock/iverilog-uvm/issues/451) | [IEEE 1800] §8 — Support restricted class type parameters |
| [#452](https://github.com/dsellerbrock/iverilog-uvm/issues/452) | [IEEE 1800] §8 — Implement the type(this) self type |
| [#453](https://github.com/dsellerbrock/iverilog-uvm/issues/453) | [IEEE 1800] §7 — Implement soft packed unions |
| [#454](https://github.com/dsellerbrock/iverilog-uvm/issues/454) | [IEEE 1800] §8 — Accept the constructor default argument keyword |
| [#455](https://github.com/dsellerbrock/iverilog-uvm/issues/455) | [IEEE 1800] §8 — Implement method override specifiers |
| [#456](https://github.com/dsellerbrock/iverilog-uvm/issues/456) | [IEEE 1800] §18 — Implement constraint override specifiers |
| [#457](https://github.com/dsellerbrock/iverilog-uvm/issues/457) | [IEEE 1800] §19 — Support covergroup inheritance |
| [#458](https://github.com/dsellerbrock/iverilog-uvm/issues/458) | [IEEE 1800] §20 — Implement $timeunit and $timeprecision system functions |
| [#459](https://github.com/dsellerbrock/iverilog-uvm/issues/459) | [IEEE 1800] §20 — Add the $stacktrace string-function form |
| [#460](https://github.com/dsellerbrock/iverilog-uvm/issues/460) | [IEEE 1800] §22 — Parse parenthesized boolean `ifdef expressions |
| [#461](https://github.com/dsellerbrock/iverilog-uvm/issues/461) | [IEEE 1800] §8 — Implement weak_reference#(T) |
| [#462](https://github.com/dsellerbrock/iverilog-uvm/issues/462) | [IEEE 1800] §11 — Implement tolerance range operators |
| [#463](https://github.com/dsellerbrock/iverilog-uvm/issues/463) | [IEEE 1800] §18 — Expand rand real beyond scalar finite intervals |

</details>

### New issues: 43 open

<details>
<summary>Show #468–#469, #471–#502, and #505–#513</summary>

| Issue | Title |
| --- | --- |
| [#468](https://github.com/dsellerbrock/iverilog-uvm/issues/468) | [IEEE 1800] §22 — Accept escaped identifiers in conditional compilation |
| [#469](https://github.com/dsellerbrock/iverilog-uvm/issues/469) | [IEEE 1800] §§6.11.2/11.5.1 — Preserve two-state packed-select results |
| [#471](https://github.com/dsellerbrock/iverilog-uvm/issues/471) | [IEEE 1800] §11.5.1 — Keep packed subpart accesses inside the selected element |
| [#472](https://github.com/dsellerbrock/iverilog-uvm/issues/472) | [IEEE 1800] §6.5 — Accept disjoint mixed-driver packed elements |
| [#473](https://github.com/dsellerbrock/iverilog-uvm/issues/473) | [IEEE 1800] §§6.11/11.3 — Convert assignment-expression results to two-state destinations |
| [#474](https://github.com/dsellerbrock/iverilog-uvm/issues/474) | [IEEE 1800] §§10.9/6.22 — Elaborate fixed-array parameter assignment patterns and element reads |
| [#475](https://github.com/dsellerbrock/iverilog-uvm/issues/475) | [IEEE 1800] §16 — Bind mixed-type assertion-local declarations consistently |
| [#476](https://github.com/dsellerbrock/iverilog-uvm/issues/476) | [IEEE 1800] §16 — Support selected lvalues in sequence match-item assignments |
| [#477](https://github.com/dsellerbrock/iverilog-uvm/issues/477) | [IEEE 1800] §§13.5.2/6.22.2 — Reject non-equivalent ref actual types |
| [#478](https://github.com/dsellerbrock/iverilog-uvm/issues/478) | [IEEE 1800] §§18.5.9/18.7 — Resolve inline constraint aliases by object identity |
| [#479](https://github.com/dsellerbrock/iverilog-uvm/issues/479) | [IEEE 1800] §18.7 — Bind explicit `this` in inline constraints to the target class |
| [#480](https://github.com/dsellerbrock/iverilog-uvm/issues/480) | [IEEE 1800] §§20.18.1/20.17.1 — Reject excess `$system` arguments |
| [#481](https://github.com/dsellerbrock/iverilog-uvm/issues/481) | [IEEE 1800] §19.5.4 — Preserve four-state values during coverage bin matching |
| [#482](https://github.com/dsellerbrock/iverilog-uvm/issues/482) | [IEEE 1800] §§19.3/25.9 — Sample covergroups through virtual interfaces |
| [#483](https://github.com/dsellerbrock/iverilog-uvm/issues/483) | [IEEE 1800] §13.5.2 — Allow const-ref forwarding to const-ref formals |
| [#484](https://github.com/dsellerbrock/iverilog-uvm/issues/484) | [IEEE 1800] §§7.4/7.8 — Support associative arrays with fixed-array elements |
| [#485](https://github.com/dsellerbrock/iverilog-uvm/issues/485) | [IEEE 1800] §§7.6/7.8 — Validate variable-size associative pattern values transactionally |
| [#486](https://github.com/dsellerbrock/iverilog-uvm/issues/486) | [IEEE 1800] §7.8.6 — Warn when reading a nonexistent associative entry |
| [#487](https://github.com/dsellerbrock/iverilog-uvm/issues/487) | [IEEE 1800] §12.7.3 — Traverse packed ranks after runtime and omitted array dimensions |
| [#488](https://github.com/dsellerbrock/iverilog-uvm/issues/488) | [IEEE 1800] §11.5.1 — Preserve indexed part-select orientation on ascending class properties |
| [#489](https://github.com/dsellerbrock/iverilog-uvm/issues/489) | [IEEE 1800] §18.3 — Diagnose four-state values in constraints |
| [#490](https://github.com/dsellerbrock/iverilog-uvm/issues/490) | [IEEE 1800] §7.12.2 — Apply ordering methods to fixed class-property arrays |
| [#491](https://github.com/dsellerbrock/iverilog-uvm/issues/491) | [IEEE 1800] §§18.5.10/18.5.9 — Preserve solve-before targets in fixed-array queues |
| [#492](https://github.com/dsellerbrock/iverilog-uvm/issues/492) | [IEEE 1800] §§7.6/23.3.3 — Connect unpacked-array output ports to array slices |
| [#493](https://github.com/dsellerbrock/iverilog-uvm/issues/493) | [IEEE 1800] §10.6 — Release selected packed subfields without a target assertion |
| [#494](https://github.com/dsellerbrock/iverilog-uvm/issues/494) | [IEEE 1800] §§18.4/18.5.11 — Capture queue-size leaves passed to constraint functions |
| [#495](https://github.com/dsellerbrock/iverilog-uvm/issues/495) | [IEEE 1800] §11.5.1 — Clip partially out-of-range dynamic selects on packed class properties |
| [#496](https://github.com/dsellerbrock/iverilog-uvm/issues/496) | [IEEE 1800] §§16.5.1/16.9.3 — Sample procedural `$past` operands in the Preponed region |
| [#497](https://github.com/dsellerbrock/iverilog-uvm/issues/497) | [IEEE 1800] §§8.23/26.3 — Allow package-qualified static class calls in expressions |
| [#498](https://github.com/dsellerbrock/iverilog-uvm/issues/498) | [IEEE 1800] §11.4.2 — Preserve selected width and carrier bits for packed-select increments |
| [#499](https://github.com/dsellerbrock/iverilog-uvm/issues/499) | [IEEE 1800] §§7.4/11.5.1 — Index packed bits after an unpacked struct-member element |
| [#500](https://github.com/dsellerbrock/iverilog-uvm/issues/500) | [IEEE 1800] §23.7.1 — Diagnose unresolved unindexed hierarchical task calls |
| [#501](https://github.com/dsellerbrock/iverilog-uvm/issues/501) | [IEEE 1800] §37.3.3 — Report source file and line for VPI source objects |
| [#502](https://github.com/dsellerbrock/iverilog-uvm/issues/502) | [IEEE 1800] §§7.4.6/11.4.2 — Update fixed-array elements for increment expressions |
| [#505](https://github.com/dsellerbrock/iverilog-uvm/issues/505) | [IEEE 1800] §§35.5.6/H.7.8 — Support imported shortreal array arguments |
| [#506](https://github.com/dsellerbrock/iverilog-uvm/issues/506) | [IEEE 1800] §§35.7–35.8/H.7.8 — Support fixed-size unpacked export formals |
| [#507](https://github.com/dsellerbrock/iverilog-uvm/issues/507) | [IEEE 1800] §19.3 — Reject output/inout covergroup formals |
| [#508](https://github.com/dsellerbrock/iverilog-uvm/issues/508) | [IEEE 1800] §19.6.1.2 — Implement cross-bin matches thresholds |
| [#509](https://github.com/dsellerbrock/iverilog-uvm/issues/509) | [IEEE 1800] §19.6.1.2 — Evaluate cross with predicates over wildcard-bin values |
| [#510](https://github.com/dsellerbrock/iverilog-uvm/issues/510) | [IEEE 1800-2023] §19.5.1 — Implement real-valued coverpoint bins |
| [#511](https://github.com/dsellerbrock/iverilog-uvm/issues/511) | [IEEE 1800] §§19.6.1.3–19.6.1.4 — Support CrossQueueType cross-bin set expressions |
| [#512](https://github.com/dsellerbrock/iverilog-uvm/issues/512) | [IEEE 1800] §§19.6/19.11.2 — Validate large automatic cross limits |
| [#513](https://github.com/dsellerbrock/iverilog-uvm/issues/513) | [IEEE 1800] §19.11.3 — Validate merged transition-family cardinality (validation only) |

</details>

## Evidence and selection rules

- File an issue only for a distinct IEEE requirement with a verified clause and a reproducer or concrete paired evidence. If the suspected gap is not established, label the issue as validation-only and state that no failure has been reproduced. Search all open and closed issues first; link or add evidence to an existing issue when it covers the same gap.
- A discovery in the ledger is not a selected blocker. Pick one next blocker from the evidence and dependencies; do not implement work merely because it appears here.
- Keep application-source defects, setup/runner failures, CI-only failures, unverified diagnostics, and vendor extensions outside the IEEE issue set. A generic language gap found while examining an application can be included only when the issue states a source-independent requirement and evidence.
- Report CI only for the exact current PR head. Keep local focus results, issue evidence, and CI status distinct. The active PR’s checks above were read from GitHub on 2026-10-08 and were still queued/in progress.
- Preserve historical evidence in place. Add a ticket link and status to the matching debt/blocker entry instead of duplicating long narratives in this index.

### Clean-main recheck — 2026-10-08

The compiler used for this recheck was built from clean `origin/main` at `af89cfc50be1084cc86c48865f3f6ba78d4512fa` and installed at `iverilog-uvm-ieee-packed-oob-20261008/local-install/bin/`. V04–V07 registered reducers pass in both strict editions (8/8 compile-and-run executions); the positive recursive cross-`with` reducer also passes in both editions. New self-authored reducers confirm the remaining distinct clause-19 gaps in [#507](https://github.com/dsellerbrock/iverilog-uvm/issues/507) (both prohibited output and inout formals were accepted), [#508](https://github.com/dsellerbrock/iverilog-uvm/issues/508) (the ordinary cross-`with` control passes; adding `matches 2` fails), [#509](https://github.com/dsellerbrock/iverilog-uvm/issues/509) (ordinary-bin control passes; wildcard-bin `with` selection fails), and [#510](https://github.com/dsellerbrock/iverilog-uvm/issues/510) (real bins/`type_option.real_interval` are ignored in both modes, with incorrect 50% coverage). The [#469](https://github.com/dsellerbrock/iverilog-uvm/issues/469) packed two-state out-of-range reproducer prints X in both editions. DD-105's five saved cases compile without the old `kind 26` diagnostic; no runtime replay was performed. A signed cover-bin range reducer now reports 33.333% after three of nine values and 100% after all nine, in both editions. The [#511](https://github.com/dsellerbrock/iverilog-uvm/issues/511) CrossQueueType reproducer is rejected in both editions. The validation-only [#512](https://github.com/dsellerbrock/iverilog-uvm/issues/512) 83,521-bin cross question is based on a reproduced drop after a `sorry` diagnostic while compile exits 0 in both editions. A focused trailing-empty-bin probe on the same baseline reports 33.33% coverpoint and 16.67% cross coverage after one of three nonempty source bins and one of two other bins are hit; no denominator defect was found. These are local results, **not CI results**.

## Final-sweep exclusions and dispositions

- **Closed as already fixed:** DD-029 / [#503](https://github.com/dsellerbrock/iverilog-uvm/issues/503). Current `main` string loads reject `thr->flags[4] != BIT4_0` before using the address; this includes overflow from `vec4_to_index`. The normalized L62 candidate and paired wide-index matrix pass. The closeout issue comment was corrected with this exact evidence.
- **Closed as no longer reproducible:** DD-005 / [#470](https://github.com/dsellerbrock/iverilog-uvm/issues/470). On clean origin/main af89cfc50be1084cc86c48865f3f6ba78d4512fa, tests/sva_recursive_consequent_test.sv passes under -g2017 and -g2023; registered SVA legacy focus passes 17/17, JSON focus 8/8, and endpoint fan-out VPI passes 1/1. Closeout evidence: https://github.com/dsellerbrock/iverilog-uvm/issues/470#issuecomment-6066898539.
- **Reproducer not discriminating or not reduced:** DD-001 (source hypothesis only); DD-012 (historical queue-of-fixed-array boundary lacks a current-main reproducer and precise clause disposition); DD-013 (class-property/root-member last-index forms were not independently reproduced after the direct queue fix); DD-014 (no source reproducer); DD-037 and DD-038 (crashes follow cascaded unrelated diagnostics); DD-044 (original constraints were redundant; a discriminating unsatisfiable reducer and root-cause repair remain absent); DD-050 (nested queue-size reducer pending); DD-053 (no legal source case for the fallback); DD-061 (possible out-of-range default issue, not confirmed); DD-098 (application compile notices have no minimized causal reducer).
- **Baseline/requirement not established:** DD-009 (selector interpretation withdrawn; invalid-header validation not isolated); DD-023 (L47 correction exists; residual metadata/callback edges have no current failing reducer); DD-024 (synthesis-only crash has no prior-baseline comparison or verified IEEE synthesis obligation); DD-052 (the crash probe is candidate-only and current-main comparison is pending; explicit `triggered()` forms are already tracked by #439); DD-076 (null-method diagnostic behavior is not established as a normative requirement); DD-082 and DD-093 (diagnostic-quality issues, not demonstrated semantic conformance gaps).
- **Not reproducible on current main:** DD-105’s five saved assignment-pattern cases all compile with exit 0 on the current-main install; the old PR #411 `kind 26` code-generation diagnostic did not reproduce. No runtime/output replay was done, so this excludes only the reported compile-time gap.
- **Covered by an existing ticket:** DD-047 is a nested dynamic-array/container randomization subcase of #419; DD-052 is an explicit-call subcase of #439, but its candidate crash remains baseline-pending; the new standalone reducer and paired clause evidence were added as a #419 comment. DD-068 → #419; DD-051 → #440; DD-052 → #439; DD-057 → #429; DD-078 → #414; DD-087 and PR #464's DD-112 two-state packed bit-select behavior → #469; DD-109 → #421. DD-042's explicit cross-bin `matches` threshold and wildcard-bin `with` value-source gaps are separately tracked by #508 and #509. Other mapped debt entries link to their new issues above.
- **Fixed on current main or otherwise resolved:** DD-010 is fixed by the V07 never-instantiated population guard and passes paired clean-main rechecks. DD-025 constant-function assignment and increment/decrement effects and DD-028 scalar/fixed-array property increment/decrement are implemented in [commit 5c0f5588](https://github.com/dsellerbrock/iverilog-uvm/commit/5c0f5588ee) with permanent regressions; DD-064 string truth conversion is implemented in [commit 11d4b588](https://github.com/dsellerbrock/iverilog-uvm/commit/11d4b588c) with paired 2017/2023 regressions. The signed static range crossing zero now passes the paired current-main reducer documented in the debt ledger. The 2023-only `array map()` gap is fixed by [merged PR #407](https://github.com/dsellerbrock/iverilog-uvm/pull/407), and `class :final` is implemented in [commit 32cfc8dc](https://github.com/dsellerbrock/iverilog-uvm/commit/32cfc8dcc). Historical evidence remains in place. DD-018/019, DD-031/032, DD-039–043, DD-046, DD-049 (class-event property reads, fixed by PR #340), DD-056, DD-089, DD-095, DD-097, and DD-101 also have a documented fix or scoped resolution; DD-045 is an upstream Caliptra name typo; DD-054 is a pinned-source macro-whitespace compatibility case with normative status unresolved; DD-055 is an application-only nested VIF handoff; DD-069/070 and DD-097/101 are source/setup/runtime-harness work; DD-090 concerns SDF interconnect behavior with its IEEE 1497 boundary; DD-091 is the nonstandard `-gcommercial-unsafe` policy; DD-099 has unclear wider `$bitstoreal` requirements; DD-100 lacks a standalone `ref` reproducer; DD-107/108 are CI failures without a demonstrated language defect; DD-110 is a runtime-budget observation without a measured semantic mismatch; DD-111 is an impure helper called by application constraint source.

- **Clause-19 residual crosswalk.** Confirmed CrossQueueType cross-bin set-expression rejection is [#511](https://github.com/dsellerbrock/iverilog-uvm/issues/511). The 65,536-bin automatic-cross cutoff drops an 83,521-bin legal source cross with exit status 0; [#512](https://github.com/dsellerbrock/iverilog-uvm/issues/512) tracks the standards/resource-limit decision and the error policy for refused crosses. [#513](https://github.com/dsellerbrock/iverilog-uvm/issues/513) is explicitly validation-only for merged transition-family cardinality; no incorrect result has been reproduced. Transition-name union behavior, source-denominator carving, and trailing empty-bin exclusion were checked against `sv_covergroup_merged_cross_transition`, `sv_covergroup_ctor_bin_ranges_type_coverage`, `sv_covergroup_fixed_bin_post_carve`, and the focused clean-main trailing-bin probe; no current gap was found. IEEE 1800 does not define Icarus VPI coverage introspection or a textual report layout, so those extension details are excluded; standard bin identities remain covered by the clause tests. Caliptra hierarchical member cross items are application compatibility syntax, not standard §19.6. The 2023 real-bin gap is [#510](https://github.com/dsellerbrock/iverilog-uvm/issues/510); tolerance range operators remain [#462](https://github.com/dsellerbrock/iverilog-uvm/issues/462).

These exclusions retain their underlying notes in the debt ledger; they are not counted as active IEEE gaps. The clause matrix and 2023 survey continue to describe broad partial support; an unbounded “PARTIAL” label alone is not an actionable ticket without a distinct boundary and evidence.
