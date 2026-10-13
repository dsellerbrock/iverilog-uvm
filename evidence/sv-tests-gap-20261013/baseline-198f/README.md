# Verified Icarus 13 source-build baseline

Slurm job 833 replayed the pinned sv-tests corpus with the actual Icarus 13 source build, using the corrected wrapper resolution already used by job 816.

- Source commit/tree: `198f0abec3154a916d13730cee24549e24e076b0` / `5f18c01ab88bc385710e9734a5c41249e34cb875`.
- Compiler/VVP SHA-256: `d728a3d5d05cb81375b367f76324dc7b19b2f2dec6041626c0dcf2aac9664c16` / `3146652a6461678992534d98ebb453f32e5bcaeedb1eeba029f415c5f50b4526`.
- Corpus/UVM commits: `c4229f3bd5220e6d3ba8f390e5d09c87e462e9c7` / `656f20d087370a7c742e00188d20bbf30fa95339`.
- Result: 1,022/1,027 passed (99.51%); five failed. All per-test outcome fields match current-source job 816.
- Runner script SHA-256: `4b98093938ef77c155e7b6b4fe593e7619ced4242dca61281ce3c3e6c3e6a158`.
- `runner-safe` SHA-256: `f271c6424a0592fde39ff5ae8c8f7c56b2a5587bfc10604a48c1b3815a4bc4af`.
- Raw-log archive SHA-256: `dcf866a19a1dd2ad09c56bf440d6a903f45150ba7a20dcf1d042efef09518573`.

`evidence/start/summary.json`, `all-tests.txt`, and `raw-logs.tar.gz` are the outcome evidence. `logs/` contains the environment, binary hashes, run output, completion marker, and corpus archive hash. `run.sbatch` and the runner files preserve the invocation. The former 603/1,027 result is retained separately under `original-job-584/`; that run resolved system Icarus 12.0.
