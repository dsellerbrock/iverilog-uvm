# Raw results

| Edition | Probe | Compile exit | Runtime |
|---|---|---:|---|
| 2017 | `ev_formal_only.sv` | 2 | not run |
| 2017 | `ev_task_formal.sv` (standard example) | 2 | not run |
| 2017 | `ev_call_fork_only.sv` ordinary task control | 0 | not run |
| 2023 | `ev_formal_only.sv` | 2 | not run |
| 2023 | `ev_task_formal.sv` (standard example) | 2 | not run |
| 2023 | `ev_call_fork_only.sv` ordinary task control | 0 | not run |

Both failing probes report a syntax error at line 1, the formal declaration. Both control compile logs are empty. Full per-test logs, compiler hashes, staged input hashes, and result checksums are retained in `remote-3579/`.
