# Open and closed issue dedupe

Repository searched: `dsellerbrock/iverilog-uvm`; open and closed states searched separately on 2026-10-20.

| Search | Open results | Closed results | Review |
|---|---|---|---|
| `associative array class index` | #429 indexed class-array member operations; #484 associative arrays with fixed-array elements; #734 `string.len()` on a fixed unpacked string array | none | #429 tracks class-array member lvalues/receivers, not class handles as associative keys. #484 tracks fixed-array values. #734 is unrelated. |
| `null index` | #429; #850 empty two-state queue pop | #157, #502, #97, #30, #27 | None concerns null class-key indexing. |
| `struct index associative` | #734; #801 `%p` formatting of associative arrays of structs | none | Neither tracks struct keys/index lookup. |
| `associative array argument` | #803 readmemh/writememh reject associative-array arguments | none | System-task memory arguments, not subroutine formal compatibility. |
| `7.8.3` | none | none | No direct candidate. |
| `7.9.10` | none | none | No direct candidate. |
| `associative array class index segfault` | none | none | No duplicate runtime-crash report. |
| `associative array segmentation fault` | none | none | No duplicate runtime-crash report. |
| `struct associative array index` | #734; #801 | none | No direct candidate. |

Directly reviewed #429, #484, #801, and #803. The positive probe's runtime crash is not yet attributed to a specific feature; the lead must direct isolation before a new issue is filed.
