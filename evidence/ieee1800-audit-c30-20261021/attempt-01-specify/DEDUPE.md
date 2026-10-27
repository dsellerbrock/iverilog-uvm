# §30 specify-path issue dedupe

Repository: `dsellerbrock/iverilog-uvm`. On 2026-10-21, searched open and closed issues (`--state all`, limit 1000) with `specify path delay`, `specify pulse`, `path pulse reject`, and `module path delay`.

| Search | Matches | Disposition |
| --- | --- | --- |
| `specify path delay` | #825 OPEN (§25.6 interface-signal path terminals); #44 and #19 CLOSED (broad unrelated issues) | #825 is about interface-signal path terminals, not path delay selection or pulse rejection. |
| `specify pulse` | none | No existing issue. |
| `path pulse reject` | none | No existing issue. |
| `module path delay` | #825 OPEN; #44 and #19 CLOSED | Same unrelated matches as above. |

The broad `specify` search also surfaced unrelated issue text; no Clause 30 issue covers ordinary path rise/fall delays, state-dependent paths, or default pulse rejection. Search command: `gh issue list -R dsellerbrock/iverilog-uvm --state all --limit 1000 --search '<term>' --json number,title,state`.
