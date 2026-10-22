# §31 timing-check issue dedupe

Repository: `dsellerbrock/iverilog-uvm`. On 2026-10-21, open and closed issues were searched with `gh issue list -R dsellerbrock/iverilog-uvm --state all --limit 1000 --search '<term>' --json number,title,state` for `"$setup"`, `"$hold"`, `"$width"`, `"timing check"`, `"notifier"`, and `"31."`.

| Search | Matches | Disposition |
| --- | --- | --- |
| `"$setup"` | #825 OPEN (§25.6); #536, #46, #27 CLOSED | #825 is interface-signal specify path terminals; the closed matches are unrelated. |
| `"$hold"` | #616, #652, #878, #879 OPEN; #30 CLOSED | Class, array-query, trireg, resistive-switch, and UVM port issues; none are timing checks. |
| `"$width"` | OPEN: #797, #860, #420, #757, #838, #659. CLOSED: #498, #666, #533, #431, #494, #438, #434, #462, #488, #480, #436, #503, #667, #99. | Caliptra formatting, aliases, randomization, type matching, coverage, arrays, clockvar, casts, and other unrelated issues; no timing-check issue. |
| `"timing check"` | none | No existing issue. |
| `"notifier"` | none | No existing issue. |
| `"31."` | OPEN: #730, #788, #757, #860, #792, #859, #663. CLOSED: #477, #661, #680, #536, #30, #16. | Broad numbering/text matches for unrelated clauses or issue numbers. |

No existing issue covers Clause 31 setup, hold, width checks, timing-violation reports, or notifier behavior. Re-run focused open+closed dedupe before any issue is filed, using the specific failure mode and clause.
