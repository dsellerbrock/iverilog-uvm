# Attempt v3: single-dimension fast path

Pinned measurement base: `c7ebca768c21c251d9c165c9aff0e363768030b1`.

Job 1294 compares the pinned reference, descriptor predecode (v1), predecode
plus packed result construction (v2), and v3. V3 adds a fast path only for
valid single-dimension descriptors with low bound 0 and stride 1. It consumes
the one index, validates it through the existing signed/X/Z conversion and
bounds check, and leaves all other descriptors on the generic loop. Invalid
metadata therefore retains the existing stack-pop path.

Each build runs the 32 valid and malformed focused checks. The 100,000-access
hotloop is profiled with Callgrind; output must match byte-for-byte across all
four builds. The keep threshold is at least a 10% instruction reduction versus
the pinned reference, with no output differences.

Job: `a5-wp2-predecode-v3-r4` (2 CPUs, 8 GiB).
Remote run root: `/home/dsell/slurm-runs/iverilog-uvm/a5-perf/wp2-predecode-v3-c7eb-20261015-r4`.

Results: exit 0. All four focused and hotloop outputs matched byte-for-byte.
Callgrind instructions:

| Variant | Instructions | Change vs reference | Change vs previous |
| --- | ---: | ---: | ---: |
| Reference | 1,128,370,773 | 0.000000% | - |
| Predecode (v1) | 1,052,269,912 | -6.744313% | - |
| Predecode plus packed result construction (v2) | 1,024,423,467 | -9.212159% | -2.646322% |
| Single-dimension fast path (v3) | 1,027,723,440 | -8.919704% | +0.322130% |

V2 was the best variant but missed the 10% keep threshold. V3 made it slower
than V2. Reject predecode for this hotloop and keep the patch as experiment
evidence only. Full profiles, build logs, and hashes are in this directory.
