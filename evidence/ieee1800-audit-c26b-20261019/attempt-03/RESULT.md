# §26/§23 package-struct port controls

Host: macOS. Commands ran inside `~/codex-supervisor/localrun 240`; each
compiler or simulator invocation had a 20-second timeout. Total runner time
was 0.46 seconds; peak RSS was 26,378,240 bytes.

Both `-g2017` and `-g2023` results were identical:

| Probe | Result |
| --- | --- |
| [`r26_vp_a.sv`](../../../tests/1800_audit/c26/r26_vp_a.sv) | Rejected: unpacked-struct `input var` has unsupported `<no_type>` port and internal synthesis error |
| [`r26_vp_b.sv`](../../../tests/1800_audit/c26/r26_vp_b.sv) | Same rejection for package-qualified unpacked struct input `var` |
| [`r26_vp_c.sv`](../../../tests/1800_audit/c26/r26_vp_c.sv) | Rejected: unpacked-struct input with 4-state member has unsupported net type and internal synthesis error |
| [`r26_vp_d.sv`](../../../tests/1800_audit/c26/r26_vp_d.sv) | Rejected: unpacked-struct input `var` without an output is unsupported |
| [`r26_vp_e.sv`](../../../tests/1800_audit/c26/r26_vp_e.sv) | Rejected: unpacked-struct output `var` is unsupported |
| [`r26_st_h.sv`](../../../tests/1800_audit/c26/r26_st_h.sv) | Same rejection for unpacked-struct input `var` with package header import |
| [`r26_vp_f.sv`](../../../tests/1800_audit/c26/r26_vp_f.sv) | Accepted; input `bit [7:0]` port compiled without diagnostics |

Raw compiler output, exact arguments, exit codes, and stdout are in
[`results.json`](results.json) and the per-case logs. The lead filed
[#818](https://github.com/dsellerbrock/iverilog-uvm/issues/818) for rejection
of legal unpacked-struct net and variable ports after open/closed dedupe. It
filed [#819](https://github.com/dsellerbrock/iverilog-uvm/issues/819) for
accepting the two-state `bit` input net after dedupe. Probe `f` is the only
case accepted in this attempt.
