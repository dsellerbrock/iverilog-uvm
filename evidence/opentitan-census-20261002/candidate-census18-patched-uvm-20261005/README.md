# Candidate UVM compile lane with DPI

The candidate compiler compiled all **35/35 UVM lane cores** on the patched OpenTitan source snapshot with the bundled `uvm_dpi.vpi` module installed. The run emitted no `UVM_NO_DPI` or missing-DPI fallback warning. This is a compile result; it does not establish runtime passes.

The result uses candidate engine SHA-256 `890c5b3c9ee0098ab4bcf4d25f06b10c3a8758a88d5e867b1a566a5ca9ecfdaa` and UVM 1.2 in `commercial-unsafe` mode. The raw result records OpenTitan revision `unknown`; however, the source tree is now reproducible from pinned commit `a78922f14a8cc20c7ee569f322a04626f2ac6127` using the [source overlay bundle](../candidate-census18-pinned-compile-20261005/README.md#reproducible-source-overlay). The tree hash is recorded in that evidence.

The earlier 309-row result's 31 UVM failures were caused by the missing DPI module and are superseded. The clean pinned release without source overlays still has UVM failures; see the [full pinned compile census](../candidate-census18-pinned-compile-20261005/README.md).

The row table is in [`result.md`](result.md) and machine-readable output is in [`result.json`](result.json). Per-core compile logs remain in the local candidate build directory recorded in the JSON.
