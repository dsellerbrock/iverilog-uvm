# IEEE 1800 §§8.19–8.20 first attempt (Slurm job 3501)

This attempt is retained to document a probe-source error. The positive control used the identifier `small`, which is a reserved Verilog strength keyword; Icarus rejected the positive source in both editions at the declaration and later references. This is a probe syntax error, not simulator evidence. The source was corrected to `small_pkt` for attempt 02.

The independent negative checks still ran: the four §8.19 invalid constant writes were rejected; the record-only duplicate assignment was rejected; all five malformed §8.20 overrides compiled silently in both editions. See `results-3501.tar.gz` for raw logs and the table. No issue was filed from this attempt.
