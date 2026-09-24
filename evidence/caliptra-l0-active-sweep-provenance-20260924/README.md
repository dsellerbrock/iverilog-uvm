# Active Caliptra L0 diagnostic sweep provenance

At 2026-09-24T15:42:38Z, the active 52-case **diagnostic** run's two copied
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

Repeat after the sweep without changing its active output:

```sh
python3 evidence/caliptra-l0-active-sweep-provenance-20260924/attest.py \
  > evidence/caliptra-l0-active-sweep-provenance-20260924/after-run.json
```

The script exits nonzero if the pinned source is dirty/wrong or either copy has
any unexpected difference. Compare the `toolchain` sections of the two JSON
files for tool replacement or timestamp changes during the sweep.
