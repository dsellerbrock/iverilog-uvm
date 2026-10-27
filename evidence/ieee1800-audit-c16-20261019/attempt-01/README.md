# IEEE 1800 Clause 16.3 probes

Four focused probes check simple immediate assertion action blocks, immediate
assume action blocks, immediate cover pass actions, and rejection of temporal
syntax in an immediate assertion. The same sources are compiled under
`-g2017` and `-g2023`.

The normative text in IEEE 1800-2017 §16.3 (pp. 364–366) and IEEE 1800-2023
§16.3 (pp. 383–385) says an immediate assertion evaluates a nontemporal
expression when its procedural statement executes; X, Z, and 0 fail. The
assert/assume pass action executes on true and fail action on false. Immediate
cover's statement executes on true. Syntax 16-1 defines the immediate
assertion expression as `expression`, which excludes temporal sequence
operators.

Slurm job **3170** ran on DAN-DESKTOP with 1 CPU and 1 GiB (each compile and
simulation has a 120-second timeout). It used the pinned read-only simulator
built from staged source `6604c23e197980b69a5b6b69864ff8ef8d05eba3`:
Icarus 13.0-devel, `iverilog` SHA-256
`f8c0376ed73753c3327b1d7f5d4d647820836799064d965be7e1a8fbb9403ccd`, `vvp`
SHA-256 `53ad297f5370175e0df8af51c5947b7b34c723cf258617febf716cf82168249b`.

All three positive probes compiled and ran with exit 0 and printed `PASSED`
under both editions. The temporal syntax probe failed compilation in both
editions with `syntax error` and `Malformed conditional expression`. The
complete stdout, compile logs, simulator version, and input hashes are recorded
in this directory. The job left the queue; Slurm accounting is unavailable on
this host, so its final state is confirmed by the complete run log and each
expected result, not by `sacct`.

Input SHA-256:

| Probe | SHA-256 |
| --- | --- |
| `p16_03_simple_assert.sv` | `3b75bec0b4df8234b5f91cceadf23c21340f0e5e49cb7fe536dcddcc908bf764` |
| `p16_03_simple_assume.sv` | `2d3b33a5a506abcf082fdad48d745e6a069469e07345a26dc9dcc197f1b63785` |
| `p16_03_simple_cover.sv` | `4d1268d6b905ac8d817593ac29495da1c69dfadebc04ec4414991c86f40b94b0` |
| `n16_03_temporal_in_immediate.sv` | `24d6859af5cf69838f440395f54b6c61ed75e47c5c0dd02b214412aae3114756` |
| `run.sbatch` | `e0a68ebe5833f3ef565ec60ada869dbb69e1dff324afac0fe633a4da1173eb16` |
