# IEEE 1800-2023 §15.3 negative key-count probe

- Standards: §15.3.2 `put`, §15.3.3 `get`, and §15.3.4 `try_get`; IEEE 1800-2023 pp. 372–374.
- Probe: [`n15_03_semaphore_neg_keys.sv`](../../../tests/1800_audit/c15/neg/n15_03_semaphore_neg_keys.sv), exact input snapshot under `input/`.
- Host: Mac; command guarded by `~/codex-supervisor/localrun 60`.
- Result: `-g2023` compile and simulation exit 0 with no runtime diagnostic. `try_get(-1)` returns 0; `put(-1)` silently adds keys (a later `try_get(1000)` succeeds from an initially empty semaphore); `get(-1)` remains blocked through the 10-time-unit watchdog.
- Toolchain: Icarus 13.0 from commit `96a18cb6a77ea97317e975779b0daac64f551d98`; compiler SHA-256 `4f3fbe94d8cb08d55e37e831a67f85289806acdfebf6bf2f393ac572c9b36d8d`; VVP SHA-256 `9cec8fe710d7aa9d1c056658d3a8c2bb0f54a239a96edfaad48ffe871282d208`.
- Runtime: 0.17 s; peak RSS 6,881,280 bytes.
- Raw output: `results.txt`.
