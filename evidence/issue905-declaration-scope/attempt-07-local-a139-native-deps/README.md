# Local T1 diagnosis on commit a139d2eb

The out-of-tree build and install passed after adding the already-installed Homebrew libffi and z3 paths. T1 legacy was 17/20: the 2023 declaration-scope wrapper and both method receiver wrappers failed to locate included files because their regression rows omitted `-Iivltests`. Per-test logs are in `raw-legacy-test-logs/`. The JSON manifest generator in this exploratory script selected some legacy-only test names, so its JSON stage did not run; it is not test evidence.

This diagnosis led to commit `b24b06d6`, which applies the existing `-Iivltests` convention to the three affected regression rows.
