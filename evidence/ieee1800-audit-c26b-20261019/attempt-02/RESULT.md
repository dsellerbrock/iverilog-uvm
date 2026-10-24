# Unpacked-struct port controls for §26.4

Host: macOS. Commands ran inside `~/codex-supervisor/localrun 180`; each
compiler or simulation invocation had a 20-second timeout. Total runner time
was 0.37 seconds; peak RSS was 26,427,392 bytes.

Both `-g2017` and `-g2023` gave identical results:

| Probe | Result |
| --- | --- |
| [`r26_st_e.sv`](../../../tests/1800_audit/c26/r26_st_e.sv) | Rejected: `Net 'a' can not be of type <no_type>` and internal synthesis error |
| [`r26_st_f.sv`](../../../tests/1800_audit/c26/r26_st_f.sv) | Rejected with the same error |
| [`r26_st_g.sv`](../../../tests/1800_audit/c26/r26_st_g.sv) | Compiled and ran; output `SG 5a` (packed struct port through a header import) |
| [`r26_st_h.sv`](../../../tests/1800_audit/c26/r26_st_h.sv) | Rejected: `Port 'a' ... with type <no_type> is not supported`, then internal synthesis error, despite explicit `input var` |

Raw compiler output, exact arguments, exit codes, and stdout are in
[`results.json`](results.json) and the per-case logs. The lead confirmed `e`
and `f` are invalid default-kind input nets, `g` is a passing packed-struct
header import, and `h` is a valid variable port. `h` is rejected under §23.2.2
and is covered by [#818](https://github.com/dsellerbrock/iverilog-uvm/issues/818).
