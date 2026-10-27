# §§24.4 and 24.7 issue dedupe

Repository: `dsellerbrock/iverilog-uvm`; each `gh issue list --state all --limit 1000 --search ...` query searched open and closed issues.

| Search | Matches | Disposition |
| --- | --- | --- |
| `"testbench race"` | none | no focused prior report |
| `"reactive region program sample"` | none | no focused prior report |
| `"24.4"` | #877 OPEN | §24.5 forbidden module-to-program task call; unrelated race-avoidance behavior |
| `"program block race"` | none | no focused prior report |
| `"program testbench race"` | none | no focused prior report |
| `"$exit"` | #786 OPEN plus other unrelated matches, including #876 and #877 | #786 is the existing module-origin `$exit` candidate; paired job 3656 confirmed the violation |
| `"module-origin exit"` | #786 OPEN | exact existing candidate; it was retitled and updated with the paired reproduction; no duplicate issue filed |

Closed #17 (“Phase 13: Clocking blocks and program blocks”) was inspected: it is a broad historical feature umbrella, but does not assert the specific §24.4 observation/write ordering tested here. The exact #786 body and comments were reviewed; its title now tracks the module-origin variant, with the program-origin correction in [comment 6309531937](https://github.com/dsellerbrock/iverilog-uvm/issues/786#issuecomment-6309531937) and the paired module-origin result in [comment 6309671512](https://github.com/dsellerbrock/iverilog-uvm/issues/786#issuecomment-6309671512).
