# IEEE 1800 §§21.4–21.6 probes

- `p21_04a_readmem.sv` was copied unchanged from the audit lead. The original plusargs source is preserved as [p21_06a_plusargs-original.sv](p21_06a_plusargs-original.sv); the current [p21_06a_plusargs.sv](../../../tests/1800_audit/c21/p21_06a_plusargs.sv) applies the lead-directed [16:1] correction to the test assertion.
- Host: MacBook Air; each compile/simulation was wrapped with `~/codex-supervisor/localrun 180`.
- Pinned batch compiler/runtime: commit `b9441bafbdb0b6b7413c09e0381845e69481391b`; compiler SHA-256 `7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0`; vvp SHA-256 `e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d`.
- Commands and raw logs are in `command.txt` and the attempt subdirectories. No tests were added to the project smoke/T1 suites.

## §§21.4–21.5

- The unchanged combined probe compiles in both editions, then exits 1 with run-time errors on the associative-array `$readmemh` and `$writememh` calls. One-statement reducers independently reproduce each error in both editions: [read reducer](../../../tests/1800_audit/c21/r21d_assoc_readmem.sv), [write reducer](../../../tests/1800_audit/c21/r21d_assoc_writemem.sv), [logs](attempt-02-reducers/). The lead filed #803 after all-state dedupe.
- The lead-directed no-associative-array variant reports `RESULT pass=10 fail=1` in both editions, not 11/11. It produces expected warnings for short/long file ranges, an error for address 0x9 outside [1:4] (the memory stays unchanged), and `FAIL enum_stops`.
- The isolated enum reducer shows `em0=1 em1=7`, with no warning/error and exit 0 in both editions. This is a confirmed §21.4.2 gap; the lead filed #804 after the all-state `readmem enum` dedupe search. See [source](../../../tests/1800_audit/c21/r21d_enum_invalid.sv) and [logs](attempt-04-reducers/).
- The no-associative-array run is [attempt-03-no-assoc](attempt-03-no-assoc/); the 10/11 result shows the remaining tested cases ran despite the expected out-of-range memory diagnostic.

## §21.6

- The original plusargs probe reports `RESULT pass=9 fail=1` only because `tn[15:0]` selects out-of-range bit 0 from `logic [256:1] tn`. A reducer shows `$value$plusargs` returns `t1` for all three tested argument orders in both editions.
- After changing the assertion to the valid `tn[16:1]` slice, the plusargs probe reports `RESULT pass=10 fail=0` in both editions. The informational line/warning for the dynamic format-string check is expected.
