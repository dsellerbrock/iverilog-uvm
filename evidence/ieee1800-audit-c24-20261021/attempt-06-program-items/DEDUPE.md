# §24.3 program-item issue dedupe

Repository: `dsellerbrock/iverilog-uvm`; each `gh issue list --state all --limit 1000 --search ...` query searched open and closed issues.

| Search | Matches | Disposition |
| --- | --- | --- |
| `"always in program"` | none | no focused prior issue |
| `"program instance module"` | none | no focused prior issue |
| `"nested program"` | none | no focused prior issue |
| `"24.3"` | #746–#750 OPEN (§6.24.3 casts), #772 OPEN (§11.4.14.3), #876 OPEN (§24.6 anonymous program) | different clauses and behavior; no §24.3 program-item rule |
| `"program declaration"` | none | no focused prior issue |
| `"program item"` | #876 OPEN | §24.6 anonymous-program syntax, not §24.3 prohibited items |
| `"program construct"` | none | no focused prior issue |
| `"program may contain"` | none | no focused prior issue |

Closed #17 (“Phase 13: Clocking blocks and program blocks”) is a broad historical implementation umbrella; it does not report these specific item-validation rules. No new issue is filed before the paired probe results are classified.
