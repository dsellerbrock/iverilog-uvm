# IEEE 1800-2017/2023 §6.24 audit

Probe evidence for the lead-selected §6.24.1–§6.24.3 casting slice. These
results cover only the cases named below; they do not claim complete
§6.24 conformance.

## Environment

- Host: MacBook Air, Darwin 27.0, arm64.
- Probe tree commit: 27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e.
- Icarus toolchain source: b9441bafbdb0b6b7413c09e0381845e69481391b.
- Icarus: 13.0 devel; iverilog SHA-256 7ce507279ef15cb404b9ce70ba47902c4264daebffaf1b340bfb351adcc9c2b0.
- vvp SHA-256 e74cb1b690dc2ff07c928684df0df302d053bd94ff4a4a30bf8e10adb7da0b1d.
- Each compile/run was individually limited to 60 seconds with
  scripts/run_with_timeout.py; the enclosing job used
  ~/codex-supervisor/localrun. No Slurm jobs were submitted for these small
  probes.

## §6.24.1 — static casts

2017 §6.24.1 pp.132–133; 2023 §6.24.1 p.139 onward. The lead found the tested
rules identical across editions.

tests/1800_audit/c06/p06_24a_static_cast.sv passes all 17 assertions under
-g2017 and -g2023 (RESULT pass=17 fail=0). It covers signed/unsigned casts,
integral/real casts and rounding, concatenation casts, narrowing, size casts
from an expression and parameter, truncation, sign/zero extension, 4-state
preservation, and enum casts without a range check.

Command: ~/codex-supervisor/localrun 180 bash evidence/ieee1800-audit-c06c-20261019/run-p06-24a.sh.
Wall time 0.69 s; peak RSS 16,891,904 bytes.

Not covered: const'(x) and the shortreal bit-pattern note.

## §6.24.2 — $cast

2017 §6.24.2 p.134; 2023 §6.24.2 p.141.

### Function form

tests/1800_audit/c06/p06_24b_dyn_cast.sv passes 10 assertions in both
editions. It checks valid/invalid enum assignments and unchanged destination,
real-to-int, string, byte and X/Z enum cases. A separate ordinary assignment
control, tests/1800_audit/c06/r06_24b_real_assign_control.sv, prints
CONTROL rv=7.000000 in both editions.

The reduced repro tests/1800_audit/c06/r06_24b_real_cast_isolate.sv first
casts 3.7 to an integer successfully, then $cast(real_dest, 7) aborts in both
editions with Format 9 not implemented for putting real values, assertion
failure in real_from_vpi_value (vpi_priv.cc:1067), exit 250. The direct
real rv; rv=7; control succeeds.

### Task form and nonsingular arguments

tests/1800_audit/c06/p06_24e_task_invalid.sv shows invalid enum task-form
casts silently leave the destination unchanged in both editions, print no
runtime error, and continue to the valid call.

tests/1800_audit/c06/p06_24f_nonsingular.sv is accepted in both editions;
the function form returns 1 while leaving the unpacked array unchanged, and
the task form is silent. The expected rule differs: 2017 requires a
compile-time singular-argument check; 2023 accepts compilation but the
function form must return 0 for the invalid nonsingular assignment, while
task form must report a runtime error.

Canonical issues:

- #741 — real destination abort: https://github.com/dsellerbrock/iverilog-uvm/issues/741
- #742 — invalid task form omits runtime error: https://github.com/dsellerbrock/iverilog-uvm/issues/742
- #743 — nonsingular destination returns success without assignment: https://github.com/dsellerbrock/iverilog-uvm/issues/743

Repeated filings #744 and #745 were verified byte-for-byte duplicates of
#742 and #743, commented and closed; #742/#743 remain canonical.

## §6.24.3 — bit-stream casts

2017 §6.24.3 pp.135–137; 2023 §6.24.3 pp.142–144.

### Combined probe

The first probe tests/1800_audit/c06/p06_24c_bitstream.sv did not compile in
either edition. It reported clean “not yet implemented” diagnostics for
packed/unpacked struct casts, dynamic-struct-to-queue casts, and queue-to-string
casts, plus Array ba needs an array index here for an unpacked-array source.
It was split so one unsupported case could not hide the rest.

### Split probe results

| Probe | 2017 | 2023 |
| --- | --- | --- |
| r06_24c_s2p.sv | Compiles, warns fallback, prints 0000 (expected 1234) | Same |
| r06_24c_p2s.sv | Rejected: bit-stream cast to unpacked struct not implemented | Same |
| r06_24c_p2ua.sv | Rejected: bit-stream cast to unpacked array not implemented | Same |
| r06_24c_ua2p.sv | Rejected: array source requires an index | Same |
| r06_24c_q2str.sv | Rejected: bit-stream cast to string not implemented | Same |
| r06_24c_str2q.sv | Compiles, prints queue size 8 and zero elements (expected 2, 65, 66) | Same |
| r06_24c_da.sv | Dynamic-array/integral round trip passes | Same |
| r06_24c_s2q.sv | Compiles, prints all zeros (expected packet bytes) | Same |
| r06_24c_q2s.sv | Rejected: bit-stream cast to unpacked struct not implemented | Same |

Negative probes n06_24_{struct24_to_int,int_to_struct33,assoc_dest,size_zero,size_neg}.sv
run in both editions. The 24-to-32 struct cast is incorrectly accepted;
33-bit source to struct, associative destination, and zero/negative size
casts are rejected. The Array x needs an array index here diagnostic on the
associative case is a compile rejection.

The lead classified the five issue groups below as distinct gaps. Open-and-closed
issue searches covered all six proposed terms, the BLOCKERS entry, and prior
related issue bodies; #474, #728, and #97 were reviewed and excluded after their
bodies/comments contained no 6.24 cast references.

- [#746 — struct destination](https://github.com/dsellerbrock/iverilog-uvm/issues/746)
- [#747 — fixed unpacked array source/destination](https://github.com/dsellerbrock/iverilog-uvm/issues/747)
- [#748 — queue to string destination](https://github.com/dsellerbrock/iverilog-uvm/issues/748)
- [#749 — struct/string source yields fabricated values](https://github.com/dsellerbrock/iverilog-uvm/issues/749)
- [#750 — mismatched struct-to-int size accepted](https://github.com/dsellerbrock/iverilog-uvm/issues/750)

The broad open search for “6.24.3” indexed #746–#749; an exact “struct-to-int
cast with a size mismatch” search returned #750. Five targeted open searches
found each of #746–#750 exactly once. Search output is in
dedupe/created-issues-verification.txt. Full commands, compile/run logs, and
dedupe search JSON are in this directory.

The split batch used
~/codex-supervisor/localrun 900 bash evidence/ieee1800-audit-c06c-20261019/run-p06-24c-split.sh,
ran for 34.57 s, and reported peak RSS 4,244,013,056 bytes (about 3.95 GiB).
evidence/ieee1800-audit-c06c-20261019/dedupe/ contains all-state searches.
