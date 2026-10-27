# IEEE 1800 §15.4 mailbox probes

Paired 2017/2023 probes cover bounded and default-unbounded construction,
`num()`, FIFO message and waiter order, blocking `put()`/`get()` wakeups,
`try_put()`/`try_get()`/`peek()`/`try_peek()`, multiple waiters released by a
single message, typeless run-time mismatch returns, and compile-time type
checking for `mailbox #(int)`. A separate 2023 probe checks the explicit
§15.4.4 rule that an unbounded mailbox is never full, so `try_put()` succeeds.

Standards: IEEE 1800-2017 §15.4.1–§15.4.9, pp. 355–358; IEEE 1800-2023
§15.4.1–§15.4.9, pp. 374–377. Negative `new(bound)` is deliberately not
classified: the standard says it is illegal but permits indeterminate behavior
and only says implementations may warn.

The source worktree is `m7-1800-audit-c08` at `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`
with other audit work in progress. The frozen four-probe input archive and
Slurm script are stored beside this file. Toolchain: `/home/dsell/toolchains/iverilog-uvm-m18-main-cae035642e056644274a01e98d4422ce286685b4/bin`.
Each compile and simulation has a 90-second timeout. Slurm request: 1 CPU,
2 GiB, 20 minutes.

Slurm job `3103` completed in 1 second on DAN-DESKTOP with exit 1; accounting
storage is disabled, so peak RSS is unavailable. The core operational test
passed in both editions, as did the 2017/2023 typed-mailbox compile rejection
and the 2023 unbounded `try_put` probe. The default typeless mailbox test
failed in both editions: mismatched `try_peek` and `try_get` were not reported
as negative returns, and the mismatched `try_get` removed the message. See
[`remote-job-3103/results.txt`](remote-job-3103/results.txt) and its per-test
logs. The input archive SHA-256 is
`fc0d102c7cdd5d3dea83942d11890c312c681b2e0751f8cad77eb890cf45c621`.
