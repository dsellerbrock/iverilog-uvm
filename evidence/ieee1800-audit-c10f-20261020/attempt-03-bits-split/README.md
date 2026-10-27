# §20.6.2 `$bits` isolated expressions

Attempt 02 showed the combined compile was masked by two invalid type arguments: `$bits(P)` (already covered by #788) and `$bits(real)` (`real` is not a bit-stream type under §6.24.3). This attempt runs each expression from B1–B5 in its own source file under both editions, with `-B` pinning Icarus helpers to the protected audit toolchain. The detailed commands, tool/helper hashes, and raw results are in `run.sbatch`, `slurm-*.out`, and `results-*/`.

Expected output for each edition: B1 `64`; B2 `64 64`; B3 `64`; B4 `64`; B5 `64`. Existing open issue #788 is the likely destination for any unpacked-structure result already in its scope. Dedupe searches are preserved in `../attempt-02-bits/dedupe-*.json`.

## Results (Slurm job 3538)

All five probes compiled and ran successfully under both `-g2017` and `-g2023`:

| Probe | `-g2017` | `-g2023` | Expected |
| --- | --- | --- | --- |
| B1 `$bits(p)` unpacked struct variable | `3` | `3` | `64` |
| B2 packed struct variable/type control | `64 64` | `64 64` | `64 64` |
| B3 fixed unpacked `int[2]` control | `64` | `64` | `64` |
| B4 typed assignment pattern `P'{1,2}` | `-1` | `-1` | `64` |
| B5 cast of unpacked struct variable `P'(p)` | `-1` | `-1` | `64` |

The outputs reproduce the existing #788 unpacked-structure `$bits` gap and show the same wrong result for the typed-pattern and cast expressions. Both controls pass. No new issue was filed. The lead-authorized reproduction comment was posted on #788.

The remote run directory was removed after copying results; `du -sb` recorded 23,508 bytes freed.
