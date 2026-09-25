# OpenTitan HMAC open-ended covergroup range replay

This follow-on to [PR #374](https://github.com/dsellerbrock/iverilog-uvm/pull/374) preserves constant-endpoint `[lo:$]` and `[$:hi]` bins through parsing and resolves `$` to the signed or unsigned coverpoint type boundary. It retains crosses and transition terms without enumerating wide ranges. The strict paired controls target IEEE 1800-2017 and 2023 covergroup range rules; the pinned OpenTitan replay uses `-gcommercial-unsafe` and is **nonstandard compatibility** evidence.

| Check | Before | Final private Icarus image |
|---|---|---|
| 2017/2023 ordinary and crossed bins | Dropped ranges and cross; first coverage sample 50% rather than 16.67% | Signed/unsigned boundaries, 32-bit interval, cross, ignore/illegal carving, and empty intersection pass |
| 2017/2023 transition terms | `[lo:$]` rejected by parser | Both `[lo:$]` and `[$:hi]` transitions pass |
| 2017/2023 illegal `[$:$]` | Incorrectly accepted | Compile rejected |
| 2017/2023 mixed open/constructor bin | Intermediate candidate silently omitted open sibling | Whole bin is dropped with explicit `sorry` diagnostic |
| Pinned HMAC UVM compile | PR #374 `FAIL`, 1 hard error, 14 debt diagnostics | `DEBT`, exit 0, 0 hard errors, 13 debt diagnostics |
| Pinned HMAC runtime | PR #374 no runtime | `RUNTIME_FAIL`: checked sequence traffic reaches status read, then `UVM_ERROR` at `hmac_scoreboard.sv:481` (`0x2` DUT vs `0x10` mirror); `TEST FAILED CHECKS` |

The HMAC result is **0/1 released DV**, despite VVP exit 0 and meaningful hash/message traffic. The scoreboard mismatch is a separate blocker; a same-edge mirror-update race is plausible but not yet proved. The full [84-row unsafe matrix](latest-unsafe-matrix.md) on this combined image has the same 35 UVM and 49 runtime keys as the historical PR #374 matrix. All 84 compiles explicitly use `-gcommercial-unsafe`: UVM is 9 `DEBT` / 26 `FAIL`; runtime is 7 `DEBT` / 35 `FAIL` / 6 `RUNTIME_FAIL` / 1 `RUNTIME_TIMEOUT`. There are **0/49 zero-debt raw matrix `PASS` statuses**. HMAC advances from a hard compile failure to a runtime failure; EDN and OTBN remain compile failures. A 120-second TL-agent timeout is not a pass. The [provenance record](latest-unsafe-matrix-provenance.json) records the flags, tool and source hashes, and [archived log hashes](latest-unsafe-matrix-log-hashes.json); the matrix JSONs confirm identical row keys.

| Selected-runtime view | Passed | Qualification |
|---|---:|---|
| Raw matrix, zero setup/semantic debt | 0/49 | No row has `PASS` status. |
| Exact base-source matrix commands, completed checked smoke | 7/49 | Seven `DEBT` rows finish with intended pass markers, meaningful sequence or scoreboard activity, and zero runtime errors; their setup/compile warnings remain visible. |
| Compatibility with documented named patches | **9/49** | The seven above plus current-image OTP and CSRNG named replays. These two match selected test identities but use their documented overlay/DPI profiles, not the exact matrix commands. |

The adjusted **9/49** is a nonstandard compatibility rate for one selected smoke per target, not IEEE conformance or the full released OpenTitan test catalog. GPIO traffic is inferred from the completed smoke sequence and its pinned 20–200 transaction loop; its low-verbosity log does not count individual transactions. Forty selected runtime identities still have a compile failure, runtime failure, or timeout after crediting the two patched passes. These 40 rows do **not** represent 40 distinct compiler bugs.

The remaining rows group by their **first observed blocker**, not a proved unique root cause. Some cores have further errors behind that first diagnostic.

| First observed blocker after the two patches | Rows | Examples |
|---|---:|---|
| Source-syntax or pinned declaration diagnostics | 10 | Four SPID module-scope `static` tasks; class-scope imports; SPI TPM parameter override |
| Covergroup or cross-bin compilation | 5 | EDN, I2C, LC_CTRL, PWM, SYSRST_CTRL |
| Constraint compilation or typing | 3 | AES, RV_DM, RV_TIMER |
| Clocking or mixed-driver compilation | 3 | CLKMGR, SPI Device, SPI Host |
| Other type/parser/elaboration compilation | 9 | Entropy source, flash controller, USBDEV, alert handler, others |
| Package parse or missing module | 3 | Ibex I-cache, ROM controller, `prim_flop_2sync` |
| Runtime solver limit | 2 | ADC_CTRL, PATTGEN |
| Native DPI absent from matrix run | 2 | PRESENT, PRINCE |
| Runtime check failure, root unproved | 2 | HMAC, `trial1` |
| 120-second timeout | 1 | TL Agent, after more than 1,200 requests |

Several signatures recur across rows, including module-scope `static`, class-scope imports, SPI mixed drivers, covergroup runtime-range drops, and missing native DPI. The categories mix compiler limitations, pinned-source issues, missing runtime dependencies, and unresolved functional failures; there is no defensible count of independent bugs yet.

The pinned OpenTitan checkout is `a78922f14a8cc20c7ee569f322a04626f2ac6127` and was clean before and after. The 84-row matrix uses its unmodified generated source lists; documented OTP and CSRNG source overlays require separate named replays. The final private compiler includes merged PR #373 and #374 at main `808ad9f40711cb8277f920a0c7a4a1ab2aa2a99c` plus this open-range change. Compiler engine SHA-256: `9084fca0b6d1cbe00184583399ba1c5fcf0f10d78402f42c14fd50c3708dbdfe`; VVP SHA-256: `e54c7489ae51e3d14ba3b201cd4502b3d8ccfc7742926589cc9bddb82334bcae`. The exact application commands, selected smoke sequence, metadata, and per-row status are in [hmac-combined-result.json](hmac-combined-result.json), with copied [compile and runtime logs](hmac-combined-logs/).

The separate current-image [OTP named replay](otp-current-overlay/result.json) passes 1/1 nonstandard compatibility DV with its hash-checked disposable RAM-path overlay, native DPI, 1343 checked TL A/D pairs, and six original bin groups retaining 36 endpoints. The ten fault-injection selectors are zero in this seed, so the warned `force` branches remain unqualified. The [CSRNG named replay](csrng-current-overlay/result.json) passes 1/1 with its disposable width patch, native AES DPI, and ordered app-2 instantiate/generate/uninstantiate checks; its one ignored compile-time constraint item remains separate. Both use explicit `-gcommercial-unsafe` and preserve original checks. Together these are **2/2 named nonstandard compatibility DV**, not additions to the base-source 0/49 matrix numerator.

Paired RED logs and combined-image focused results are in this directory. Constructor-dependent open endpoints and `with (item inside {open range})` remain loudly unsupported. A bin mixing an open range with a constructor-dependent closed range is now rejected as a whole, avoiding silent partial coverage. The IEEE wording for open endpoints is in [1800-2017](https://fpga.mit.edu/6205/_static/F25/documentation/1800-2017.pdf) and [1800-2023](https://iccircle.com/static/upload/img20240319175450.pdf), §§19.5.1 and 19.6.1.

Final local gates on the combined image pass: full legacy **6,694 total** (6,689 ordinary passes, zero failures, two not implemented, three expected failures), full JSON/VVP **3,743/3,743**, VPI with PLI1 **140/140**, and REAL DPI UVM **358/358** with zero failures or skips. The focused paired legacy and JSON lists each pass 8/8; merged PR #373/#374 neighboring focus passes 2/2 and 17/17 legacy plus 21/21 JSON; negative suite passes 155/155, SVA dual engine 62/62, and `make check` passes. These are compiler/UVM regression counts, separate from the released-DV smoke rate.
