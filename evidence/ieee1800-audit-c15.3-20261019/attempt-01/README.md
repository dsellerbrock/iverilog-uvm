# IEEE 1800 §15.3 semaphore probe, attempt 01

- Standards: IEEE 1800-2017 §15.3 (pp. 354–355) and IEEE 1800-2023 §15.3 (pp. 372–374).
- Positive probe: [`p15_03_semaphore.sv`](../../../tests/1800_audit/c15/p15_03_semaphore.sv); exact snapshot is in `input/`.
- Positive result: both `-g2017` and `-g2023` pass default and multi-key `new`, default and counted `put`, `try_get`, blocking `get` wakeup, and FIFO waiter order.
- Negative probe: [`n15_03_semaphore_neg_keys.sv`](../../../tests/1800_audit/c15/neg/n15_03_semaphore_neg_keys.sv); exact snapshot is in `input/`.
- Negative result: `-g2023` prints `try_get(-1) returned 0` with no runtime diagnostic and exits 0. This probe does not distinguish the completion of the subsequent `put(-1)` and `get(-1)` calls; their behavior remains unclassified pending follow-up.
- Host: Mac; positive run through `~/codex-supervisor/localrun 120`; negative run through `~/codex-supervisor/localrun 15`.
- Toolchain: Icarus 13.0 from commit `96a18cb6a77ea97317e975779b0daac64f551d98`; compiler SHA-256 `4f3fbe94d8cb08d55e37e831a67f85289806acdfebf6bf2f393ac572c9b36d8d`; VVP SHA-256 `9cec8fe710d7aa9d1c056658d3a8c2bb0f54a239a96edfaad48ffe871282d208`.
- Positive runtime: 0.20 s; peak RSS 8,028,160 bytes.
- Raw logs: `positive-results.txt`, `negative-2023-results.txt`.
- Follow-up: isolated 2023 negative-key behavior, including key-count corruption and blocking `get(-1)`, is in [attempt 02](../attempt-02/README.md).
