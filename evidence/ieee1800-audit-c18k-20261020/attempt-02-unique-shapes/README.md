# IEEE 1800 uniqueness shape and real-scalar follow-up

- Standards: IEEE 1800-2017 §18.5.5 (p. 513); IEEE 1800-2023 §18.5.4 (p. 534). The real-array rejection from job 3442 was commented on existing issue #463 because it fails before `unique` is evaluated: https://github.com/dsellerbrock/iverilog-uvm/issues/463#issuecomment-6294443723.
- This lead-directed rerun isolates six integral uniqueness member shapes and the 2023 real-scalar uniqueness case with a pigeonhole control. 2017 rejection of `rand real` is expected from §18.4.
- Inputs and process-group timeout harness are hashed in `SHA256SUMS-input.txt`. Each compile/run has a 30-second timeout. Dedupe searches, including open and closed issues and `constraint state read not supported`, are copied from the preceding attempt.
- Slurm job 3457 ran on DAN-DESKTOP with 1 CPU / 1 GiB from 15:26:19Z to 15:26:20Z. Each compiler/runtime process had a 30-second process-group timeout. Version, hashes, result table, and full logs are in `remote-results/`; peak RSS is unavailable because Slurm accounting is disabled.

Expected: S1–S6 each print `ok=50 bad=0`; 2023 scalar real prints `R1 ok=100 bad=0 R1P rc=0`; the 2017 real probe is rejected.
