# Earl Grey Verilator top compile follow-up

The pinned clean OpenTitan source at `a78922f14a8cc20c7ee569f322a04626f2ac6127` now compiles the `lowrisc:systems:chip_earlgrey_verilator:0.1` RTL synthesis row with **PASS** on Icarus engine `367e44671b5aabf7786a200c2af4c3dcbd17c449bffa3ea2bc30fbfcfbaa1abc`.

The focused run completed in 139.435 seconds with zero hard errors, semantic debt, or actionable setup warnings. Its build-local overlays make three source corrections:

- Use four-bit `mubi4_t` values for the Verilator wrapper’s MuBi clock-control and scan signals, and connect the AST bypass request/acknowledge ports to the existing Earl Grey request/acknowledge signals. This removes accidental one-bit implicit nets.
- Give Ibex tracer locals automatic lifetime so their initializers run on each procedural activation.
- Guard only the simulation memory-path trace for synthesis. The ROM and OTP image defaults are hash-checked as empty, and the conditional `$readmemh` path remains present.

All source files stay unchanged in the clean OpenTitan checkout. The matrix runner stages hash-checked build-local overlays and redirects only this row’s source list. Original and generated source hashes, plus setup classification, are recorded in [result.json](result.json); the compile log is preserved alongside it. FuseSoC’s unlisted C, C++, and Python file-type notices remain recorded as benign setup diagnostics; none are in the Icarus source list.

This is one focused RTL compile pass, not a runtime DV result or a refreshed 309-row census.
