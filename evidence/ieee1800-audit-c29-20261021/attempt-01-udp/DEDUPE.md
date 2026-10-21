# §29 UDP issue dedupe

Repository: `dsellerbrock/iverilog-uvm`. Each search uses `--state all` and includes open and closed issues; searches were run on 2026-10-21 before classifying the paired probe.

| Search | Matches | Disposition |
| --- | --- | --- |
| `UDP` | none | no focused existing UDP issue |
| `primitive table` | #879 OPEN | Issue is the unrelated §28.14 `rnmos` strength reduction gap |
| `edge-sensitive UDP` | none | no focused existing issue |
| `29.` | #811 OPEN (§23.3.2), #663 OPEN (Caliptra transfer members), #457 CLOSED (§19 covergroup inheritance), #29–#31 CLOSED (older unrelated implementation work) | none concerns UDP semantics or Clause 29 |

Command: `gh issue list -R dsellerbrock/iverilog-uvm --state all --limit 1000 --search '<term>' --json number,title,state,url`. No existing issue covers the UDP behaviors in this probe.
