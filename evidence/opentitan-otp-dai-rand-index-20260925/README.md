# OTP random-indexed parameter-member constraint

The released OTP `dai_wr_blank_addr_c` uses `PartInfo[part_idx].secret` to require eight-byte alignment for secret partitions. `part_idx` is random. The prior fixed-index parameter-member lowering rejected it, and the conditional constraint was silently dropped after an ignored-item warning; the emitted solver IR enforced only four-byte alignment.

`elaborate.cc` now emits a constant table of the selected packed-struct member while keeping the index symbolic. The VVP solver selects the declared member value per model and checks selected X/Z leaves and invalid four-state indexes; invalid two-state reads yield zero. Unsupported or malformed forms remain diagnostic. Paired IEEE 1800-2017/2023 legal, illegal, rollback, negative-bound, signedness, X-leaf, and missing-member reducers are baseline RED and pass 12/12 in each focused harness. The clauses are 2017 §§7.4.6, 18.3, 18.5.7, 18.5.13 and 2023 §§7.4.5, 18.3, 18.5.6, 18.5.12, with rollback under §18.6.3.

The private Icarus build compiles the exact pinned OTP program with `dai_wr_blank_addr_c` retained and no ignored constraint items. The native-DPI smoke completes at 141094616 ps with `TEST PASSED CHECKS`, zero UVM warning/error/fatal and assertion errors, and 1343 scoreboard-checked TL A plus 1343 TL D items. Its DAI attempt is address `0x66c` in nonsecret partition 4. **Qualified released OTP DV remains 0/1** because six intended covergroup bins are still dropped; they are a separate blocker. The pinned source checkout is unchanged, and the existing RAM-path overlay is applied only to a disposable generated source copy. This release replay, the paired strict reducers, and the real-DPI UVM regression have separate denominators.

Exact commands, hashes, and gate results are in `result.json`.

The final private-image gates pass: full legacy 6638 total (6633 passed, 2 not implemented, 3 expected failures, zero unexpected), full JSON 3679/3679, negative 155/155, SVA dual-engine 62/62, VPI with PLI1 140/140, real-DPI UVM 358/358, and `make check`.
