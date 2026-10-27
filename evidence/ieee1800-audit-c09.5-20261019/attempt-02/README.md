# IEEE 1800 §9.5 process-thread probe

- Standards: IEEE 1800-2017 §9.5 p. 224 and IEEE 1800-2023 §9.5 p. 240; the lead confirmed identical normative text.
- Probe: [`p09_05_threads.sv`](../../../tests/1800_audit/c09/p09_05_threads.sv), with the exact run input snapshotted under `input/`.
- Host: Mac, run through `~/codex-supervisor/localrun 120`.
- Editions: `-g2017` and `-g2023`; both compile and simulate successfully, exit 0.
- Coverage: `initial`, `always`, `always_comb`, `always_latch`, `always_ff`, parallel `fork...join` branch, `process::self()` dynamic process, continuous assignment, and `final` procedure.
- Output: each run prints `PASS all process execution threads clause 9.5` and `PASS final procedure thread clause 9.5`.
- Toolchain: Icarus 13.0 from commit `96a18cb6a77ea97317e975779b0daac64f551d98`; compiler SHA-256 `4f3fbe94d8cb08d55e37e831a67f85289806acdfebf6bf2f393ac572c9b36d8d`; VVP SHA-256 `9cec8fe710d7aa9d1c056658d3a8c2bb0f54a239a96edfaad48ffe871282d208`.
- Runtime: 0.21 s; peak RSS 8,175,616 bytes.
- Raw output: `results.txt`.
