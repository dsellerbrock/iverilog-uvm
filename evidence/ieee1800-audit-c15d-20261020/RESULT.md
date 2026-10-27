# Result: isolated IEEE 1800 event constructs

Slurm job 3385 completed on DAN-DESKTOP with `ExitCode=0:0` (accounting storage disabled; state verified with `scontrol`). It used Icarus 13.0-devel built from exact current main `cc25756d187314742d347267c2a513b3e640a7fb`. All eight minimal probes were compiled and, when compilation succeeded, run under both `-g2017` and `-g2023`. Each compiler and simulator process had a 20-second process-group timeout.

**Only the standard-form event task formal failed.** `ev_task_formal.sv` failed compilation with rc 2 and `syntax error` at line 1 in both editions. The other seven constructs compiled and ran in both editions with exactly the expected outputs:

- event trigger delay: `E1 1`
- event typed task formal: compile failure, no run
- `event.triggered` while active: `E3 10`
- `event.triggered` after expiration: `E4 0`
- forked `triggered` wait: `E5`
- nonblocking event trigger: `E6 0`, `E6B 5`
- successful `wait_order`: `E7 1`
- failing `wait_order` with explicit else: `E8 1`

The earlier combined events probe's parse failure is isolated to the standard event typed task formal `task trigger(event ev); -> ev; endtask`, which is shown in the IEEE example cited by the lead at 2017 §15.5.3 p.361. The lead searched all issue states for event-typed task formals and found no existing issue. It confirmed closed #439 covers event `.triggered()` and closed #441 covers `wait_order`; open #653 concerns a named sequence's `.triggered` and is distinct.

The issue filing and matrix row are pending the lead's final response. Raw per-edition logs, generated `.vvp` files, input checksums, and job output are preserved under this directory.
