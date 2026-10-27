# IEEE 1800 real-predicate bidirectional isolation

- Lead-directed five-case reduction of the incomplete P2_BIDIR result. IEEE 1800-2023 §§18.5.5–18.5.6; `-g2023` only.
- D1 isolates point disjunction without `inside`; D2 negated real comparison; D3 negated real truthiness; D4 backward implication; D5 if–else back-solving with an integral predicate over a real comparison.
- Each case makes five randomize calls. Compile and run each have a 60-second process-group timeout. Inputs, timeout helper and Slurm script are hashed in `input/SHA256SUMS-input.txt`.
- Open+closed dedupe for real disjunction, truthiness, implication and binary64 is in `dedupe-open-closed.txt`.
- Results and raw diagnostics will be recorded in `RESULT.md` after job completion.
