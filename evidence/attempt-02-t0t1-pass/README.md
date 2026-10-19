# Issue #664 candidate T0/T1 evidence

## Candidate

- Host: DAN-DESKTOP (Slurm).
- Source base: `c344d20197a569dea8936bad95de3d185b1e78dc`; branch
  `agent/a3-m7-issue664-noarg-concat-20261018`.
- Changed implementation source SHA-256:
  `88ec381869682adb2c18fa3f79dab19d2e79febfe90e92cc714ecceffd174bdb`.
- Built compiler SHA-256:
  `8dad4f65dcac521d59db6199b7438a0f7f0a8df676fb83d7ed6b66780151454e`.
- Built VVP SHA-256:
  `cfd826b8500b130cd823fb45b05fe2b11fce1043f140daadb2fd701f0aa1f329`.

## Results

- Slurm job 2757 built and installed the candidate with `make -j2` (2 CPUs,
  6 GiB, 60 min). Its 12 selected T1 legacy tests and 12 selected T1 JSON tests
  passed. The first T0/smoke invocation used an incomplete harness setup, so
  that invocation is not counted as passing.
- After correcting the legacy source wrappers and JSON/legacy gold locations,
  job 2759 passed both new issue tests in both runners (legacy 2/2, JSON 2/2).
  Its smoke invocation still lacked the in-tree VVP build outputs and generated
  DPI header; that smoke result is not counted as passing.
- Job 2760 used a fresh copy of the completed build tree and the installed
  compiler/runtime at the paths expected by the smoke harness (1 CPU, 2 GiB,
  30 min). `sbatch --wait` returned exit 0. Both new T0 tests passed in the
  legacy and JSON runners (2/2 each); the smoke suite passed with 56/56 VVP,
  133/133 VPI, and 152/152 negative tests, plus all reproducers and runtime
  checks. The copied build tree contains the same `elab_expr.cc` hash and the
  same compiler/runtime hashes as job 2757.

The earlier harness setup failures are retained in the `attempt-2757-*` and
`attempt-2759-*` directories; they were missing-file/path failures, not
compiler failures. The completed validation logs are in `attempt-2760-smoke-pass/`.

The full build transcript is preserved byte-for-byte as the gzip-compressed
`attempt-2757-build-and-t1/a3-i664-t0t1-2757.out.gz`.
