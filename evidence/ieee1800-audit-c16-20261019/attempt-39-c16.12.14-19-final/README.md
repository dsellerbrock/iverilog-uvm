# Clause 16.12.14–.19 audit probes

Slurm job 3215 completed with exit code 0 on `DAN-DESKTOP` (1 CPU, 1 GiB, 20-minute limit). The harness ran each probe with `-gassertions` under both `-g2017` and `-g2023`; all expected compile/runtime outcomes matched the harness (`TOTAL_UNEXPECTED=0`). Per-command timeout was 120 seconds.

Pinned toolchain: Icarus main `c31cbf1b52f1a39d5775f276e2340525a444a79e`; `iverilog` SHA-256 `f958f85546420cdaf3c67d73e7c377e63a55a3df9c4dca6de16955e81000b818`; `vvp` SHA-256 `b0e2b7f230be80efe2e04b28ad5a688c46f93eaad692d34bfe27895a61983be6`.

| Clause | Probe result in both editions | Standard basis |
| --- | --- | --- |
| §16.12.14 | All four abort operators (`accept_on`, `reject_on`, and both `sync_` forms) pass the Boolean semantic counter check. A valid temporal operand, `accept_on(abort_cond) (a ##1 b)`, is rejected with the Boolean-only `sorry`. | IEEE 1800-2017/2023 §16.12.14 |
| §16.12.15 | A completed sequence passes for both `weak` and `strong`. At end of simulation with a second attempt pending, the observed counts are weak=0, strong=0; §16.12.15 requires the strong attempt to fail when it cannot terminate. | IEEE 1800-2017/2023 §16.12.15 |
| §16.12.17 | A positive-time recursive property runs over the next sampled cycle and produces the two expected failures from the direct and recursive attempts; the test self-check passes. | IEEE 1800-2017/2023 §16.12.17 |
| §16.12.18 | Untyped formal declaration and direct instantiation pass. A standard-valid `logic [3:0]` typed formal is rejected at parse time. | IEEE 1800-2017/2023 §16.12.18 |
| §16.12.19 | Standard-valid `local input int` formal syntax is rejected at parse time. The illegal `local output` control also gets a syntax error, so the semantic direction check is masked by missing local-formal syntax. | IEEE 1800-2017/2023 §16.12.19 |

Inputs are archived in `input-r4/probes.tar.gz` (SHA-256 `4f28f60eeaeb7701077f389998ed090f018d0867af2c7d0d77203ed9d20131e5`). The exact Slurm script is `run.sbatch` (SHA-256 `7c3c49f1ce7e31a9370a36db76c2d5860d951b2025fee3960e193dca178b9bd9`). Raw job logs, compile/run logs, VVP outputs, inputs, and script are in `results-3215.tar.gz` (SHA-256 `ba5938890dc477c1a9976b50efb7e09f4490805db53be4ef25014ff73839e0e4`); extracted summary is `results-3215/logs/a3-c16-14-19-3215.out`.

Jobs 3212–3214 were exploratory harness revisions (assertion counters sampled before end-of-simulation, a recursive test using a currently unsupported property-branch shape, and an untyped-formal control nested in a different context). They are not used for these classifications; job 3215 is the final corrected probe set.

For provenance, the superseded Slurm result archives are retained: job 3212 `results-3212.tar.gz` (SHA-256 `40d02f3264d05a7b1519cbb81ff2fe3ccb13608bb7991e66a9691499bac4c3c7`), job 3213 [`superseded/results-3213.tar.gz`](superseded/results-3213.tar.gz) (SHA-256 `6d9598b7b0ccd16c43a9cb0fed38d712900e1c9e715dcdb30698b5a1e84afab7`), and job 3214 [`superseded/results-3214.tar.gz`](superseded/results-3214.tar.gz) (SHA-256 `e414810d3b4b0cca13dbea2f439e5e9cb1dfad1b9be8c234b759d7d5f3365697`).

Lead classification and gap tracking: §16.12.14 PARTIAL [#723](https://github.com/dsellerbrock/iverilog-uvm/issues/723); §16.12.15 PARTIAL [#724](https://github.com/dsellerbrock/iverilog-uvm/issues/724); §16.12.17 IMPLEMENTED (tested subset); §16.12.18 PARTIAL [#725](https://github.com/dsellerbrock/iverilog-uvm/issues/725); §16.12.19 MISSING [#726](https://github.com/dsellerbrock/iverilog-uvm/issues/726).
