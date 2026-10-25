# Clause 32.4.3, 32.5, and 32.6 probes

## Standards basis

The relevant text is materially the same in IEEE 1800-2017 and IEEE 1800-2023. See [`STANDARD.md`](STANDARD.md) for section and page references. Section 32.4.3's example uses the SDF value form `(dhigh 60)`; the probe uses `(tr 4)`, so the LABEL value syntax follows the standard example.

## Run

- Slurm job 3712 on DAN-DESKTOP; 1 CPU, 1 GiB requested, 10-minute limit; all 12 compile/run pairs completed under 30-second per-process timeouts.
- Toolchain: Icarus 13.0-devel, source `cc25756d187314742d347267c2a513b3e640a7fb`. SDF parser sources are unchanged from `origin/main` at `10f3a0a2509d0852c2556cb662fb0025121fb2d`.
- Compiler SHA-256: `87bb417df23d260bcfde3fb372b4a80eaad69e4fd2eea1ffb8b0eff10f7af08e`; VVP SHA-256: `dfc193c466a70a0917a16ab4198a111de616657d6004de79456db2a4b603b437`.
- Runner ended `HARNESS_STATUS=0`; all non-LABEL cases had zero `SDF ERROR`. The LABEL errors below are the observed behavior under test for standard-valid input.
- Exact compiler/runtime logs and normalized output are in [`raw-slurm/final-3712-logs/`](raw-slurm/final-3712-logs/); staged input and expected values are in [`input/`](input/) and [`expected/`](expected/).

## Results

| Rule | Expected | Observed in both editions | Result |
| --- | --- | --- | --- |
| §32.4.3 `LABEL` updates specparams used in specify-path expressions | Rise/fall 4/6 | LABEL-only SDF reports three `SDF ERROR` lines (`Too many errors: syntax error`, `Syntax error in CELL`, `Invalid DELAYFILE format`); path remains at source delay 1/1. No warning is emitted. | Gap |
| §32.4.3 control: ordinary IOPATH on the same cell and scope | Rise/fall 4/6 | Rise/fall 4/6, no SDF diagnostic | Pass |
| §32.4.3 mixed CELL with IOPATH then LABEL | IOPATH remains 4/6; unsupported LABEL should be reported as a warning | IOPATH remains 4/6, then the same three LABEL-related `SDF ERROR` lines; no warning | LABEL gap; valid delay section survives |
| §32.5 ABSOLUTE 4/6 then INCREMENT 1/1 | Rise/fall 5/7 | Rise/fall 1/1; no warning or error | Gap: the later increment replaces the delays instead of adding |
| §32.5 INCREMENT 1/1 then ABSOLUTE 4/6 | Rise/fall 4/6 | Rise/fall 4/6; no warning or error | Pass; the later absolute value overwrites |
| §32.6 calls scoped to `u1` and `u2`, then a later file modifies `u1` | `u1` rise/fall 5/7; `u2` 7/9 | `u1` behaves as 1/1, `u2` behaves as 7/9. No warning or error. | Scope isolation passes; `u1` result is the same INCREMENT gap as §32.5, not a separate §32.6 gap |

The `p32_multi` sampled outputs are `R1 10, R2 10, R3 11, F1 01, F2 01, F3 00`; `u2` retains its distinct 7/9 delay while the final `u1` INCREMENT is applied as 1/1. The first queued run (job 3710) sampled one multi-file transition exactly on an edge; its raw logs are retained under `raw-slurm/initial-3710-logs/`. Job 3712 moved samples off the edge and confirms the same result.

## Parser evidence and dedupe

- [`parser-source.txt`](parser-source.txt) captures the current CELL grammar: `timing_spec` accepts DELAY and TIMINGCHECK, and the lexer has no LABEL token/production. The standard-valid LABEL section is rejected at CELL parsing.
- [`DEDUPE.md`](DEDUPE.md) and [`dedupe-search.json`](dedupe-search.json) record the full open+closed issue search. No existing issue covers §32.4.3 LABEL parsing or §32.5 INCREMENT ordering. #19 and #822 discuss other specparam contexts; #880, #898, and #899 cover PATHPULSE, TIMINGCHECK, and optional `$sdf_annotate` arguments, respectively.
- SDF warnings: none in this run. The LABEL cases produce SDF errors instead; other cases produce neither SDF errors nor warnings.

## Limits

The LABEL probe exercises a specparam in a specify-path expression; a procedural-delay specparam was not separately run. The same CELL parser rejection prevents reaching either annotation use. No broader Clause 32 features or regression suites were run in this probe.
