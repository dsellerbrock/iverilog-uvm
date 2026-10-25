# IEEE 1800 clause 13 probe c13c, split follow-up

This attempt separates the required 2017 function-scope `F.member` check from the 2023-only implicit-variable expressions. It also runs the exact two-edition issue-duplicate searches requested by the audit lead.

The Slurm probe uses the protected Icarus 13.0 devel build from `9b5fad2afb4104caa816b257d5bccc40f01b8c66`, 1 CPU and 1 GiB. Each compile is limited to 60 seconds; each simulation to 30 seconds, with TERM then KILL after 2 seconds. The 2017 implicit-variable result is informational; the function-scope test is required in both editions and both implicit-variable checks are required in 2023.
