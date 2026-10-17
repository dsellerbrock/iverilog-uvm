# WP1 trace and context-stat instruction screen

**Verdict: rejected at the instruction gate.** The candidate preserved all 18
benchmark outputs and passed the focused context-stat, region-trace, and
coverage-report smoke tests, but its target improvement was 3.31%, below the
required 10%. The largest regression elsewhere was 0.17%, within the 2% cap.
The WP1 VVP source changes are retained here for the attempt record and have
been reverted from the active source tree.

## Pinned inputs

- Campaign and measurement base: `0490e2ff48f3169283e7d71afe2a16424e2cf3aa`.
- Reference source archive SHA-256: `046ac269ed5fe0f0414c2d782cf5722ed1d638e2b775d9d0726748099f6115ea`.
- Candidate source archive SHA-256: `4b7c6bb4c36bbb3a88efd97e64d3bc0ab1b4ed09156341e95d9293a28f33193d`.
- Candidate VVP patch SHA-256: `a2f9356c44519eac90008b7b5a5ce7ce82d661c8ea9c83929ce04468387fd810`.
- New `vvp_trace_config.h` SHA-256: `4e4b93c8efa0b0da03b77dba26753f2eaf06e327e8099cd152dadcae41a140f9`.
- UVM Core submodule: `78c06547a2a0a29b3dc9dcafae62b75b2ff61544`.

## Method and result

Slurm job 1213 built both trees with `-g0 -O2`, then ran one interleaved
Callgrind Ir comparison per runtime over the 18 `sim-hotspots` workloads on
one pinned CPU. Both sides used the same compiled benchmark program. The
runner returned 0, all 18 output comparisons matched, and every benchmark
produced a Callgrind count. Reference/candidate counts and deltas are in
[`run-r3/results/instruction-counts.csv`](run-r3/results/instruction-counts.csv);
the complete JSON, compressed raw profiles, and compressed trace smoke outputs are in
[`run-r3/results/`](run-r3/results/).

| Benchmark | Reference Ir | Candidate Ir | Change |
| --- | ---: | ---: | ---: |
| `behav` target | 94,570,528,237 | 91,439,391,991 | **−3.310901%** |
| `classq` | 117,751,980,184 | 116,063,116,179 | −1.434255% |
| `uvm_traffic` | 39,503,436,387 | 38,914,306,516 | −1.491338% |
| Largest other regression (`randomize_z3`) | 12,999,915,495 | 13,021,814,129 | +0.168452% |

The focused `context-stats`, `region-trace`, and `coverage-report` regression
outputs matched byte-for-byte between reference and candidate. No final
wall-time run, Caliptra comparison, or full gate suite was run because the
candidate did not qualify at the primary instruction threshold.

## Run audit

- Run r1 stopped before building because the archive did not include generated
  `configure`; r2 then built both sides and passed the trace smoke tests, but
  the adapted benchmark runner was outside its source directory. Neither run
  produced timing evidence.
- Run r3 completed all builds, trace checks, and measurements. Its batch exit
  code is 1 only because the final checksum command included the `callgrind/`
  directory. The result files were checksummed separately and verified; the
  stored run log records this post-processing error.
- The reusable screen script is [`run-wp1-screen.sbatch`](run-wp1-screen.sbatch).
  The exact submitted r3 script and adapted runner are retained under
  [`run-r3/`](run-r3/).

## Reproduction inputs

Decompress [`candidate-vvp.patch.gz`](candidate-vvp.patch.gz) (its original
patch SHA-256 is recorded above) and apply it at the pinned base, then add
[`vvp_trace_config.h`](vvp_trace_config.h) to reconstruct the candidate VVP
sources. The archive digests and compiler/profiler details
are recorded in [`run-r3/source-manifest.txt`](run-r3/source-manifest.txt),
[`run-r3/environment.txt`](run-r3/environment.txt), and the result checksum
manifests. No benchmark source or gold file changed.
