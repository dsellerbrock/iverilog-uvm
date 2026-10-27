# IEEE 1800 §9.6.1 wait-fork depth results

Slurm job 3740 ran on DAN-DESKTOP with Icarus 13.0 devel `cc25756d1`. Each of
the seven separate sources was compiled and run under `-g2017` and `-g2023`,
with 30-second per-process limits. All 14 compiles returned 0. Cases W1–W6
returned run code 0; W7 hit the 30-second timeout (124) in both editions.
Exact output is in `logs/slurm-3740.out`; per-case exit codes are in
`results/status.tsv`.

| Case | Expected | Observed in both editions | Result |
|---|---:|---:|---|
| W1 child waits 10, then starts #50 grandchild | 10 | 60 | Fails: parent `wait fork` waits for the grandchild |
| W2 called task starts #20 child | 20 | 20 | Pass |
| W3 no children | 0 | 0 | Pass |
| W4 child finished before wait at #10 | 10 | 10 | Pass |
| W5 C1's #30 child; sibling C2 runs to #100 | 30 | 30 | Pass; C1 does not wait for sibling C2 |
| W6 `join_any` at #5, another immediate child remains to #40 | 40 | 40 | Pass |
| W7 child starts forever #7 monitor and exits after #3 | 3 | No return/output before timeout 124 | Fails; forever grandchild prevents the parent from returning and reaching `$finish` |

IEEE 1800-2017 §9.6.1 p. 225 states: “The wait fork statement blocks process
execution flow until all immediate child subprocesses (processes created by
the current process, excluding their descendants) have completed their
execution.” IEEE 1800-2023 §9.6.1 p. 241 gives the same sentence, ending
“have terminated” instead;
2017 also has a redundant sentence restating the immediate-child rule that
2023 omits. The standard example treats children created inside its invoked
`do_test` task as immediate children, while excluding descendants created by
child5; W2 confirms the task-call behavior.

W1 and W7 reproduce #643's tracked defect in both editions. W7 demonstrates
the UVM impact: a detached child can start a forever monitor and finish, yet
the parent is held indefinitely by that grandchild. W2–W6 controls pass. No
new issue is needed.

The protected toolchain and binary hashes are in `toolchain.txt`. Its
`vvp/vthread.cc` is unchanged from the current `origin/main` source, so the
wait-fork implementation under test matches main. Job 3740 requested 1 CPU
and 1 GiB and ran for 60 seconds. Slurm accounting was unavailable after
completion, so peak RSS is not available; see `scheduler.txt`.
