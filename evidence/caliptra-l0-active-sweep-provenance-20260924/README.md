# Preliminary Caliptra L0 diagnostic sweep provenance

At 2026-09-24T15:42:38Z, the preliminary 52-case **diagnostic** run's two copied
firmware source roots each matched the pinned Caliptra v2.1.2 tree recursively
except for its one named compatibility patch. The comparison covered 5,139
non-`.git` entries per tree, including file contents and modes, symlink targets,
and directory structure. `smoke_test_hw_config` changed only `caliptra_isr.h`;
`smoke_test_hmac_errortrigger` changed only its test C file. Both copied-file
hashes match the frozen runner expectations. The pinned Caliptra checkout was
clean at `49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e`.

[`during-run.json`](during-run.json) records the SHA-256, resolved path, size,
and nanosecond mtime of the xPack GCC 15.2 executables observed in the first
firmware build log (`gcc`, `cpp`, `as`, `objcopy`, `objdump`, `size`) plus the
GCC-reported `cc1`, `collect2`, assembler, and linker programs. These are
provenance checks, not an L0 pass or IEEE conformance result.

The sequential run was stopped after a completed first case and during its
second case to prepare a separate bounded-parallel profile with an ephemeral
JTAG listener port. Its partial output is not a 52-case result. A read-only
repeat produced [`after-run.json`](after-run.json); the two copied trees,
toolchain records, pinned source, and script hash matched `during-run.json` at
that checkpoint. The script has since gained an optional parallel-output check.

Repeat the read-only check without changing the preserved output:

```sh
python3 evidence/caliptra-l0-active-sweep-provenance-20260924/attest.py \
  > evidence/caliptra-l0-active-sweep-provenance-20260924/after-run.json
```

The script exits nonzero if the pinned source is dirty/wrong or either copy has
any unexpected difference. Compare the `toolchain` sections of the two JSON
files for tool replacement or timestamp changes during the sweep.

After the parallel 52-case run completes, pass its output path with `--run` to
check the two named copied firmware roots against all 5,139 pinned entries and
verify every temporary JTAG top and compile filelist differs only by the
requested port-0 substitution. The script also checks each named result points
to its own copy. Its focused `test_attest.py` accepts the exact copied top and
rejects a tampered one. The old snapshots remain specific to the stopped
sequential run.

The later three-job, 14,400-second-per-case diagnostic wrapper was stopped
after four completed cases because three long cases failed on the unchanged
`ERR_HWIF_IN` assertion and a separate sampled-value probe was needed. Its
[`long52_checkpoint.json`](long52_checkpoint.json) records one completed pass,
three completed failures, two already-launched cases still running, and 46
not started. The wrapper cannot launch more cases. Every completed per-case
record passed pinned-source and tool-fingerprint checks, but there is no
52-case aggregate. This copied-source `-gcommercial-unsafe` result is
nonstandard compatibility evidence, separate from the pristine and IEEE
lanes.
