# Attempt 15 — harness setup failure

- Slurm job: 3001 on DAN-DESKTOP.
- Submitted script SHA-256: `155a921c5718adf80941bcf777bb63d918fec8ccc6d3d0be9002c64d88515e70`.
- Input archive SHA-256: `7040106a0695a6f8f6b600ee2ca57b4aeb32957a8bcbdb190e504518481d75ed`.
- Raw results bundle SHA-256: `da1126279189fef033dbfedb3181d8d93feb66cfb922d36c5e6c7671b585dc26` (`results-3001.tar.gz`).

The input archive was copied to the run-directory root instead of `input/`,
which is where the submitted script looked. Extraction failed. Both positive
compiles and both negative compiles then reported missing source files. The
negative checks were false positives because the runner accepted any ordinary
compile error. **No probe compiled or ran; no standards conclusion can be
drawn from this attempt.** The raw `GATE_RESULT=FAIL` and logs are preserved
for auditability.
