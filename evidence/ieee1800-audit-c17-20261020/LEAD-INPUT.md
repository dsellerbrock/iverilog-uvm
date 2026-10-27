Resume the active M7 IEEE 1800 audit. You classify Supported/Partial/Missing and file only novel gaps; A3 runs probes. Require paired-edition evidence and open+closed dedupe for every new issue; keep exactly one matrix row per issue.

The current sweep has 133 audit issue records created today (131 open findings, 2 closed duplicate filings), latest #866. Current matrix is `docs/conformance/matrices/ieee1800_status.md`.

Pending from the prior checkpoint: §35.5.6.1 / Annex H.7.4 and H.7.8 string and unpacked-structure DPI open arrays are skipped in both editions; probes and all-state dedupe are in `evidence/ieee1800-audit-c35d-20261020/`.

New runner evidence: §17.3 procedural checker instance. `-g2017` and `-g2023` reject a checker instantiation in a module `initial` procedure, while the static checker control passes in both. Standard text calls this a procedural checker instance (2017 p.487, 2023 p.506); open+closed searches for `procedural checker`, `checker instantiation`, and `checker in procedure` found no issues. Full brief and logs: `evidence/ieee1800-audit-c17-20261020/attempt-01-procedural-checker/`.

Please classify both pending candidates, file only unique gaps, then choose the next probe in the established scope order.
