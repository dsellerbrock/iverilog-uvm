# Clause 15.5 current-main parser and runtime reducers

- Host: macOS localrun; source: clean `origin/main` at `c41e504c7ee64a7bfc047f8662d3bc8044f1d90f`.
- Command: `~/codex-supervisor/localrun 180 evidence/ieee1800-audit-c15a-20261020/attempt-07-current-main-reducers/run-local.sh`
- Result: localrun exit 0; 1.36 s; peak RSS 16,973,824 bytes.
- Toolchain hashes: see `toolchain.sha256`.
- Both `-g2017` and `-g2023`: implicit-direction and explicit-`input` event task formals each failed parsing at the formal declaration; valid in-order `wait_order` printed `RESULT result=1`; out-of-order `wait_order` emitted `ERROR: ... wait_order events triggered out of order` and then continued to print `SURVIVED`.
- IEEE 1800-2017 §15.5.3 (p. 360) and 1800-2023 §15.5.3 (p. 378) include `task trigger(event ev); -> ev; endtask` as an event-argument example; the compiler rejects this form in both editions.
- IEEE 1800-2017 §15.5.4 (pp. 361–362) and 1800-2023 §15.5.4 (pp. 379–380) specify that an explicit `else` fail statement executes without generating an error. The probe's `else` executes, but the simulator also emits `ERROR`.
- Probe observations are recorded for audit-lead classification and issue filing; no new issue has been filed yet.
