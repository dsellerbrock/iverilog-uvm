# Superseded invalid queue-read test design

Job 3561 on the pinned compiler compiled the initial probe under both
`-g2017` and `-g2023`. It printed `OOB_INT 0` in each edition and stopped at
the test's assertion expecting X. IEEE 1800 §6.11 says `int` is 2-state, so
Table 7-1 correctly requires zero. The expectation was wrong; this is not a
simulator conformance failure. Raw outputs, input copy, and tool hashes are
preserved in [`remote-3561/`](remote-3561/).
