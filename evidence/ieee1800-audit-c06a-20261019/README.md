# IEEE 1800 §6.16 string probes — 2026-10-19

The audit lead selected §6.16 (string data type) and supplied four positive probes plus five compile-negative probes. The paired test sources are in tests/1800_audit/c06/. This is a scoped probe set, not a full-clause conformance claim. After reviewing the probes and open/closed issue search results, the lead classified all seven gaps below as new; issues #730–#736 were filed.

## Run

- Command: ~/codex-supervisor/localrun 900 bash evidence/ieee1800-audit-c06a-20261019/run-probes-local.sh
- Host: MacBook-Air.local, Darwin 27.0.0, arm64.
- localrun result: exit 0, 1.34 s, peak RSS 7,716,864 bytes.
- Icarus: 13.0 devel built from current batch source b9441bafbdb0b6b7413c09e0381845e69481391b; iverilog SHA-256 7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0, vvp SHA-256 e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d.
- Editions: -g2017 and -g2023, matching the c08 probe flags. Every compile and simulation had a 60 s Perl alarm.
- Full results: [localrun.out](localrun.out); individual compile/run logs: [results-local/](results-local/); diagnostic values: [diagnostic-values.run.log](diagnostic-values.run.log).
- Initial dedupe results: [dedupe/](dedupe/). Final open-and-closed searches and reviewed adjacent issue bodies: [dedupe2/](dedupe2/).

## Provenance and resource note

The local c08 install recorded in the 2026-10-17 evidence had been retired. The pinned Linux build from the same 9b5fad2 source commit is present under /home/dsell/toolchains/, but the Slurm node was full (20/20 CPUs). My Slurm job 3287 remained pending and was canceled; the small probe was run locally under the active fallback policy. The result above therefore records the current batch compiler, not the older c08 binary. An initial local rerun was archived in attempt-01-metadata-mismatch/ because its printed metadata incorrectly named the pinned c08 toolchain; use only the corrected run listed above.

## Observed results and lead classification

Both editions produced identical outcomes:

- p06_16a_decl_conv: 27 pass, 0 fail.
- p06_16b_index_ops: 24 pass, 0 fail.
- p06_16c_methods: 18 pass, 3 fail (member, member_wr, arr).
- p06_16d_conv: 22 pass, 1 fail (hex_rt).
- Three negative cases were rejected: len(1), nonconstant string replication assigned to integral, and substr(1).
- Two negative cases compiled and generated VVP: implicit integral-to-string assignment and assigning a string to a[0].

The diagnostic run shows class property name prints obj but reports length 8; writing name[0] leaves visible O rather than Obj. Fixed-array strings print the expected contents (a, bb, ccc) but each reports length 1. hextoa(32'hdeadbeef) produces -21524111; atohex("deadbeef") returns the expected 32-bit pattern.

## Follow-up characterization

A second localrun split the failing contexts and checked nearby conversion methods. The full command transcript and per-case logs are in diag2/localrun.out and diag2/A-split/localrun.out.

- A direct class-instance property name has len 8, while its static class property and a local string have the expected lengths 4 and 3. A struct string member also has len 8. Copying the property into a local string yields len 3.
- Class-property getc(1), substr(1,2), compare(), and toupper() return correct values. Index read name[1] aborts VVP with an array_size_ assertion. putc(0,"O") correctly changes obj to Obj, while name[0]="O" replaces the visible string with O. A struct member index write similarly yields X instead of Xyz; a static class string property index write works.
- Fixed unpacked string array elements report len 1 for both constant and variable indices. Their getc, index read, substr, compare, toupper, indexed write, and copy-to-local work. Dynamic-array, associative-array, and queue string lengths work.
- The same hextoa, octtoa, bintoa and itoa outputs were reproduced on a compiler built from fafa49958d71c38e7a0a110f6df90a931e92a4cf, which is contained in origin/main. The current-main history after that commit did not change vvp/class_type.cc, string codegen files, or string-related lines in the changed VVP/elaboration files inspected.
- The accepted implicit assignments produce sensible values: 8'h41 becomes "A", 16'h4142 becomes "AB", assigning "QRS" to a string element stores "S", and assigning the string to a byte stores 83.

The potentially adjacent open issues #429 and #484 were read in full, as were closed #100 and #503; their scopes do not cover these string behaviors. The lead classified seven distinct new gaps and no existing-issue comments were needed:

- #730: signed-magnitude output from `hextoa`, `octtoa`, and `bintoa` for bit-31-set values.
- #731: `len()` on an instance property or struct-member string returns 8.
- #732: string-to-byte and string-element assignments are accepted and truncate silently.
- #733: integral-to-string assignment is accepted without the required cast.
- #734: `len()` on a fixed unpacked string-array element returns 1.
- #735: indexed read of an instance class-property string aborts VVP.
- #736: indexed writes to instance-property and struct-member strings replace the whole string.
