# Uniform legal-combination sampling — 2026-10-06

The unordered class-B regression (`rand bit s; rand bit [31:0] d; s -> d == 0`)
failed before the fix at 61 `s == 1` results in 256 draws. The current paired
2017 and 2023 regression passes. It checks at most 10 unordered `s == 1`
results and 90–166 ordered results in 256 draws; the ordered control keeps the
approximately even marginal required by `solve s before d`.

The change rejection-samples complete tuples for coupled active direct scalar
class properties of widths 1–64 when solve-before, `dist`, soft constraints,
`randc`, containers, member properties, and symbolic state checks are absent.
Independent factors are split with `z3_joint_components_`; if that analysis
cannot prove a split, the sampler checks the whole active scalar tuple. Each
candidate is uniform over the bit-vector domain, and only solver-accepted
tuples are committed. The owning object RNG is used. Unsupported shapes remain
outside this implementation and keep the broader blocker open.

Paired commands, run from the repository root:

```sh
local-install/bin/iverilog -g2017 -s main -I ivtest -o /tmp/uniform-2017.vvp ivtest/ivltests/sv_randomize_global_uniform.v
local-install/bin/vvp /tmp/uniform-2017.vvp
local-install/bin/iverilog -g2023 -s main -I ivtest -o /tmp/uniform-2023.vvp ivtest/ivltests/sv_randomize_global_uniform_2023.v
local-install/bin/vvp /tmp/uniform-2023.vvp
```

Both runs printed `PASSED`. VVP SHA-256: `d1303bdda33e75fa7b33a70e6e8e67278abb9e520dc19617894e505eae671519`.

The adjacent `sv_randomize_global_sampling_fail` regression also printed
`PASSED` under both editions. Its expected oversized-domain warning and
unsupported-size error remained; it checks failure value/callback atomicity,
bounded joint sampling, `dist`, and solve-before behavior. It does not qualify
those excluded paths for uniform legal-tuple sampling.
