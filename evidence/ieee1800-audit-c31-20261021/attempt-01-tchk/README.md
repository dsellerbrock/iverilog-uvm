# IEEE 1800 Clause 31 timing-check probe

The audit lead assigned paired probes for `$setup`, `$hold`, `$width`, notifier transitions, and violation reports. Icarus ignores timing checks unless invoked with `-gspecify`; only those runs measure IEEE behavior. Default-mode runs are recorded as tool-mode observations, not conformance gaps.

## Standard requirements

The provisions are the same in IEEE 1800-2017 and IEEE 1800-2023:

- §31.3.1 `$setup`: the window begins at `timecheck_time - limit` and ends at `timecheck_time`; a violation occurs only when `beginning < timestamp_time < end`, so neither endpoint is included. The standard says: “The end points of the time window are not part of the violation region.” Printed pages 866 (2017) and 898 (2023).
- §31.3.2 `$hold`: the window begins at `timestamp_time` and ends at `timestamp_time + limit`; a violation occurs when `beginning <= timecheck_time < end`, so the beginning is included and the end is excluded. Printed pages 867 (2017) and 899 (2023).
- §31.4.4 `$width`: a violation occurs when `threshold < (timecheck_time - timestamp_time) < limit`; both ends are excluded. With threshold 0, limit 4, and pulse width 2, a violation is required. Printed pages 879 (2017) and 911 (2023).
- §31.3 requires a timing violation to be reported when a data event occurs within the defined time window. §31.6/Table 31-13 gives notifier responses: x becomes either 0 or 1; 0 toggles to 1; 1 toggles to 0; z remains z. Printed pages 883 (2017) and 915 (2023).

The stimulus causes `$setup` at t10 (data event t9: inside [t7,t10)), `$hold` at t11 (data event inside [t10,t12)), and `$width` at t22 (pulse width 2 is inside (0,4)). Starting notifier 0 should produce 0→1→0→1 and `N 3 1`.

Probe: [`p31_tchk.sv`](../../../../tests/1800_audit/c31/p31_tchk.sv). Open+closed issue dedupe is in [`DEDUPE.md`](DEDUPE.md), and raw results are in [`RESULT.md`](RESULT.md).
