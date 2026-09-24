# Caliptra L0 patched diagnostic parallel runner

`run.py` launches the exact 52 names in the pinned `selected_52.txt`, each through
the existing Icarus per-case runner with a separate output directory. It uses at
most four concurrent jobs and the bundled Caliptra BFM. The profile is explicit
`-gcommercial-unsafe` plus the copied reset, checker, and ephemeral JTAG-port
overlays; its results are nonstandard diagnostic compatibility evidence, separate
from the pristine unsafe lane and IEEE conformance.

```sh
python3 evidence/caliptra-icarus-l0-parallel-runner-20260924/run.py \
  --output evidence/caliptra-icarus-l0-patched-long-52-20260924 --plan
python3 evidence/caliptra-icarus-l0-parallel-runner-20260924/run.py \
  --output evidence/caliptra-icarus-l0-patched-long-52-20260924 --jobs 3 --timeout 14400
```

`--plan` reads and verifies the 52 names but creates no output. The live command
requires a new output path, writes one stdout/stderr log per case, and records
every outcome in `summary.json`. Only complete matching case results with clean
source/tool integrity and the original pass, zero-error, and firmware-execution
gate count as passes. Missing, blocked, or invalidated runs stay visible outside
the numerator. The six xPack GCC tool binaries are hashed before and after the
sweep; no Verilator or QD BFM process is launched.

`--timeout` defaults to 1,800 seconds per case. The released mailbox firmware
needs a longer limit: the first four-job attempt was stopped at 24 minutes when
the startup `.data` copy was only about 14% complete. The 14,400-second
diagnostic pilot uses the same per-case limit shown above.

Each case checks all of its own before/after fingerprints. Across cases the
aggregate compares stable compiler, runtime, DPI, and copied-source hashes;
copied filelist hashes can differ because they embed unique temporary paths.
`python3 -B evidence/caliptra-icarus-l0-parallel-runner-20260924/test_run.py`
checks that boundary and the frozen JTAG port/source guards without a sweep.
