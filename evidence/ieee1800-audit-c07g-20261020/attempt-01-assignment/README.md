# IEEE 1800 §7.10.4 queue assignment probe

This probe covers the normative queue-assignment forms in the examples of
IEEE 1800-2017 and IEEE 1800-2023 §7.10.4: whole-queue concatenation for
append/prepend, slices for front/back removal, concatenation-based insertion
before/after a position, empty assignment, and the two queue-trimming forms.
Each case checks the complete resulting queue and terminates with `$fatal` on
mismatch.

The matching standard text and pages are in `STANDARD.md`. Slurm job 3560
completed both edition runs successfully; the exact evidence is in
[`RESULT.md`](RESULT.md) and `remote-3560/`. Lead classification is pending.
