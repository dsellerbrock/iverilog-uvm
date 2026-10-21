# Open and closed issue dedupe: Clause 23.11 bind forms

The snapshot [`dedupe-all-issues.json`](dedupe-all-issues.json) contains all 424 repository issues fetched after the probes: 297 open and 127 closed. Searched titles and bodies in both states for `bind`, `23.11`, `bind instance list`, `bind interface`, `bind parameter`, `bound module`, and `bind_target`.

The broad `bind` search found 21 issues, but none concerns the Clause 23.11 bind directive forms tested here. Nearest results are distinct:

- #918 (open) concerns binding a named property as an assertion consequent, not the `bind` directive.
- #896 (open) concerns elaboration of a cross-clock sequence `.matched` expression; it does not test bind targets.
- #873 (open) concerns a local-variable initializer in a property or sequence.
- #44 (closed) and #19 (closed) are broad historical parser/language milestones; neither records the target forms or interface-target restriction probed here.
- #475 (closed) concerns assertion-local declaration types, not bind instantiation or target scope.

The scoped searches for `23.11`, `bind instance list`, `bind interface`, `bind parameter`, `bound module`, and `bind_target` had no matches. No duplicate or novel gap was identified by the runner; final classification is pending the audit lead's 2023 wording check.
