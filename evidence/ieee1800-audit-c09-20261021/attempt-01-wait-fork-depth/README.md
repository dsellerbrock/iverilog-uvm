# IEEE 1800 §9.6.1 wait-fork depth probes

## Standard basis

IEEE 1800-2017 §9.6.1 p. 225 says: “The wait fork statement blocks process
execution flow until all immediate child subprocesses (processes created by
the current process, excluding their descendants) have completed their
execution.” IEEE 1800-2023 §9.6.1 p. 241 has the same sentence, changing the
ending to “have terminated.” The 2017 text repeats that the calling process waits for
its immediate child subprocesses; 2023 omits that redundant sentence. In the
worked example, children spawned from the invoked `do_test` task count among
the calling process's immediate children, while child5's own descendants do
not. W2 tests that task-call rule directly.

Each case is a separate source and is compiled and run under `-g2017` and
`-g2023`. All compiler and simulator processes have a 30-second timeout.

| Case | Shape | Expected `wait fork` return time |
|---|---|---:|
| W1 | Child block waits 10, starts a #50 grandchild, then exits | 10; observed 60 |
| W2 | Called task starts a #20 child; caller executes `wait fork` | 20; observed 20 |
| W3 | No children before `wait fork` | 0; observed 0 |
| W4 | A #5 child finishes before caller waits at #10 | 10; observed 10 |
| W5 | C1 waits for its #30 child while sibling C2 waits #100 | 30 for C1, not 100; observed 30 |
| W6 | `join_any` returns after #5 while a second immediate child remains until #40 | 40; observed 40 |
| W7 | An immediate child starts a forever #7 monitor and ends after #3 | 3; observed timeout after 30 seconds with no return |

## Dedupe

Open/closed searches for #643, `wait fork`, `9.6.1`, and `grandchild` are
recorded in `DEDUPE.md`. #643 already covers the immediate-child/descendant
behavior; these are depth probes, not new issue candidates.

## Run

Job 3740 completed on DAN-DESKTOP. Paired outcomes, raw logs, toolchain and
scheduler metrics are in `RESULT.md`.
