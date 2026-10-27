# IEEE 1800 §19.7 option argument depth probe

## Standard basis

IEEE 1800-2017/2023 §19.7, Tables 19-1 and 19-2. Both editions state: “Option assignment statements in the covergroup definition are evaluated at the time that the covergroup is instantiated.” Table 19-2 lists `at_least` as allowed at covergroup, coverpoint, and cross scope, with a covergroup-level default for coverpoints and crosses. Individual coverpoints or crosses may override that default. Weight, goal, comment, and per_instance do not flow down from covergroup scope.

## Cases and expected outputs

Run every source separately with `-g2017` and `-g2023`.

| Case | Probe | Expected | Routing if different |
| --- | --- | --- | --- |
| O1 | covergroup `option.at_least=al`, `al=2` | 0.00 after one sample; 100.00 after two | #835 baseline |
| O2 | coverpoint `option.at_least=al`, `al=2` | same as O1 | #835 scope |
| O3 | `option.at_least=al+1`, `al=1` | same as O1 | #835 scope |
| O4 | `option.at_least=P`, module parameter `P=2` | same as O1 | New issue candidate if it fails; constant control |
| O5 | coverpoint `option.weight=w` with `w=3`, second point weight 1, first point 100%, second 0% | group 75.00% | #835 scope |
| O6 | `option.goal=al*10`, `al=9`, read `c.option.goal` | 90 | #835 if value wrong; #689 if option read fails |
| O7 | group `at_least=2`; one point inherits, one overrides to 1; sample each once | cpA 0.00, cpB 100.00 | New issue candidate if default or override fails |

## Dedupe

Searched all open and closed issues in `dsellerbrock/iverilog-uvm` on 2026-10-21 for `covergroup option`, `option.at_least`, `option.weight`, `option.goal`, `not a constant; using default`, `19.7`, `option inheritance`, and `coverpoint option override`. Existing matches are recorded in `DEDUPE.md`. The Table 19-2 terms matched no issue.

## Run

See [RESULT.md](RESULT.md) for the Slurm job, pinned compiler and binary hashes, output summary, exact diagnostics, scheduler status, and resource-accounting limitation. Raw compiler and simulation logs, status table, input hashes, and submitted script are retained here. Each compiler and simulator process had a 60-second timeout.
