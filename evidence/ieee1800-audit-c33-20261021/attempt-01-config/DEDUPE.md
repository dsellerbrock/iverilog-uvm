# §33 configuration issue dedupe

Repository: `dsellerbrock/iverilog-uvm`. Before filing, searched open and closed issues on 2026-10-21 with `gh issue list -R dsellerbrock/iverilog-uvm --state all --limit 1000 --search '<term>' --json number,title,state` for `"config"`, `"configuration"`, `"liblist"`, and `"33."`.

| Search | Matches | Disposition |
| --- | --- | --- |
| `"config"` | OPEN: none. CLOSED: #672, #664, #44, #5, #27. | All closed matches concern unrelated class, parser, or virtual-interface behavior. |
| `"configuration"` | OPEN: #671, #670. CLOSED: #672, #664. | All concern unrelated Caliptra issues. |
| `"liblist"` | none | No existing issue. |
| `"33."` | OPEN: #750, #622. | Broad text/number matches are unrelated to Clause 33. |

Before the new report, no open or closed issue covered SystemVerilog `config`, `default liblist`, or `instance … use` binding. After tech lead filed #881 from the probe, the same four open+closed searches were rerun:

| Search | Refreshed matches | Disposition |
| --- | --- | --- |
| `"config"` | OPEN: #881. CLOSED: #672, #664, #44, #5, #27. | #881 is this finding; other closed matches remain unrelated. |
| `"configuration"` | OPEN: #881, #671, #670. CLOSED: #672, #664. | #881 is this finding; #671/#670 and closed matches are unrelated Caliptra reports. |
| `"liblist"` | OPEN: #881. | #881 is this finding. |
| `"33."` | OPEN: #881, #750, #622. | #881 is this finding; #750 and #622 concern §§6 and 19. |

Pre-file searches establish the dedupe; refreshed searches establish that the submitted issue is now the sole relevant Clause 33 report.
