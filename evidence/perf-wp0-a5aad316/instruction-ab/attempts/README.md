# Preserved Slurm attempts

Pinned measurement base: `f9f8e0a79f230f38da6cbb4445994ad1075ad531`.

- Job 1133 stopped during Valgrind startup because `VALGRIND_LIB` was not
  exported before the version check. No VVP profile ran.
- Job 1135 completed both VVP profiles and output comparisons. The original
  helper exited 1 because its exact-count assertion rejected the 70-instruction
  difference. Raw profiles and the captured counts are in `../job1135/`.
