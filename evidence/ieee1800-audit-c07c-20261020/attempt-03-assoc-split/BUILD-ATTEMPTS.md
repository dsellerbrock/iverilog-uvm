# Local toolchain setup attempts

1. Slurm job 3517 was queued with `Reason=Resources` while Slurm had 38,912 MiB allocated of 39,101 MiB; canceled before start. No probe result came from it.
2. `git archive cc25756d` omitted generated `configure`. The local runner generated it with Autoconf 2.73; the first build then failed at `parse.y:2386` because macOS's system Bison is 2.3. No probe result came from it.
3. The next build used Homebrew Bison 3.8.2 and reached VVP compilation, then failed because pkg-config selected the macOS SDK `ffi.h` path rather than Homebrew's header. No probe result came from it.
4. Adding Homebrew libffi include/library paths let the full build reach `vvp_z3.cc`, which then failed on missing `z3.h`. The failure log is `build-attempt-03.log`.
5. The resume step uses the already-built exact `cc25756d` source tree and object files, adds Homebrew libffi and Z3 include/library paths to the VVP sub-build, finishes `make install`, then runs the six probes. This avoids repeating completed compiler work; see `run-local.sh` and `localrun-final-04.log`.
