# §26 package probes

Host: macOS. Commands ran inside `~/codex-supervisor/localrun 300`; each
compiler or simulator invocation had a 20-second timeout. Total runner time
was 1.62 seconds; peak RSS was 26,673,152 bytes.

Toolchain: the same binaries and SHA256 values recorded in
[`§25.3–§25.5 results`](../ieee1800-audit-c25a-20261019/RESULT.md).

Both `-g2017` and `-g2023` gave identical results. Eight of nine positive
package probes compiled and ran with their expected output:

| Probe | Output |
| --- | --- |
| `p_explicit` | `P1 1` |
| `p_qualified` | `P2 1` |
| `p_wild_bind` | `P3 1 2` |
| `p_func_local` | `P4 2` |
| `p_func_wild` | `P5 1` |
| `p_export` | `P7 5 5` |
| `p_varinit` | `P8 7` |
| `p_complex` | `P9 4 6` |

[`p_header.sv`](../../tests/1800_audit/c26/p_header.sv) failed at an imported
struct input, but the lead determined this was an unpacked struct with the
default net kind and was not a legal positive probe. Separate reduced probes
confirm packed typedef header imports compile and run.

Of eleven negative candidates, ten were rejected in both editions. The
exception [`n26_unit_ref.sv`](../../tests/1800_audit/c26/neg/n26_unit_ref.sv)
was accepted without diagnostics, violating §26.2; the lead filed
[#817](https://github.com/dsellerbrock/iverilog-uvm/issues/817) after
open/closed dedupe. The `implicit_net` candidate was validly rejected at parse
time; the other rejected cases conformed in the tested subset.

Raw compiler output, exact arguments, exit codes and stdout are in
[`results.json`](results.json) and the per-case logs. The first attempt had a
source-generation error (literal `\\n` appended to each source); it was
corrected before this recorded run and is not a simulator result.
