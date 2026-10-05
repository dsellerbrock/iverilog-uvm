# Keccak 2-share FPV remains upstream-invalid

The focused SVA row remains `UPSTREAM_INVALID` on clean OpenTitan revision
`a78922f14a8cc20c7ee569f322a04626f2ac6127` and engine
`367e44671b5aabf7786a200c2af4c3dcbd17c449bffa3ea2bc30fbfcfbaa1abc`.

The [diagnostic source probe](source-repair-probe.patch) closes the missing
`StPhase1` case item and imports `prim_mubi_pkg`. Compilation then reaches both
`keccak_2share` instances and rejects obsolete `cycle_i` and `rand_aux_i` port
connections. The current DUT instead has DOM control and lifecycle inputs, so
the FPV checker needs a control-model update before it can be considered valid.
This probe does not make the row pass and does not change the frozen 309-row
census.

See the [machine result](result.json), [matrix report](result.md),
[setup log](setup.log), and [compile log](compile.log).
