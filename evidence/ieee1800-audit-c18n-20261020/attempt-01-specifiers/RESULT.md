# IEEE 1800 constraint specifiers and set membership — Slurm job 3480

## Standards

- IEEE 1800-2023 §18.5.2, pp. 530–531: `:initial` marks a non-override,
  `:extends` marks an override, the two are mutually exclusive, `:final`
  prevents replacement, and prototype/external-block specifiers must match.
- IEEE 1800-2017 §18.5.2: inheritance rules without these 2023 specifiers.
- IEEE 1800-2017 §18.5.3, p. 511: set membership in constraints gives every
  value equal probability absent other constraints, supports negation and
  expression ranges. IEEE 1800-2023 defines the operator in §11.4.13.

## Environment and evidence

- DAN-DESKTOP, Slurm job 3480; 1 CPU, 1 GiB; 15 seconds wall time.
- Pinned Icarus 13.0-devel `cc25756d1`; executable hashes are in
  `remote-results/job-3480/results/SHA256SUMS`.
- Each compiler and simulation process had a 30-second process-group timeout.
- `results.tsv` timing fields are reconstructed from the raw GNU `time` files.
  The original runner table is retained as `results-runner.tsv`, and the
  untouched Slurm output is `job-3480.out`.

## Results

`p18_05_2_specifiers.sv` compiles and runs under `-g2023`: `SPEC ok=50 bad=0`;
every sample is in `{8, 10, 12, 14}`. Under `-g2017`, the compiler rejects the
new specifiers as IEEE 1800-2023-only syntax.

All five negative probes reject under `-g2023`: `:initial` on an override,
`:extends` without an inherited name, both mutually exclusive specifiers,
overriding a `:final` constraint, and a prototype/external-block specifier
mismatch. Under `-g2017`, the new specifiers are rejected as edition-gated
syntax (the mutually exclusive form is rejected by the parser).

The §18.5.3 set-membership probe passes in both editions. For 4,500 random
samples, the nine allowed values have counts `3:487 5:499 9:480 10:489 11:482
12:493 13:524 14:529 15:517`, all within the lead's 500±105 bound. Negated
membership and an expression range both pass 200 checks (`S2 bad=0`,
`S3 bad=0`). Each edition took 7.14 seconds for these checks.

## Dedupe and classification

- Open and closed searches for `"final constraint"`, `":extends"`,
  `"initial specifier"`, and `"constraint specifier"` identified closed issue
  [#456](https://github.com/dsellerbrock/iverilog-uvm/issues/456), which directly
  covers the constraint specifiers. All directed cases pass; no duplicate issue
  or comment is needed.
- Open and closed searches for `"inside uniform"`,
  `"set membership constraint"`, and `"18.5.3 inside"` returned no matches.
- The audit total remains 107 issues: §18 has 11. This probe adds no issue.
  The two latest filings, #841 and #842, are both §18.5.1.

## Raw files

`remote-results/job-3480/results/` contains per-case compile/run logs, timing
and RSS records, toolchain hashes, and timestamps. The staged input hashes are
in `input/SHA256SUMS-input.txt`.
