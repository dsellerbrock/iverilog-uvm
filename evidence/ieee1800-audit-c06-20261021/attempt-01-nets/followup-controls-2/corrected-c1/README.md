# Corrected C1 probe

The original C1 source used a net declaration assignment (`wire s_t n = v;`).
The audit lead specified the isolated continuous-assignment form instead:
declare `wire s_t n;`, then `assign n = v;`. This directory contains the
corrected probe and paired Slurm run. The first variant remains preserved in
`../raw-slurm-3766/input/C1_net_declaration_assignment.sv`.
