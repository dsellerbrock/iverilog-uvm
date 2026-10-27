# Reduced §25 wildcard interface-port probes

Host: macOS. Commands ran inside `~/codex-supervisor/localrun 180`; each
compile and simulation invocation had a 20-second timeout. Total runner time
was 0.41 seconds; peak RSS was 26,279,936 bytes.

Toolchain: the same binaries and SHA256 values recorded in
[`§25.3–§25.5 results`](../ieee1800-audit-c25a-20261019/RESULT.md).

Both `-g2017` and `-g2023` produced identical results:

| Probe | Result |
| --- | --- |
| [`r25_wc_a.sv`](../../tests/1800_audit/c25/r25_wc_a.sv) | Compile rejected: `.*` did not find a matching identifier for interface port `sb_intf`; this is the standard's simple interface-instance example with an additional `clk` port. |
| [`r25_wc_b.sv`](../../tests/1800_audit/c25/r25_wc_b.sv) | Compile rejected with the same missing matching identifier for `sb_intf`; the interface has a connected `clk` port. |
| [`r25_wc_c.sv`](../../tests/1800_audit/c25/r25_wc_c.sv) | Compile and run passed; output was exactly `C req=1` using shorthand `.sb_intf`. |

Raw commands, exit codes, diagnostics, and stdout are in [`results.json`](results.json)
and the per-case logs. The audit lead verified the standard example and
open/closed dedupe, then filed [#814](https://github.com/dsellerbrock/iverilog-uvm/issues/814).
