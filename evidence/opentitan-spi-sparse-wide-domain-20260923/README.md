# SPI wide-scalar enumeration triage

## Trigger and call path

The pinned flash-mode replay is the saved VVP image `spi-07d8ba6.vvp` (SHA-256
`0ce4ed3f7c7505160d7329806d12ed6516cb1244a2197f9fdab0fcd652ec2883`) run by
the installed `b56c6424…` VVP. Its command, working directory, and 120.32 s
timeout are in `evidence/opentitan-spi-device-current-20260923/result.json`
and `/tmp/ivl-focus-20260923/spi-dist-lazy-item-flash.result.json`. The replay
does not supply `+ntb_random_seed`, so its seed is the simulator default (not
recorded as a fixed integer); it prints PRE_START at 5,026,568 ps and has no
later UVM result in the bounded log.

A 4 s sample on that candidate appears in `flash-profile-sample.txt`. It
places the active solver time in `z3_solve_pass_`'s scalar-sampling lambda,
`sample_scalars`, then `z3_enumerate_sparse_wide_domain_`: 737 sampled frames
in the helper versus 70 in `z3_enumerate_domain`. No
`z3_resolve_dist_exact`, `exists_in`, or candidate dist projection frame
appears in the sample. The bounded `IVL_Z3_SOLVE_TRACE=1` replay is in
`flash-solver-trace.log.gz`; it recorded 69 `cip_tl_seq_item` solves (13 solver
variables, five soft constraints, zero dist specs) and 44
`dv_base_reg_field` solves (one variable, mostly no dist). The trace ran only
briefly and was stopped after evidence capture; it is not a test result.

The relevant source is `vvp/vvp_z3.cc`: `z3_enumerate_sparse_wide_domain_`
starts at line 6261; `sample_scalars` starts at line 8232 and calls the helper
after the ordinary exact domain enumerator declines. The sparse helper creates
up to 65 complete Z3 models while blocking one scalar value at a time. The
preceding enumerator declines a 32-bit property because its full domain is
larger than `ENUM_DOMAIN_CAP` (1024). In the unchanged TL item source,
`a_valid_delay`, `a_valid_len`, `d_valid_delay`, and `d_valid_len` are 32-bit
unsigned random fields with soft-only small intervals (`tl_seq_item.sv:58-64,
93-103`). Those soft constraints are not hard assertions in the feasibility
solver; therefore the hard projection of each such field is wider than the
64-value sparse cap. This is a plausible repeated trigger for the sample, but
the profiler did not attribute individual helper invocations to a specific
property, so that mapping remains an inference.

## Paired minimal reproducer and boundary

`wide_reducer.sv` models an unconstrained 32-bit hard domain with a coupled
parity field and a soft `[0:50]` interval. `narrow_boundary.sv` is identical
except that its subject is 6 bits, so its full 64-value domain stays under the
normal exact-enumeration cap. Both were compiled with the installed compiler
using `-g2017` and `-g2023`; both pass with `+ntb_random_seed=1`. The 8-call
wall times on this host were 0.07/0.08 s for the wide form and 0.04/0.03 s for
the narrow form (2017/2023 respectively). These runs validate the fixtures,
not a broad performance claim. Compile and run logs are stored alongside the
sources.

## Candidate narrow optimization and uncertainty

After exact bounded enumeration declines, a syntactic proof that a wide scalar
does not occur in any hard assertion would establish a full hard domain of
`2^width` values. For widths above 10 bits that domain exceeds both current
caps, so the 65-model probe must fail and immediately enter the same existing
fallback. Skipping that provably doomed probe would preserve the current
fallback and consume no owner RNG. However, fewer base-solver queries may
change internal solver heuristics or downstream model choices. This has not
been implemented or proven seed-for-seed, so no source change is proposed in
this triage.
