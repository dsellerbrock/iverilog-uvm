# Clause 40.5 issue dedupe

Searched all issues (open and closed) in `dsellerbrock/iverilog-uvm` on 2026-10-21. The direct issue searches were `"vpiCoverageStart"`, `"vpiCoverageCheck"`, `"coverage VPI"`, `"40.5"`, `"coverage control"`, `"toggle coverage"`, and `"code coverage" "VPI"`. A separate scan of all 239 issues carrying the `1800-audit` label checked the exact terms `vpiCoverageStart`, `vpiCoverageCheck`, `coverage VPI`, `40.5`, `toggle coverage`, and `code coverage` in titles and bodies.

- `"vpiCoverageStart"` and `"vpiCoverageCheck"` return #883, which is the Annex M assertion-constant mismatch; the issue does not cover Annex K coverage controls or runtime behavior.
- `"coverage VPI"` returns #443, which is the §16 deferred-cover accounting/database follow-up. Its scope is deferred-cover accounting, not the §40.5 code-coverage VPI controls probed here.
- `"40.5"`, `"coverage control"`, `"toggle coverage"`, `"code coverage" "VPI"`, and the audit-label scan return no directly matching issue.

No existing issue covers the tested §40.5 unavailable-coverage behavior. Whether the observed VPI diagnostics/results constitute a gap is pending the lead's classification.
