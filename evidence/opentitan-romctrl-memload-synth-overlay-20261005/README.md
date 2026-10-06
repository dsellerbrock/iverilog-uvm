# OpenTitan ROM controller synthesis warning

The previous RTL result marked `lowrisc:ip:rom_ctrl:0.1` as DEBT because `prim_util_memload.svh` reported `Process not synthesized.` The selected standalone `rom_ctrl` top has `BootRomInitFile=""`; the warning came from a simulation-only `show_mem_paths` plusarg/display in the same initial process as the optional memory loader.

For this exact top and pinned source, the matrix runner now creates a build-local include overlay for the RTL lane only. It wraps only the plusarg/display trace in `` `ifndef SYNTHESIS `` and leaves the conditional `$readmemh` code unchanged. The overlay is guarded by SHA-256 checks for both `prim_util_memload.svh` and `rom_ctrl.sv`, and its path and hash are recorded in `result.json`. No pinned OpenTitan source was edited.

## Evidence

- Baseline compile with the candidate backend and no overlay: exit 0 with the `Process not synthesized` warning in [baseline-compile.log](baseline-compile.log).
- Focused matrix compile with the overlay: `PASS`, zero hard errors, zero semantic debt, and no diagnostics in [result.json](result.json) and [overlay-matrix-compile.log](overlay-matrix-compile.log).
- The overlay preserves the memory loader: a negative compile control with nonempty `BootRomInitFile` still reports `Process not synthesized` in [nonempty-image-control-compile.log](nonempty-image-control-compile.log). That case remains debt; the overlay does not hide an active `$readmemh` path.
- `scripts/opentitan_matrix.py --self-test` passed with the overlay command and preservation checks.

The pinned source hashes were `prim_util_memload.svh` `0ae62592964c0648c08f28fdd235ed7e7668f6071dc001aa6c1b6f652eea1956` and `rom_ctrl.sv` `72cdd7822b2b5df3de40dc933b85f31384841337c79f59dfe88f961d8e9f4c47`. The generated overlay hash is `9484798c23f4f441e9e454677429af14bcefcad2d10f74d099acbe4b39475da3`.

The focused run used the generation-guard candidate backend `ivl` SHA-256 `a55408edce6e223df99061590c9055cfc055f503a628810248c723f5390d4b00` through a wrapper. The matrix JSON records the wrapper hash; this README records the backend hash separately.
