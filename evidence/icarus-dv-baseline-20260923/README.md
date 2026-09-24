# Icarus application DV baseline (2026-09-23 local)

Both censuses used this checkout's installed Icarus 13.0 (devel): `iverilog`
SHA-256 `1590b064aee694d390f8e18b1ca3469a5a47405397db9b8e385b6c5b41f1a5a2`
and `vvp` SHA-256 `5d4d0ca6bbaa695927572bdbba03915a07e20005403a5fe0d7e25e7e659c16ed`.
The OpenTitan compiler hashes matched before and after its census. The pinned
application checkouts were clean. No application source was edited.
After the guarded-distribution correction, installed VVP SHA-256
`e9b7a64a8643973c9bc6597ca604285bbd718cf733e45181f6155390d9fdc8c6`
replayed the three Caliptra unit images with the same 2-pass/1-fail verdict
and both named OpenTitan smoke images with the same 2-pass verdict and
scoreboard counts. These were runtime-only replays; the 84-row OpenTitan
matrix was not rerun under this VVP.

| Scope | Fresh Icarus result | Meaning |
| --- | --- | --- |
| Caliptra v2.1.2 selected L0 tests | 0 of 52 runtimes attempted | The shared `caliptra_top_tb` fails strict elaboration with 46 mixed continuous/procedural variable-driver errors; an L0 runtime pass rate is unmeasured. |
| Caliptra selected L0, opt-in `-gcommercial-unsafe` | 0 passes / 1 attempted, 51 unrun | The final native-vector-backed pinned first case reaches 43.865 us and 621 instruction-trace entries, then exits 1 after TLU, SOC IFC, and Veer store-buffer assertion actions, with no pass marker and 17,467 error diagnostics. The compiler reports zero Preponed sampling warnings. This is a nonstandard compatibility failure, not a strict L0 pass. An earlier copied-reset diagnostic also failed at 43.865 us and belongs to a separate profile. |
| Caliptra / Adams Bridge unit filelists | 20 compile passes, 6 failures, 17 setup gaps, 1 unsupported / 44 | Compilation does not establish a DV runtime pass. |
| Checker-bearing Caliptra / Adams Bridge unit subset | 2 passes, 1 failure / 3 attempted | `csrng_tb` and `power2round_tb` passed their explicit checks; pristine `rej_bounded_tb` reported `TESTCASE FAILED`. The other unit runtimes remain unmeasured here. |
| OpenTitan Earlgrey-PROD-M6 UVM compile lane | 0 clean passes, 8 compiled with debt, 27 failed / 35 targets | Each target had one selected smoke configuration. |
| OpenTitan UVM/directed runtime lane | 0 clean passes, 8 pass banners with debt, 36 compile failures, 4 runtime failures, 1 timeout / 49 targets | The eight banner rows exited zero; six have logged activity and two have banner-only evidence. All eight retain FuseSoC setup warnings and three also retain compiler warnings. This does not qualify full DV. |
| OpenTitan named xbar and pwrmgr smoke subset | 2 checked passes / 2 attempted | Fresh current-tool images completed with TileLink/scoreboard activity and zero UVM warnings, errors, or fatals. Xbar is unmodified (1/1); pwrmgr uses the documented disposable checker overlay (1/1) and cannot count as unmodified-source qualification. This subset is separate from the 84 matrix rows. |

The OpenTitan 84 rows are *lane rows*, not 84 independent named tests or a
fraction of its 1,914 enumerated UVM named-test entries. The Caliptra 52 L0
cases, 44 unit filelists, and three bounded unit runtimes have different
denominators and must not be combined into one pass percentage.
See [Caliptra commands and per-test evidence](../caliptra-icarus-dv-baseline-20260923/README.md)
and [OpenTitan commands and per-row evidence](../opentitan-icarus-dv-baseline-20260923/README.md).
The [named xbar/pwrmgr smoke record](../opentitan-named-smokes-20260923/README.md)
has its own two-case denominator and exact commands.
