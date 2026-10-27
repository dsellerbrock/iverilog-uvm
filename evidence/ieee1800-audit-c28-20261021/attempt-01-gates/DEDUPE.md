# §28 gate, switch, strength, and delay issue dedupe

Repository: `dsellerbrock/iverilog-uvm`. Each `gh issue list --state all` search includes open and closed issues; queries were run on 2026-10-21 before classifying this probe.

| Search | Matches | Disposition |
| --- | --- | --- |
| `bufif` | none | no focused existing issue |
| `wand` | none | no focused existing issue |
| `gate delay` | #44 CLOSED, broad Phase 72 parser cleanup | not a gate semantics report |
| `strength %v` | none | no focused existing issue |
| `28.` | #768 OPEN (§10.6 multi-operand procedural continuous assignment); #663 OPEN (Caliptra transfer members); #536, #46, #47, #45, #43, #44 CLOSED (unrelated historical/performance issues) | no Clause 28 issue; #44 does not report gate behavior |

The search command used for each row was `gh issue list -R dsellerbrock/iverilog-uvm --state all --limit 1000 --search '<term>' --json number,title,state,url`. No candidate gap is filed until the paired-edition probe is complete and classified by the audit lead.
