# Open and closed issue dedupe (pre-file search)

Repository: `dsellerbrock/iverilog-uvm`; searched 2026-10-21 with `gh issue list --state all --limit 1000 --search <term>` so both open and closed issues were included.

| Search term | Results | Relevance |
|---|---|---|
| `vpi_put_value` | #27 CLOSED | OpenTitan runtime-stub request; not the §38.34 no-delay API behavior. |
| `cbValueChange` | none | — |
| `vpi_iterate` | none | — |
| `vpi_register_systf` | none | — |
| `vpi_get_vlog_info` | none | — |
| `VPI` | #795 OPEN, #741 OPEN, #443 OPEN, #445 OPEN, #684 OPEN, #712 OPEN, #501 CLOSED, #502 CLOSED, #448 CLOSED, #536 CLOSED, #444 CLOSED, #664 CLOSED, #434 CLOSED, #439 CLOSED, #470 CLOSED, #27 CLOSED, #11 CLOSED, #44 CLOSED, #29 CLOSED | Reviewed matches: #443/#445 concern deferred-assertion information exposed through VPI; #501 is VPI source-location reporting; #27 and #29 mention unrelated VPI runtime/sensitivity behavior. Others are unrelated uses or broad text matches. |
| `"VPI" "system task"` | none | — |
| `"VPI callback"` | #501 CLOSED, #536 CLOSED | Neither tracks the basic §38 callback contract probed here. |
| `"vpi_register_cb"` | none | — |
| `"vpi_get_value"` | #795 OPEN, #29 CLOSED | #795 is a §20.9 `$countbits` runtime crash involving VPI stack access; #29 is wait-loop sensitivity. Neither covers this basic API path. |
| `"cbValueChange"` | none | — |
| `"vpiNet"` | none | — |
| `"vpi_register_systf"` | none | — |

No existing issue found that covers the exact tested behavior. If the probe reveals a gap, search results are a pre-file snapshot; repeat the search after the lead files it and record the new issue as the sole exact match.
