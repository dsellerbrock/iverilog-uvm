# IEEE 1800 §16.13.7 probe results

The standard-example property fails to compile in both editions at its
declaration initializer `logic v = e;`. Slurm job 3596, using Icarus
`cc25756d1`, returned compile status 1 for `-g2017` and `-g2023`. The primary
diagnostic is `syntax error` at line 8, the initializer. The later “Unable to
bind ... p” diagnostic is parser recovery after that error; no simulation ran.

The positive control in Slurm job 3597 passed in both editions. It runs the
existing `p16_10_local_vars_property.sv`, which declares a local property
variable without an initializer and assigns it in a sequence match item. This
isolates the unsupported declaration-initializer form from basic property
local-variable handling.

IEEE 1800-2017/2023 §16.13.7 explicitly defines local-variable declaration
initialization for named sequences and properties, including separate copies
for distinct semantic leading clocks. The probe uses the standard's two-clock
example pattern and changes `e` between the first `clk1` and `clk2` ticks.

| Edition | §16.13.7 compile | §16.10 control compile/run |
|---|---:|---|
| 2017 | 1, syntax error at initializer | 0 / 0, PASS |
| 2023 | 1, syntax error at initializer | 0 / 0, PASS |

The direct probe command is recorded in `run.sbatch`; each compile/run had a
30-second timeout. Raw compiler output, host and tool versions, hashes, and
timing are under [`remote-3596/`](remote-3596/) and
[`attempt-02-local-var-control/remote-3597/`](../attempt-02-local-var-control/remote-3597/).
Open-and-closed issue dedupe returned no hits for the recorded terms; see
[`DEDUPE.md`](DEDUPE.md). The candidate remains lead-pending; no issue was
filed by the runner.
