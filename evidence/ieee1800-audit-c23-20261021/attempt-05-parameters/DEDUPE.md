# Clause 23.10 parameter probe dedupe

Fresh live open+closed GitHub snapshot from 2026-10-21: 431 issues (304 open, 127 closed), saved as `dedupe-all-issues.json` before any new issue from this tranche.

Searched issue titles and bodies for `defparam`, `early resolution`, `23.10`, `named parameter assignment`, `ordered parameter`, `localparam override`, `parameter dependence`, `type parameter override`, `duplicate parameter assignment`, `parameter name assigned`, `cross-generate defparam`, and `class type parameter default`. No issue directly tracks the selected §23.10 behavior. The lone `defparam` hit is open #921 (§25.9), which mentions an external `defparam` only as a control for virtual-interface behavior. There are no direct matches for duplicate named parameter assignments, cross-generate `defparam`, or early hierarchical resolution.

Related issues reviewed and distinct:

- #751 OPEN (§6.20.1/§6.20.3): 2023 `forward_type` syntax on a module type parameter; it does not cover parameter assignment, dependent value parameters, or early hierarchical resolution.
- #766 OPEN (§6.25): specialized class-scoped types; it does not cover module instance parameter redefinition.
- #895 OPEN (§23.5): parameterized `extern module` syntax is rejected; distinct from parameter values and their elaboration.
- #450 CLOSED: associative-array parameter types; #451 CLOSED: restricted class type parameters. Both concern type categories, not §23.10 redefinition semantics.
- #19 CLOSED is a broad language-edge umbrella mentioning type parameters and unrelated features; it has no §23.10 `defparam` or instance-assignment behavior report.
- #474 CLOSED covers array assignment patterns and element reads, not parameter override behavior.
- #642 OPEN reports an internal error for a class static method in a continuous assignment; unrelated to a type-dependent parameter default.
- #921 OPEN mentions an external `defparam` only as a control in a §25.9 virtual-interface issue; it does not track the two §23.10 hierarchy-resolution rules probed here.

The full snapshot includes both open and closed issues; no candidate duplicates the selected rules. Re-evaluate against the probe-specific behavior before filing any issue.

Lead adjudication: #928 (Q2), #929 (Q4b), #930 (Q8), and #931 (Q7b robustness failure) were filed from the paired probes; each represents a distinct check. The pre-filing searches above and reviewed neighboring issues are the dedupe basis.
