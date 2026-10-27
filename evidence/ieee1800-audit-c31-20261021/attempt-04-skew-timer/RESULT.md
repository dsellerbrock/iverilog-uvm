# Clause 31 skew timer results

## Attempt 1: combined event-flag source

Slurm job 3690 on DAN-DESKTOP compiled the combined `p31_skewtimer.sv` with `-gspecify` under both `-g2017` and `-g2023`. Both compiler invocations exited 1 with the diagnostic:

```text
sorry: $timeskew event_based/remain_active flag arguments are not supported; the check is dropped.
```

This prevents runtime classification of K3 and prevented the other cases in the combined source from running. The exact source, command output, scheduler record, and initial script are preserved in [`raw-slurm-3690`](raw-slurm-3690/). The probe was then adjusted so default-mode cases can run separately and the event-flag form remains an isolated compile check.

## Attempt 2: isolated default-mode checks

Slurm job 3691 on DAN-DESKTOP completed with `COMPLETED`, exit `0:0`, 1 CPU and 1 GiB requested. `sacct` is disabled, so peak RSS is unavailable. Both editions compiled and ran the default-mode source with exit 0 using the pinned toolchain (source commit `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`; compiler SHA-256 `9760f8c1ab8ad03d64761b257db74ff07603a15c4d44d2bcdba75073f006911c`; `vvp` SHA-256 `7fa3224c44e69b555fa86c1e3e048fa2709780276c6417ff8b7a7f0d63241c02`).

Both editions produced:

```text
p31_skewtimer.sv:13: Timing violation: $timeskew check in p31_skewtimer at time 30
K2 30
COUNTS K1=0 K2=1 K3=0 K4=0 C0=0
```

K1 (`$timeskew`, no data event) and K4 (`$fullskew`, no data event) produced no timer report; K2 reported only when its data event arrived at t30, instead of near t12–t13. The `$skew` no-data control C0 stayed silent, as expected. These results show the default timer-based behavior is missing for both `$timeskew` and `$fullskew`.

The isolated K3 compile with `event_based_flag=1` exited 1 in both editions with the same “event_based/remain_active flag arguments are not supported; the check is dropped” diagnostic as attempt 1. K3 could not run. This is a separate optional-flag support gap for the lead to classify.

The refreshed open+closed searches are in [`DEDUPE.md`](DEDUPE.md). They find no timer-mode issue; #890 appears only for `$timeskew`/`$fullskew` search terms because it mentions those checks as positive controls. Scheduler stdout, compile/run logs, source, and hashes are in [`raw-slurm-3691`](raw-slurm-3691/). The lead filed #891 for missing default timer-based `$timeskew`/`$fullskew` reporting and #892 for rejected flag arguments. Along with #890 for negative timing checks, Clause 31 contributed 3 new issues, bringing the cumulative audit count at that checkpoint to 157.
