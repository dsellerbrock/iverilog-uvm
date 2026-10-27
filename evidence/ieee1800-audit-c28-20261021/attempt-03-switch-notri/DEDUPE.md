# §28 switch and CMOS issue dedupe

Repository: `dsellerbrock/iverilog-uvm`. Each command includes both open and closed issues via `--state all` and `--limit 1000`; these searches were re-run on 2026-10-21 before classifying attempt 03.

| Search | Matches | Disposition |
| --- | --- | --- |
| `nmos` | #878 OPEN | Search matches #878's evidence text; it only covers the `trireg` compile rejection, not `nmos` semantics |
| `tran` | #878 OPEN | Search matches #878's evidence text; it does not cover `tran` semantics |
| `rnmos` | #878 OPEN | Search matches #878's evidence text; it does not cover resistive strength semantics |
| `trireg` | #878 OPEN | Existing issue covers the unsupported net type, storage strength, and decay |
| `charge decay` | #878 OPEN | Existing issue covers decay as a behavior blocked by unsupported `trireg` |
| `28.13` | #878 OPEN | Search matches the issue's standard citation; it covers the `trireg` gap, not general switch strength reduction |
| `cmos` | none | no focused existing issue |

Command: `gh issue list -R dsellerbrock/iverilog-uvm --state all --limit 1000 --search '<term>' --json number,title,state,url`. #878 is the only Clause 28 issue so far; no further candidate exists unless these isolated probes mismatch.
