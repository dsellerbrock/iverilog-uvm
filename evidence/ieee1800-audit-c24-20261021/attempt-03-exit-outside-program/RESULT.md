# IEEE 1800 §24.7: `$exit` called outside a program

## Standard basis

IEEE 1800-2017 and IEEE 1800-2023 §24.7 say `$exit` is ignored when called from a thread that does not originate in a program initial procedure. The warning is optional. Since the separate program's initial procedure finishes at time 5, it should print `PROG done`; program completion then ends the simulation before the module's time-20 `LATE` display.

## Paired-edition reproducer

Source: [`r20_02_exit.sv`](../../../../tests/1800_audit/c20/r20_02_exit.sv) (source SHA-256 `5967ac778242fb7de8d804d59f1b5d832ecb1f1b20b46da30256eef5f0fd26d2`). It contains a program initial process scheduled to print `PROG done` at time 5 and a module initial process that prints `EX0` then calls `$exit` at time 1.

Pinned compiler source commit: `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`; Icarus 13.0-devel at `/home/dsell/toolchains/iverilog-fb584a25-20261020`. Slurm job 3612 used 1 CPU, 1 GiB, 5-minute allocation. Each compile and run had a 30-second timeout.

Commands, run once for each edition:

```sh
iverilog -g2017 -o exit-2017.vvp r20_02_exit.sv
vvp exit-2017.vvp
iverilog -g2023 -o exit-2023.vvp r20_02_exit.sv
vvp exit-2023.vvp
```

Both editions compiled and ran with exit code 0 and empty stderr. Both stdout logs contain only `EX0`; `PROG done` is suppressed, confirming that the module-origin `$exit` incorrectly terminates simulation instead of being ignored. Raw logs are in [`remote-3612/`](remote-3612/).

## Open/closed issue dedupe

Searches for `$exit`, `$exit ignored`, `$exit outside program`, and `§24.7` included both open and closed issues. The only direct match is open #786. Its description already identifies the module-called form in this same test and records the observed `EX0`-only output. This probe therefore extends evidence for #786; no duplicate issue was filed. Dedupe details and raw query results are in [`dedupe/`](dedupe/).

## Lead status

The requested `ask-techlead --agent A3 --lead 1800-audit` call was rejected at 160/160 daily lead calls, despite the supervisor note saying 80 calls remained. No direct helper/quota-file edits were made. Classification and filing decisions remain with the lead.
