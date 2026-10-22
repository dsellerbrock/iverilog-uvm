# Exploratory §16.12.16 case probe (not classification evidence)

Slurm job 3207 added the required semicolon after `endcase`, but the assertion redundantly specified a clock already declared by the named property. Icarus diagnosed the duplicate clock, so this result is a test construction error. The corrected single-clock form is in attempt 36.
