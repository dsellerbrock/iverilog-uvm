# Results: IEEE 1800 §19.7 option depth probes

## Environment and command

- Slurm job 3736 on DAN-DESKTOP; submitted 2026-10-21 06:28 host time; completed with scheduler exit `0:0`. `scontrol` reports a runtime rounded to `00:00:00` (start/end in the same second).
- Requested resources: 1 CPU, 1 GiB, 10 minutes. Slurm accounting is disabled and the completed job step is unavailable to `sstat`, so peak RSS was not recorded; scheduler status and metric output are retained in `scheduler.txt` and `scheduler-metrics.txt`.
- Icarus Verilog 13.0 devel, commit `cc25756d1`, from `/home/dsell/toolchains/iverilog-uvm-a3-audit-cc25756d187314742d347267c2a513b3e640a7fb`. SHA-256: `1088dd266d4715d5a99d4eb5f7ae7a128449744927bae1971b37278872613593` (`iverilog`), `e66837952db8927f4ef69007b4290c07e23f30f9258facae416da98c95715bbb` (`vvp`).
- Each source was compiled and run under `-g2017` and `-g2023`; every process used a 60-second timeout. Exact commands are in `run.sbatch`; compiler/simulator logs and return codes are retained. The job reported `compile_rc=0` and `run_rc=0` for all 14 edition/case pairs.

## Outcomes

| Case | Expected | Actual in both editions | Result |
| --- | --- | --- | --- |
| O1 group `at_least=al`, `al=2` | 0.00 after 1; 100.00 after 2 | 100.00; 100.00 | #835 fallback reproduced |
| O2 coverpoint `at_least=al`, `al=2` | 0.00; 100.00 | 100.00; 100.00 | #835 scope reproduced |
| O3 `at_least=al+1`, `al=1` | 0.00; 100.00 | 100.00; 100.00 | #835 fallback; also emits unresolved-binding warning for `al` |
| O4 `at_least=P`, module `parameter P=2` | 0.00; 100.00 | 0.00; 100.00 | Pass; constant parameter works |
| O5 coverpoint weights 3:1, coverage 100%:0% | group 75.00 | group 75.00; points 100.00/0.00 | Pass; argument-valued point weight works |
| O6 `goal=al*10`, `al=9`, then read `c.option.goal` | 90 | 0 | Readback gap; compile-time `sorry` below |
| O7 group `at_least=2`; point override 1; one hit each | cpA 0.00; cpB 100.00 | cpA 0.00; cpB 100.00 | Pass; constant default and override work |

## Diagnostics, verbatim

O1 and O2, in both editions:

```text
sorry: covergroup option 'at_least' is not a constant; using default 1.
```

O3, in both editions:

```text
input/o3_expression_at_least.sv:5: warning: Unable to bind wire/reg/memory `al' in `o3_expression_at_least.cg' (compile-progress: unresolved reference).
sorry: covergroup option 'at_least' is not a constant; using default 1.
```

O6, in both editions (from the `c.option.goal` read):

```text
input/o6_goal_readback.sv:11: sorry: covergroup option members are not run-time state; this read evaluates to constant 0 (set options in the covergroup body instead).
```

## Disposition

O1–O3 confirm and scope the existing #835 gap. O4 and O7 pass, so this probe supports no new issue candidate. O5 passes despite the nonconstant constructor-argument value. O6's assignment itself emits no diagnostic; the attempted option read returns 0 and maps to the existing #689 option-member read scope per lead direction. No issue was filed by the runner.
