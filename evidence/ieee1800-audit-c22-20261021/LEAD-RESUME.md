# 1800-audit lead resume

Goal: classify probe evidence and file only deduped `1800-audit` issues in `dsellerbrock/iverilog-uvm`; the runner supplies probes and raw results.

Current matrix: `docs/conformance/matrices/ieee1800_status.md`. All 41 top-level clauses are inventoried; child rows record scoped probe results, and missing coverage remains unassessed.

Live GitHub state: 220 open issues labeled `1800-audit` (the prior 89-issue snapshot is stale). Open issue number ranges: #608–617, #619–628, #630, #632–638, #642–655, #659, #675, #677–678, #681–682, #684–689, #691–692, #695–696, #698–728, #730–743, #746–796, #798–826, #829–833, #835–866. Re-query and search open plus closed issues before filing.

New probe evidence awaiting your classification:
- §22.12: `fileline2.v` passes the golden in both `-g2017` and `-g2023`; Slurm job 3604.
- §22.14: the standard-listed 1800-2017 and 1800-2023 specifiers are warned/ignored; unknown 1800-9999 is accepted instead of errored; an unpaired `begin_keywords` is accepted in `-g2023` despite the 2023-only pairing rule. Slurm job 3604; open/closed searches found no matching issue.
- §24.3.1 and §24.3.2: program region scheduling and program-port reactive-to-active loopback probes pass in both editions; Slurm jobs 3603 and 3605.

Probe results and raw logs: `evidence/ieee1800-audit-c22-20261021/attempt-02-paired-editions/RESULT.md`, `evidence/ieee1800-audit-c24-20261021/attempt-01-program-reactive/RESULT.md`, and `evidence/ieee1800-audit-c24-20261021/attempt-02-program-ports/RESULT.md`. Matrix rows are lead-pending. No new issues have been filed by the runner.

Please classify each result, split distinct §22.14 gaps if warranted, create one issue-linked matrix row per issue filed, and select the next clause/subclause from the standards.
