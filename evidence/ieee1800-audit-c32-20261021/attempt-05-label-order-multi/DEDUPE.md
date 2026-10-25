# Open and closed issue dedupe

Snapshot: `gh issue list -R dsellerbrock/iverilog-uvm --state all --limit 1000 --json number,title,state,body`, 404 issues returned (277 open, 127 closed). The repository currently has 251 open issues labeled `1800-audit`; the older 89-issue handoff count is stale. Search ran over all returned open and closed issues, not only the `1800-audit` label.

| Search | Matches | Assessment |
| --- | --- | --- |
| `INCREMENT` | #45 (closed), #498 (closed), #502 (closed), #633 (open), #718 (open), #793 (open), #824 (open), #856 (open) | DPI, packed/array increment expressions, arguments, array queries, and interface declarations; none concern SDF annotation mode/order. |
| `multiple SDF` | none | No existing report. |
| `sdf_annotate` near `scope` | none | No existing report. |
| `SDF LABEL` | none | No existing report. |
| `specparam` near `annotation` | none | No existing report. |
| Clause references §32.4.3, §32.5, or §32.6 | none | No existing report. |
| Broader SDF/specparam search | #19 (closed), #822 (open), #880 (open), #898 (open), #899 (open) | #19 covers specparam constants and specify path declarations, not SDF LABEL annotation. #822 covers a specparam declaration inside a generate block. #880 covers PATHPULSE; #898 covers TIMINGCHECK; #899 covers optional `$sdf_annotate` arguments. All are distinct. |

The existing Clause 32 issues do not cover the three probed rules. If the final run confirms a gap, it is not a duplicate of #880, #898, or #899.
