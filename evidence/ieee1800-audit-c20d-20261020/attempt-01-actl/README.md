# §20.12 assertion-control initial probe — 2026-10-20

IEEE 1800-2017 §20.12 and 1800-2023 §20.11 define `$assertcontrol` and the `$asserton`, `$assertoff`, and `$assertkill` tasks; see [STANDARD.md](STANDARD.md). This first probe combined the task-list form with named concurrent and immediate assertions. The runtime result established that `$assertcontrol` is unavailable, but the list-argument warnings meant the lead requested the bare-task isolate in [attempt 02](../attempt-02-isolate/README.md) before classifying the gap.

## Run and result

- Slurm job 3545 on DAN-DESKTOP, cc25756d1; 1 CPU, 1 GiB, 10-minute limit; `COMPLETED`, exit 0, elapsed 1 second. Slurm accounting is disabled, so peak RSS is unavailable.
- The source compiled under both `-g2017` and `-g2023`, with warnings that the assertion label `a1` could not be bound in the two `$assertcontrol` calls. VVP failed under both editions with `System task/function $assertcontrol() is not defined by any module.` The initial probe did not reach behavioral checks for `$assertoff`, `$asserton`, or `$assertkill`.
- Raw source, log, compile/run output and errors are in [remote-3545](remote-3545/). The relevant dedupe searches are in this directory; only closed #444 was related, and it covers deferred-immediate pending-report cancellation rather than the task itself.
