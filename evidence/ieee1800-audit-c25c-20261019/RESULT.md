# §25.9–§25.10 virtual-interface probes

Host: macOS. Commands ran inside `~/codex-supervisor/localrun 240`; each
compile and simulation invocation had a 20-second timeout. Total runner time
was 0.75 seconds; peak RSS was 26,509,312 bytes.

Toolchain: the same binaries and SHA256 values recorded in
[`§25.3–§25.5 results`](../ieee1800-audit-c25a-20261019/RESULT.md).

Both `-g2017` and `-g2023` gave identical results. The positive
[`p25_09a_virtual.sv`](../../tests/1800_audit/c25/p25_09a_virtual.sv)
compiled and ran with output:

```text
NULL_INIT
EQ_OK
GRANT3 at 5
REQ2 1 REQ1 x
ADDR 5a
P16 beef
SWITCH 1
CLK 0
DONE
```

Candidate negative probe outcomes (the lead's final classification is noted):

| Probe | Result |
| --- | --- |
| `null_deref` | Compiled and ran, printing `SURVIVED` after dereferencing a null virtual interface |
| `param_mismatch` | Rejected with an assignment-compatible interface type error citing §25.9 |
| `modport_to_nomodport` | Rejected with an assignment-compatible interface type error citing §25.9 |
| `virtual_port` | Rejected; virtual interface variable cannot be used as a module port, citing §25.9 |
| `virtual_continuous` | Compiled and ran successfully |
| `virtual_sensitivity` | Compiled and ran, but was withdrawn as a negative: procedural event control through a virtual interface is legal and is exercised by the positive task test |
| `modport_hidden_member` | Rejected; member not listed in modport, citing §25.5 |

Raw compiler output, exact arguments, exit codes, and stdout are in
[`results.json`](results.json) and the per-case logs. The audit lead confirmed
that the null dereference violates §25.9 and filed [#815](https://github.com/dsellerbrock/iverilog-uvm/issues/815).
It confirmed the continuous-assignment probe violates §25.9 and filed
[#816](https://github.com/dsellerbrock/iverilog-uvm/issues/816). The
procedural sensitivity probe is legal and was not filed; the positive
`SBusTransactor.wait_for_bus()` test exercises it. `CLK 0` is consistent with
the clocking input's initial sampled value before a posedge. Other negative
probes were rejected as required in the tested cases.
