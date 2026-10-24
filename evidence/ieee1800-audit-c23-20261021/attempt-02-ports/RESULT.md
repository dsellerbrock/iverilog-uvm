# Clause 23 module-port probe results

## Environment

- Pinned simulator: Icarus 13.0-devel, commit `cc25756d1` (`cc25756d187314742d347267c2a513b3e640a7fb`), `iverilog` and `vvp` both report that SHA.
- Slurm job 3771 completed with `ExitCode=0:0`, 1 CPU, 1 GiB; 12 cases were compiled in both `-g2017` and `-g2023`. Each compiler and runtime process had a 30-second timeout. The exact staged script and checksums are in `raw-slurm-3771/staged-runner/`; raw logs, result table and scheduler state are in `raw-slurm-3771/`.
- Job 3770 is infrastructure-only; see [`INFRA-3770.md`](INFRA-3770.md). Its invalid statuses are excluded.

## Paired outcomes

| Case | Clause | 2017 | 2023 | Expected |
|---|---|---|---|---|
| D1 bus_conn defaults | §23.2.2.4 | `0fff00ff` | `0fff00ff` | match |
| D2 `.*` with missing defaulted name | §23.3.2.4 | `5a` | `5a` | match |
| D3 `.*` actual overrides default | §23.3.2.3–§23.3.2.4 | `11` | `11` | match |
| A1 packed array to array of instances | §23.3.3.5 | `1010` | `1010` | match |
| A2 unpacked array to array of instances | §23.3.3.5 | compile error: `Array I needs an array index here` | same | expected `0 1 0 0` |
| N1 `.d` absent although default exists | §23.3.2.3 | compile error: unresolved `d` | same | reject |
| N2 `.d` has 4-bit actual vs 8-bit formal | §23.3.2.3 | compiles; warns and pads 4 high bits | same | reject |
| N3 `.d` shorthand must not create a net | §23.3.2.3 | compile error: unresolved `d` | same | reject |
| N4 default in non-ANSI header | §23.2.2.4 | syntax/port declaration error | same | reject |
| N5 packed array connection has wrong width | §23.3.3.5 | compile error: width 5 vs expected 4 or 1 | same | reject |
| N6 interface port left open | §23.3.3.4 | compile error: interface port cannot be left unconnected | same | reject |
| N7 named interface type mismatch | §23.3.3.4 | compile error: incompatible interface definitions | same | reject |

Full per-edition return codes and stdout are in `raw-slurm-3771/results.tsv`; compile and runtime diagnostics are separate files in `raw-slurm-3771/logs/`. The lead verified that the 2023 wording matches 2017 and filed [#924](https://github.com/dsellerbrock/iverilog-uvm/issues/924) for A2 and [#925](https://github.com/dsellerbrock/iverilog-uvm/issues/925) for N2. The other cases were classified as passing or correctly rejected; neither failure duplicates an existing issue.
