## Attempt 02 — local dependency failure

The current-main build reached VVP compilation, then failed at `vvp_dpi.cc:15` because `ffi.h` was not found. No §14.3 probe ran. `localrun` recorded 176.61 seconds and 1,368,031,232 bytes peak RSS. The audit will use a Slurm-built current toolchain instead of changing the Mac dependency setup.
