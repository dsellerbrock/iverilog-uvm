# IEEE 1800 uniqueness shape follow-up, Slurm job 3457

## Standards

- IEEE 1800-2017 §18.5.5, p. 513; IEEE 1800-2023 §18.5.4, p. 534.
- The 2023 uniqueness rule permits `real` scalar members and real-leaf unpacked arrays. 2017 rejects `rand real` under §18.4, before uniqueness is checked.

## Evidence

- DAN-DESKTOP, Slurm job 3457, 1 CPU / 1 GiB, 2026-10-20T15:26:19Z–15:26:20Z. Each compiler and runtime process had a 30-second process-group timeout. Slurm accounting is disabled, so peak RSS is unavailable.
- Icarus 13.0-devel `cc25756d1`; binary and input hashes are in `remote-results/` and `SHA256SUMS-input.txt`.
- The six integer shapes produced the same results in both editions:

```text
S1 ok=0 bad=0
S2 ok=50 bad=0
S3 ok=50 bad=0
S4 ok=0 bad=0
S5 ok=0 bad=0
S6 ok=50 bad=0
```

  S1 is slice-only, S2 scalar pair, S3 scalar plus whole array, S4 scalar plus slice, S5 scalar plus slice plus scalar, and S6 two constant-index elements. Compile warnings identify S1 line 4, S4 line 16, and S5 line 20 as not representable. The first exact runtime error in each edition is: `ERROR: constraint state read: the constraint item at .../p18_05_5_unique_shapes.sv:4 is not supported by the constraint solver; randomize() fails rather than ignore it.`
- The 2023 scalar real test compiled and ran with `R1 ok=0 bad=100 R1P rc=0`. It repeatedly reports `ERROR: global constraint sampling failed: no feasible binary64 value satisfies the finite real interval.` The -g2017 compilation rejects `rand real` at §18.4 as expected. The real failure may be caused by singleton `inside` handling rather than the `unique` constraint; a no-`unique` control is pending lead direction.
- The lead filed [#839](https://github.com/dsellerbrock/iverilog-uvm/issues/839) for the slice-member refusal, after the open+closed dedupe. The scalar-real result still needs an inside-only control before it can be classified. The broader 2023 fixed-size real-array gap is on [#463](https://github.com/dsellerbrock/iverilog-uvm/issues/463), with probe evidence posted in [comment 6294443723](https://github.com/dsellerbrock/iverilog-uvm/issues/463#issuecomment-6294443723).

## Dedupe

Open and closed queries, including the lead-requested `constraint state read not supported` search, are copied from the preceding attempt in `dedupe-open-closed.txt`. The searches found no existing unique-slice issue.
