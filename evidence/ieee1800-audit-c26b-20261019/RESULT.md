# Reduced §26.4 module-header import probes

Host: macOS. Commands ran inside `~/codex-supervisor/localrun 180`; each
compiler or simulator invocation had a 20-second timeout. Total runner time
was 0.53 seconds; peak RSS was 26,476,544 bytes.

Toolchain: the same binaries and SHA256 values recorded in
[`§25.3–§25.5 results`](../ieee1800-audit-c25a-20261019/RESULT.md).

Both `-g2017` and `-g2023` gave identical results:

| Probe | Result |
| --- | --- |
| [`r26_hdr_a.sv`](../../tests/1800_audit/c26/r26_hdr_a.sv) | Compiled and ran; output `HA 5a` (header import of a packed typedef) |
| [`r26_hdr_b.sv`](../../tests/1800_audit/c26/r26_hdr_b.sv) | Compiled and ran; output `HB 5a` (qualified packed typedef) |
| [`r26_hdr_c.sv`](../../tests/1800_audit/c26/r26_hdr_c.sv) | Failed: `Net 'a' can not be of type <no_type>` and internal synthesis error for the struct member access |
| [`r26_hdr_d.sv`](../../tests/1800_audit/c26/r26_hdr_d.sv) | Compiled and ran; output `HD 5a` (wildcard header import with parameter port list) |

Raw compiler output, exact arguments, exit codes, and stdout are in
[`results.json`](results.json) and the per-case logs. Probe `c` combines a
header import with an unpacked struct default-kind input port and is not a
valid positive probe. The lead confirmed the packed typedef header-import
forms are legal and pass. The separately valid unpacked-struct variable-port
controls are recorded in `attempt-02/RESULT.md` and `attempt-03/RESULT.md`; they
expose a §23.2.2 gap, not a §26.4 header-import gap.
