# UVM DPI follow-up

This local rerun used the pinned sv-tests corpus (`c4229f3`) and UVM source (`656f20d`) with Icarus source commit `db458c438eca253fb1b3110f671fe3800e33b7a0`. It loaded the `uvm_dpi.vpi` module using `-M<module-dir> -muvm_dpi` for all 37 cases previously classified `ACCEPTANCE_ONLY` because the original run omitted the module.

The run compiled and executed all 37 cases: 0 compile failures, 0 nonzero runtime exits, 0 timeouts, and 0 missing-DPI-symbol logs. The sv-tests log parser accepted 34 cases. Three assertion markers were reported:

| Test | Finding |
| --- | --- |
| `chapter-16/16.2--assert-final-uvm.sv` | Its `assert final` expression is processed immediately after `m_if.a <= a` schedules a nonblocking update. At that point the interface signal is still uninitialized, so the comparison is unknown and the test's `$error` action fires. IEEE 1800-2023 §16.4 says “a deferred assertion’s expression is evaluated at the time the deferred assertion statement is processed”; only its reporting action is deferred. This is a test-oracle error, not a simulator feature gap. |
| `chapter-16/16.2--assert0-uvm.sv` | Same nonblocking-assignment sampling issue for `assert #0`; the test expects the expression itself to be evaluated after the update. IEEE 1800-2023 §16.4 specifies that it is evaluated when processed. |
| `chapter-16/16.7--sequence-and-uvm.sv` | The log emits `seq failed`; the pinned source itself comments that this assertion fails on all tested simulators. |

The focused rerun therefore found no confirmed simulator defect in the UVM group. It resolves the missing-DPI setup gap while exposing three test-oracle outcomes that the original acceptance-only class could not show. The 1,022/1,027 full-suite runner result remains unchanged because this was a focused rerun under the same compile/run requirements for these 37 entries, not a replacement full-suite aggregate.

`summary.json` and `summary.log` contain the per-case results. `raw-logs.tar.gz` retains each case's compile and run log; its SHA-256 is in the adjacent checksum file. `environment.txt` records toolchain versions and binary hashes, and `run-result.txt` records the localrun command, exit code, elapsed time, and peak RSS.
