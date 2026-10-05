# SPI Host SVA target fileset correction

`lowrisc:dv:spi_host_sva:0.1` passes on clean OpenTitan revision
`a78922f14a8cc20c7ee569f322a04626f2ac6127` with engine
`367e44671b5aabf7786a200c2af4c3dcbd17c449bffa3ea2bc30fbfcfbaa1abc`, with
zero setup warnings, compile errors, or semantic debt.

The pinned core defines `files_dv`, but its `formal` target also requests the
undefined `files_formal` fileset. A hash-checked, build-local core overlay
removes only that stale reference; the target still includes `files_dv`, its
SVA/bind sources, and its assertion generator. The [reproducible patch](source-core-fix.patch)
and [machine result](result.json), [matrix report](result.md),
[setup log](setup.log), and [compile log](compile.log) are saved here.
The 309-row aggregate remains frozen.
