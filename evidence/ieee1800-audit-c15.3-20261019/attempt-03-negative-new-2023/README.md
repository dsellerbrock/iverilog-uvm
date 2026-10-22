# IEEE 1800-2023 §15.3.1 negative semaphore initialization probe

- Standard: IEEE 1800-2023 §15.3.1, p. 373: negative initial values are permitted, but available keys must become positive before `get()` or `try_get()` can procure them.
- Input snapshot: [`input-p15_03_semaphore_neg_new_2023.sv`](input-p15_03_semaphore_neg_new_2023.sv); tracked probe: `tests/1800_audit/c15/p15_03_semaphore_neg_new_2023.sv`.
- Host: Mac; run with `~/codex-supervisor/localrun 120`.
- Command: `iverilog -g2023 -o /tmp/a3-p15-03-neg-new-2023.vvp tests/1800_audit/c15/p15_03_semaphore_neg_new_2023.sv && vvp /tmp/a3-p15-03-neg-new-2023.vvp`.
- Result: compile and simulation exited 0. `new(-1)` immediately allowed `try_get(1)`; it also allowed acquisition after only one `put(1)`. Both contradict §15.3.1's positive-available-key requirement.
- Toolchain: Icarus 13.0 from commit `96a18cb6a77ea97317e975779b0daac64f551d98`; compiler SHA-256 `4f3fbe94d8cb08d55e37e831a67f85289806acdfebf6bf2f393ac572c9b36d8d`; VVP SHA-256 `9cec8fe710d7aa9d1c056658d3a8c2bb0f54a239a96edfaad48ffe871282d208`.
- Runtime: 0.14 s; peak RSS 6,635,520 bytes.
- Raw output: [`results.txt`](results.txt).
