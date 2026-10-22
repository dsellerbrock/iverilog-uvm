# IEEE 1800 §21.7.1 VCD probe

- Source: [p21_07a_vcd.sv](../../../tests/1800_audit/c21/p21_07a_vcd.sv), copied unchanged from the audit lead.
- Host: MacBook Air; each edition is wrapped in `~/codex-supervisor/localrun 180`.
- Compiler/runtime: batch commit `b9441bafbdb0b6b7413c09e0381845e69481391b`; compiler SHA-256 `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`; vvp SHA-256 `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.
- Raw VCD files, compile logs, run logs, and exact commands are saved here. Review VCD behavior against §21.7.1 before classification.

Results: both editions compile and run with exit 0; `$finish` occurs at 50000 (1ps). The generated VCD files are byte-identical (SHA-256 `fd5100fcd7ac503308e8afde02476c622e51d793b9999a672f061570e5988474`).

- 2017: 0.13 s, peak RSS 6,733,824 bytes.
- 2023: 0.05 s, peak RSS 6,701,056 bytes.
- `$timescale 1ps` matches the declared simulation precision and §21.7.2.1's `time_number time_unit` grammar.
- The simulator writes `real 1` in the variable declaration and `rNaN` during `$dumpoff`; these encodings are recorded for lead review.
- At time 20000, `u1.s` changes on the same simulation timestamp as `$dumpoff`. The VCD places `b0 (` after the `$dumpoff ... $end` block. This same-time ordering is left for lead review; it is not classified as a gap here.
