# §13.8 static-method expression-context probe results

Slurm job 3738 ran on DAN-DESKTOP with the protected Icarus 13.0 devel
`cc25756d1` toolchain recorded in `toolchain.txt`. Each source was compiled
under `-g2017` and `-g2023`; successful compilations were run. Every compiler
and simulator invocation had a 60-second timeout. Exact diagnostics and
stdout are in `logs/slurm-3738.out` and the per-case log files; exit codes are
in `results/status.tsv`.

| Case | 2017 and 2023 result | Assessment |
|---|---|---|
| S1 plain class static method in continuous assignment | Both editions compile with rc 3: `internal error: cannot synthesize expression: <null>`, `Unable to synthesize port 0 of call to f`, then `Failed to synthesize expression`; no run | Confirms #642 |
| S2 parameterized class static method in continuous assignment | Same rc 3 diagnostics in both editions; specialization appears as `_ivl_0.f(<null>, x[3:0])`; no run | Confirms #642's parameterized case |
| S3 module function in continuous assignment | Both compile/run rc 0; `x=0 y=1`, then `x=1 y=0` | Pass control |
| S4 class static method in `always_comb` | Both compile/run rc 0; `x=0 y=1`, then `x=1 y=0` | Pass procedural control |
| S5 class static method in input port connection | Both compile with rc 2: `internal error: cannot synthesize expression: <null>`, `Unable to synthesize port 0 of call to f`, and `Port expression too complicated for elaboration`; no run | Similar expression-lowering failure outside continuous assignment; lead to classify scope |
| S6 static method called through a constant function in a `localparam` | Both compile/run rc 0; `S6 P=5` | Pass constant-expression case |

There was no edition-specific difference. IEEE 1800-2017/2023 §13.4
(2017 pp. 324–325; 2023 pp. 340–341) forbids output, inout, or ref function
arguments in the relevant expression contexts; these probes use input-only
arguments. The standard's §13.8 example itself calls a parameterized class
static method from `assign` (2017 pp. 334–335; 2023 pp. 352–353).

The run used 1 CPU and requested 1 GiB. Slurm reports completion at 0 seconds
rounded. Accounting is disabled and the batch step was gone at `sstat` time, so
peak RSS is unavailable. See `scheduler.txt`.
