# Current-main build attempt 01

The source archive was pinned to `origin/main` commit `c41e504c7ee64a7bfc047f8662d3bc8044f1d90f`. Autoconf and configure succeeded, but the build stopped in `vvp_dpi.cc` because configure enabled libffi without adding Homebrew's keg-only `ffi.h` include path. This is an environment/build setup failure, not probe evidence. Logs are preserved here. Attempt 05 resumes this isolated build with Homebrew libffi's include and library paths.
