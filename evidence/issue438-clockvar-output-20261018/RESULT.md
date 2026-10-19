# PR #669 post-review boundary check

Date: 2026-10-19

Branch: `agent/a3-m7-issue438-clockvar-output-20261018`

Base commit: `edbae730223eff4a748dd76bedd60ba9eaef779e`

This run closes a review gap in PR #669: fixed-unpacked output arrays of declared nets must remain outside its variable-array scope. `uwire` arrays now receive a clear elaboration diagnostic instead of reaching the VPI assertion. The paired 2017/2023 regression is registered in the legacy and JSON runners and in the focused clocking-output lists. The conformance notes point to follow-up issue [#674](https://github.com/dsellerbrock/iverilog-uvm/issues/674) for unpacked net outputs.

## Toolchain and build

- Host: macOS, local run budget 3,600 seconds; no Slurm job was submitted.
- Compiler: Icarus Verilog 13.0 devel.
- `iverilog` SHA-256: `5ee52c78c1c5d08f8c3cba4eb0000414e8f7b27c1a3beac1a51a386a8cd87f0e`.
- `vvp` SHA-256: `404c1121d16f1e32674c6a61d633811894096ed9dc22191c4d4783d95ab0fb53`.
- Incremental build after the guard: `~/codex-supervisor/localrun 900 make -j3 && make install`; passed in 41.70 seconds, peak RSS 1,356,775,424 bytes. Homebrew Bison was first in `PATH`; Homebrew libffi/Z3 flags were used.

## Focused T0/T1 selection

Graphify mapped the touched elaboration path to the clocking-output focus set. The command `~/codex-supervisor/localrun 3600 bash evidence/issue438-clockvar-output-20261018/attempt-10-uwire-boundary-local/run-focus-local.sh` passed:

- Legacy clocking-output set: 49/49.
- JSON clocking-output set: 56/56.
- Both editions reject the declared `uwire` array with `a clocking output array of nets requires per-word net drivers.`
- Total run time: 22.25 seconds; peak RSS: 21,889,024 bytes.

The first smoke attempt in attempt 10 passed VVP 56/56 and VPI 133/133, then runtime helpers failed because the expected worktree-local `local-install/bin` prefix was absent. This was a test setup failure, not a simulator result. The same built binaries were installed at that expected prefix and the complete smoke run was repeated:

```text
PATH=<worktree>/local-install/bin:$PATH ~/codex-supervisor/localrun 3600 ./ci/run-smoke.sh
```

Attempt 11 passed with exit code 0: VVP 56/56, VPI 133/133, negative suite 152/152, all reproducers, and all VVP runtime checks. Runtime was 181.05 seconds; peak RSS was 115,638,272 bytes. Logs are in `attempt-10-uwire-boundary-local/` and `attempt-11-smoke-install-local/`.

## Boundary and remaining gate

The new test covers the `uwire` case that previously passed the broad `UNRESOLVED_WIRE` check and then hit an internal assertion. `NetNet::coerced_to_uwire()` preserves the distinction between a declared net and a variable converted for a continuous assignment. Existing output-array storage remains restricted to one fixed unpacked dimension; unpacked net output support is tracked separately in #674.

T0/T1 are complete locally. The current Fast Linux result is for the prior PR head, and the running T2 batches do not contain this boundary fix. Push this change, wait for Fast Linux on the exact new head, and include it in the next T2 batch before merging.
