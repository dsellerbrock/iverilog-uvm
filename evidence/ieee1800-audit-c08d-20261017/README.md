# IEEE 1800 clauses 8.13–8.17 audit probes — 2026-10-17

This batch exercises the listed inheritance, overridden-member, `super`,
class-cast, constructor-chaining, and 2023 `default`/`:final` cases. It makes
no claim about unprobed parts of clauses 8.13–8.17. The lead-selected sources
are in [`tests/1800_audit/c08`](../../tests/1800_audit/c08/); exact source
hashes, runner, and combined raw output are preserved in this directory.

## Run provenance

- Host: `MacBook-Air.local`, Darwin 27.0.0, arm64.
- Compiler source revision: `9b5fad2afb4104caa816b257d5bccc40f01b8c66`.
  The compiled tools are unchanged by the audit-documentation commit
  `16b42fe5` or these test-only files.
- Icarus 13.0 devel compiler SHA-256:
  `9e98c3c982456148c2b15e866072448366fec4d5dae4273649d3e0cafcc37ed5`.
- VVP SHA-256:
  `87a81327f5eddd5d2281190338ea38e128774ff66b08c57b1de724f09a59615b`.
- Command: `~/codex-supervisor/localrun 1800 bash evidence/ieee1800-audit-c08d-20261017/run-probes.sh`.
- Localrun exit: 0; wall time: 1.83 s; peak RSS: 7,323,648 bytes.
- The runner gives each compile 60 s and each simulation 30 s. It ran the 12
  selected files under both `-g2017` and `-g2023`.
- IEEE 1800-2017 PDF SHA-256:
  `12e3dc7bafafca28af2b89ebc2761fb7a606d68716cf04c2d93c8617c78eebec`.
  IEEE 1800-2023 PDF SHA-256:
  `2280eb7f39532ca990b9bbd2e4226ae5c89910b51f42b2eb0e972df4403c9597`.

## Results

- The common positive probe passed all 12 assertions in both editions.
- The 2023-only positive probe passed all five checks in 2023 and was rejected
  in 2017 because constructor `default` and class `:final` require 2023.
- Nine negative probes were rejected in both editions as expected.
- `n08_17_extends_args_and_super_new.sv` compiled and ran in both editions.
  It prints `value=2`: `B` extends `A(1)` but explicitly calls
  `super.new(2)`. IEEE 1800-2017 §8.17 (p. 182) and IEEE 1800-2023 §8.17
  (p. 192) prohibit a subclass constructor from containing `super.new()` when
  superclass arguments are supplied in the `extends` specifier. This is a
  probe-confirmed gap candidate; the audit lead has not yet classified or
  deduplicated it, so the matrix remains unchanged for clauses 8.13–8.17.

Full compile/run output, including the confirmed mismatch, is in
[`results.txt`](results.txt). SHA-256 values for all probe sources are in
[`probe-sha256.txt`](probe-sha256.txt).
