# Post-processed throughput evidence

Pinned measurement base: `f9f8e0a79f230f38da6cbb4445994ad1075ad531`; main snapshot: `7f508a8a3ab4f1a230d65abfa2543a12ca2f40a9`.

This is the validated post-processing of Slurm job 1815. The original remote analyzer rejected only the dynamic progress-heartbeat line. The corrected analyzer removes that line and the mcycle marker, then requires every other simulator log line and all generated firmware input hashes to match. All 18 samples report exactly 2,000 cycles and the expected runner exit 1 from the deliberate early stop. See [`summary.md`](results/summary.md) and [`analyze-fixed.py`](analyze-fixed.py).
