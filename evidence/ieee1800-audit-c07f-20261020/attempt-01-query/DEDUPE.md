# §7.11 / §20.7 open-and-closed issue dedupe

Repository `dsellerbrock/iverilog-uvm`; searches run 2026-10-20 before classifying the new probes.

| Search | Open matches | Closed matches | Review |
|---|---|---|---|
| `$dimensions` | #757, #794, #792, #808, #830, #783, #851, #728, #428, #485, #484 | #487, #544, #492, #499, #415, #99, #42 | #792 already covers queries with a data-type argument. #794 already covers §20.7.1 dynamic-dimension queries. Other matches concern type matching, VCD, foreach, reductions, array equality/copy, associative element types/patterns, or ports. |
| `$increment` | #793, #718, #633, #824 | #498, #502, #45, #47 | #793 already covers incorrect integral-key associative-array query values. Other matches concern sequence-match expressions, subroutine defaults, interface declarations, packed-select arithmetic, DPI, or project phases. |
| `$unpacked_dimensions` | #794 | none | #794 already covers the exact §20.7.1 array with a dynamic dimension. |
| `array query` | #793, #794, #792 | none | The integral-key associative queries, dynamic dimensions, and data-type arguments are already covered by these three issues. |
| `20.7` | #793, #792 | none | Same existing issues; #794 appears through other query terms. |

Reviewed #792, #793, and #794 bodies. The current probes overlap those existing issues on: data-type query expressions (`S`), associative queries with integral keys (`A`), and §20.7.1 legal/illegal variable-dimension queries (`M`, `n2`). These results should be posted to the existing issues. The string-key `$size` compile-negative rule (`n1`) is not covered by #793, whose scope is wrong results for valid integral-key associative arrays. The remaining dimension/query cases have no matching issue in these searches.
