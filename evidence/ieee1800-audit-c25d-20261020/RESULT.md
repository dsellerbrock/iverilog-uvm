# §25.7–§25.8 interface subroutine probes

Host: macOS, both `-g2017` and `-g2023`, with each compiler/runtime invocation
capped at 20 seconds under `~/codex-supervisor/localrun`. The full runner took
0.29 seconds and peaked at 17,694,720 bytes RSS; the reducers took 0.19 seconds
and peaked at 17,481,728 bytes RSS.

Toolchain: Icarus build from batch commit
`b9441bafbdb0b6b7413c09e0381845e69481391b`; the same binaries and SHA-256
values recorded in [§25.3–§25.5 results](../ieee1800-audit-c25a-20261019/RESULT.md).

`t_import.sv` compiles and runs in both editions with the expected output:
`MRD 12`, `MWR 34` twice each, `SRD n=111`, then `N 111 11 W16`. This exercises
imported interface tasks and a second parameterized interface instance
(§25.7.1–§25.7.2, §25.8).

`t_export.sv` fails in both editions at `task a.Read` with “`a` has already been
declared in this scope,” previously declared as a net. Reduced generic and
modport-qualified interface-port variants fail at the same task definition,
confirming the module-side export definition gap (§25.7.3). The lead deduped
`extern forkjoin`, `modport export`, and `interface task` in open and closed
issues and filed [#823](https://github.com/dsellerbrock/iverilog-uvm/issues/823).

`t_forkjoin.sv` and its minimal reducer fail in both editions at the
`extern forkjoin` declaration (§25.7.4). The lead deduped and filed
[#824](https://github.com/dsellerbrock/iverilog-uvm/issues/824).

Exact sources, commands, compiler output, stdout, and exit codes are in
[`results.json`](results.json) and [`reducers.json`](reducers.json).
