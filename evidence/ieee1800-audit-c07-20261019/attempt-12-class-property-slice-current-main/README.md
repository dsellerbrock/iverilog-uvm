# Attempt 12 — Clause 7.6 class-property slice probe on current main

- Source commit/tree: `8c95b5cc10fc83d15b47e0364d2d7b4a2e12cac1` / `817b904c91f8b7d302fcb12da3c12aa5d1814dd0`.
- Slurm job 3252 on DAN-DESKTOP; 1 CPU / 1 GiB. The minimal `p07_06_class_property_slice.sv` compiles with `-g2017` and `-g2023` both returning 1 with `sorry: dynamic-array slice r-values are not yet supported as fixed-size unpacked-array expressions.`
- IEEE 1800-2017/2023 §7.6 explicitly permits assignment sources involving array slices; this confirms the current-main gap tracked by #671.
- Toolchain SHA values match attempt 08. Result manifest verified. Archive SHA-256 `326dd89da54d941ce0ff83463b22d1cd1cca285ae6296c17696ed7086e256647`; Slurm log SHA-256 `8e10ee86b7f72dffe3df763a38da355b3a43774cec763dc9286a6e351c56abe0`. Slurm accounting is disabled.
- Remote run root removed after result transfer and checksum verification.
