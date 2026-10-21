# §24.4–24.5 issue dedupe

Repository: `dsellerbrock/iverilog-uvm`; searches used `gh issue list --state all --limit 1000`, which searches both open and closed issues.

| Search | Matches | Disposition |
| --- | --- | --- |
| `"program task module"` | none | no prior report found |
| `"24.5"` | none | no prior report found |
| `"24.4"` | none | no prior report found |
| `"program subroutine"` | none | no prior report found |
| `"reactive region" "program"` | #17 CLOSED, “Phase 13: Clocking blocks and program blocks” | inspected body/comments: covers program/clocking constructs and high-level Reactive scheduling, but does not claim module-task call inheritance or rejection of module-to-program subroutine calls |
| `"module calls program"` | none | no prior report found |
| `"program task"` | #876 OPEN, anonymous program task declaration in a package | different clause and behavior |
| `"called from a program"` | none | no prior report found |
| #786 exact issue | #786 OPEN | §20.2/$exit, but its own source has both initial procedures in one program; this run will verify and correct its expected output if confirmed |

Both §24.5 probes completed in Slurm job 3655. The positive direction is supported in the tested subset; the negative direction is accepted without an error, and the lead filed [#877](https://github.com/dsellerbrock/iverilog-uvm/issues/877) after reviewing this open+closed dedupe.
