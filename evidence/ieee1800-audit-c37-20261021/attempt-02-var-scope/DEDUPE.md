# Clause 37 issue deduplication

Before classifying the follow-up probe, searched both open and closed issues in `dsellerbrock/iverilog-uvm` with `gh issue list --state all --limit 1000` and these exact GitHub search phrases:

| Search | Results |
|---|---|
| `"vpiVariables"` | no matching issues |
| `"unused variable VPI"` | no matching issues |
| `"vpiInstance"` | no matching issues |
| `"vpiScope module"` | no matching issues |
| `"vpiModule parent"` | no matching issues |

No existing issue was found for the tested variable-iteration or module-instance relationships. If a result warrants a new issue, the lead will perform its own final dedupe before filing.
