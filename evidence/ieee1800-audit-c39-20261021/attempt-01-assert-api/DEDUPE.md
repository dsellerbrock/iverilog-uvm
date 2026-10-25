# Open and closed issue dedupe (pre-file search)

Repository: `dsellerbrock/iverilog-uvm`; searched 2026-10-21 with `gh issue list --state all --limit 1000 --search <term>`.

| Search term | Results | Relevance |
|---|---|---|
| `vpiAssertion` | none | — |
| `vpi_register_assertion_cb` | none | — |
| `cbAssertionFailure` | none | — |
| `vpiAssertionDisable` | none | — |
| `39.` | #27 CLOSED | Broad textual match for an unrelated OpenTitan runtime-stub request. |
| `"vpiAssertion" "744"` | #744 CLOSED | Search token `744` matched the unrelated issue number; no assertion/VPI relation. |
| `"VPI assertion"` | none | — |
| `"assertion control" VPI` | none | — |
| `"assertion API"` | none | — |

No existing issue found for the tested assertion enumeration, callback, disable-control, or Annex M constant behavior. Repeat the open+closed search after the lead files any issue.

## Post-file and Annex K/M comparison search (2026-10-21)

All searches used `gh issue list -R dsellerbrock/iverilog-uvm --state all --limit 100 --json number,title,state,url --search <term>`; they include open and closed issues.

| Search term | Results | Relevance |
|---|---|---|
| `"vpi_user.h"` | #883 OPEN, #884 OPEN, #502 CLOSED | #883 is the Annex M assertion-constant gap; #884 is runtime assertion control. #502 is the unrelated fixed-array increment bug. |
| `"sv_vpi_user.h"` | #883 OPEN, #884 OPEN, #502 CLOSED | #883 is the exact header issue; #884 is runtime control; #502 is unrelated. |
| `"Annex K"` | #883 OPEN, #884 OPEN | The issues contained the earlier K/M naming error; #883 title and correction comments on both issues now identify Annex M correctly. |
| `"Annex M"` | #883 OPEN, #884 OPEN | Existing assertion issues only; no Annex K header-coverage issue. |
| `"VPI constant"` | none | No existing matching issue. |
| `"vpiAlways"`, `"cbAssign"`, `"vpiWidth"` | none | No existing matching issue for representative missing Annex K names. |
| `"standard VPI header"`, `"missing VPI constants"` | none | No existing broad header-coverage issue. |
| `"vpiModport"` | none | No existing issue for the second Annex M value mismatch. |
| `"vpiAssertionDisable"` | #884 OPEN, #883 OPEN | Existing disable-control issue and related header issue. |

The Annex K missing-name finding has no matching open or closed issue in these searches. #883 and #884 were corrected by issue comments: Annex K is `vpi_user.h`; Annex M is `sv_vpi_user.h`. The full Annex M comparison table was posted to [#883](https://github.com/dsellerbrock/iverilog-uvm/issues/883#issuecomment-6311027142) after the follow-up comparison was completed.
