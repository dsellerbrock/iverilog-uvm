# §20.12 assertion-control isolates — 2026-10-20

The lead requested three probes after job 3545 showed that the original list-form `$assertcontrol` test could not separate task absence from assertion-name resolution. These isolates test a bare `$assertcontrol`, then the existing control tasks against one concurrent assertion and one simple-immediate assertion. Exact standard requirements are in [STANDARD.md](STANDARD.md).

## Run

- Slurm job 3546 on DAN-DESKTOP; 1 CPU, 1 GiB, 10-minute limit; submitted 2026-10-20 13:01:54 UTC, started 13:01:54 UTC, ended 13:01:55 UTC; `COMPLETED`, exit 0, runtime 1 second.
- Compiler and VVP were pinned to protected toolchain cc25756d1 with `-B /home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb/lib/ivl`. Each source was compiled and run under both `-g2017` and `-g2023`; each process had a 30-second timeout.
- Compiler SHA-256: `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593`. VVP SHA-256: `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb`.
- Probe source hashes: ac0 `8a90674752df234e3a53caea58e9bc5faf2776ee9afd49350dcb9bf14bcb0cb6`; ac1 `391f194cd40d17d6b316c29474dc3c19672a68a9c44ed8b1fbd1392faa4243db`; ac2 `65f72a9405c4818bc87f1f16dbc43cf8ee07c3641c6246a28d7d7d4ba99114cd`.
- Raw source, compile output, runtime output and errors, run script, and Slurm log are preserved in [remote-3546](remote-3546/); generated `.vvp` build products were removed after recording results. The complete remote directory was 77,422 bytes before cleanup. Slurm accounting is disabled; peak RSS is unavailable.

## Results

The results were identical under both editions:

- `p20_12_ac0`: compile exit 0; VVP exit 1 with `System task/function $assertcontrol() is not defined by any module.` The bare `$assertcontrol(4)` form therefore fails independently of any scope-list argument.
- `p20_12_ac1`: stdout was:
  ```text
  C1 0 2
  C2 2 4
  C5 60000 2 6 1
  ```
  `$assertoff(0,a1,a2)` suppresses the concurrent assertion's action (`cf` stays 0), but the simple-immediate assertion's failure action runs twice while off (`imf` becomes 2). After `$asserton`, both actions run; after `$assertkill`, the concurrent count stays at 2 but the immediate count advances to 6.
- `p20_12_ac2`: stdout was:
  ```text
  C1 0 2
  C2 2 4
  C5 60000 2 6 0
  ```
  The no-argument `$assertoff` disables the true concurrent assertion `a3`; the later targeted `$asserton(0,a1,a2)` does not re-enable `a3`, so the final zero for `ap > 0` is expected scope behavior.

The lead classified two distinct gaps and filed [#863](https://github.com/dsellerbrock/iverilog-uvm/issues/863) and [#864](https://github.com/dsellerbrock/iverilog-uvm/issues/864). Open and closed dedupe searches are preserved in [attempt-01-actl](../attempt-01-actl/); the only related prior result was closed #444, which concerns deferred-immediate pending-report cancellation. The lead confirmed the dedupe was sufficient.
