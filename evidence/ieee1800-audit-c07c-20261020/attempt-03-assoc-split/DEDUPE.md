# Per-feature open and closed issue dedupe

Repository: `dsellerbrock/iverilog-uvm`. Searched separately on 2026-10-20 before any issue filing.

| Search | Open results | Closed results |
|---|---|---|
| associative array class index | #429, #484, #734 | none |
| null index | #429, #850 | #157, #502, #97, #30, #27 |
| struct index associative | #734, #801 | none |
| associative array argument | #803 | none |
| 7.8.3 | none | none |
| 7.9.10 | none | none |
| associative array class key | [{"number":484,"title":"[IEEE 1800] §§7.4/7.8 — Support associative arrays with fixed-array elements"},{"number":485,"title":"[IEEE 1800] §§7.6/7.8 — Validate variable-size associative pattern values transactionally"},{"number":850,"title":"[IEEE 1800] §7.10.2.4/§7.10.2.5 — pop_front()/pop_back() on an empty 2-state integral queue return x instead of 0"}] | [] |
| derived class associative array key | [] | [] |
| null associative array index | [{"number":850,"title":"[IEEE 1800] §7.10.2.4/§7.10.2.5 — pop_front()/pop_back() on an empty 2-state integral queue return x instead of 0"}] | [] |
| associative array struct index | [{"number":734,"title":"[IEEE 1800] §6.16.1 — string len() returns 1 for an element of a fixed unpacked string array"},{"number":801,"title":"[IEEE 1800] §21.2.1.7 — %p of an associative array of structs prints question marks for the element values"}] | [] |
| associative array assignment copy | [] | [] |
| associative array pass by value | [{"number":801,"title":"[IEEE 1800] §21.2.1.7 — %p of an associative array of structs prints question marks for the element values"}] | [{"number":44,"title":"Phase 72: Parser 'sorry' cleanup — clocking, let, bind, misc syntax"}] |
| associative array ref argument | [] | [] |

These are title-level search results, not disposition. Review any returned candidates against the feature-specific probe before filing.

Reviewed candidate scopes: #429 concerns indexed class-array member lvalues/receivers; #484 concerns fixed-array element values; #485 concerns transactional variable-size associative pattern values; #734 concerns `string.len()` on a fixed string array; #801 concerns `%p` formatting; #803 concerns readmemh/writememh task arguments. Closed #44 is broad parser-sorry cleanup and does not track associative-array argument semantics. #850 is queue behavior. None duplicates the split key, copy, or argument probes. Search-result noise and exact feature searches (including the 2023 clause wording) are retained here so a crash-specific ticket can be checked against both issue states.
