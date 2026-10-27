# Attempt 01: harness packaging error

Slurm job 3367 ended normally, but this is not probe evidence. The input archive contained a leading `input/` directory, while the job expected the source files directly under its input directory. All eight compile commands returned 2 because their source paths did not exist; see the archived logs and `results/results.tsv`. The probe sources are unchanged and are resubmitted in attempt 02 from a fresh Slurm run directory with a flat archive.
