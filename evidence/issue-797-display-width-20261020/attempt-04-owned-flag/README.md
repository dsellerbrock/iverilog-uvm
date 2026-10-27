# #827 mode-aware runtime fix: ownership repair rerun

- Base PR commit: `34bdaa9aa8a94adeb0d06ce1ee62e66937b6f686`.
- Source snapshot SHA-256: `b64b8f6fd5b11d20145fff5ac815fa6b1d11e02092196babcd2644b35efe8152`.
- Patch SHA-256: `883db8bd4c3f73b1460e924f5b322fa84cc1b1c7fafc428d72df1e1014f2b8cf`.
- Slurm job `3837` on DAN-DESKTOP; 3 CPUs, 2 GiB.
- Fixes job 3836's invalid-free by storing the compiler mode flag in the owned flags map with `strdup`, replacing any existing entry first.
- Repeats T0 build, paired 2017/2023 #797 reproducers and the smoke set, plus T1 legacy `format`/`swrite` regressions.
- Job 3836 logs and checksum-verified results are in `../attempt-03-mode/`.

## Result

- Started `2026-10-21 17:27:03 MDT`, finished `17:32:51 MDT`; job exit 0.
- T0: build/install passed; both paired 2017/2023 reproducers passed; smoke passed (56/56 and VPI 133/133).
- T1: legacy Verilog `format` and `swrite` passed (2/2), confirming their existing output is preserved.
- Build wall time 4:59.72; peak build RSS 1,645,224 KiB. Install wall time 0:00.48.
- All 22 copied result, log, and run-script files match the remote SHA-256 manifest. The full bundle is `remote-run-evidence.tar.gz` (SHA-256 `8aba5bf84f6d8466c0656914ee07a8dfdbccba842eb4b0e42090b75ca288a066`); the unpacked copy is retained under `remote-run/` for local inspection.
- After recording and verifying those results, removed only this run's remote `source/`, `source.tar.gz`, and `changes.patch`; retained its logs, results, and run script. `/home/dsell` free space rose 731,112,095,744 -> 733,028,380,672 bytes (+1,916,284,928 bytes); `/mnt/c` stayed effectively unchanged at about 71.391 GB free.
