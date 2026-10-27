# Open and closed issue search

GitHub searches in `dsellerbrock/iverilog-uvm` used `--state all` for:

| Search | Assessment |
| --- | --- |
| `DPI open array` | Closed #45 is the broad DPI open-array phase; closed #13 is the broader DPI-completeness phase. Closed #505 concerns shortreal array imports, #506 fixed-size unpacked export formals, and #544 multidimensional fixed-array actuals. #12 is an unrelated randomization false positive. None duplicates these passing 1-D actual and dynamic-array geometry checks. No open match. |
| `svdpi bounds` | Closed #45 broadly covers the API; no direct issue for the checked `svSize`/bound/increment/byte-size behavior. No open match. |
| `open array range DPI` | Closed #544 concerns multidimensional fixed actuals; this probe checks 1-D ascending and descending declared ranges. No direct match and no open match. |

These are coverage results, not bug reports. If a later lead review identifies
a narrower mismatch, repeat the open-and-closed dedupe for that exact behavior.
