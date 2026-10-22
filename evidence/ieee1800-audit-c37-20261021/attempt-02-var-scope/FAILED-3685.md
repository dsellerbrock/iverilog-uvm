# Slurm job 3685 — harness build failure

`iverilog-vpi` could not compile the follow-up probe because the first C revision included `vpi_user.h` but not `sv_vpi_user.h`; therefore `vpiInstance` (standard constant 745) was undeclared. All eight HDL compiles exited 0, but VPI module loading and simulation were correctly skipped. This is a probe build failure, not a simulator result. The corrected C source includes the public SV VPI header and is rerun as job 3686.
