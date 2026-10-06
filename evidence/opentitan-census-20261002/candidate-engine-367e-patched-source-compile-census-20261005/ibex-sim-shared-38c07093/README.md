# Ibex simulation support providers

OpenTitan `a78922f14a8cc20c7ee569f322a04626f2ac6127` pins Ibex to `38c070939183cc10940b66c8e9e04eeca6b65470`, while its compliance and cosimulation cores reference support cores that are not vendored in that OpenTitan snapshot. These eight files are copied from that exact Ibex revision and staged only in the matrix build overlay. `manifest.json` records their SHA-256 values; `LICENSE` preserves the upstream license.

Upstream: [sim_shared.core](https://github.com/lowRISC/ibex/blob/38c070939183cc10940b66c8e9e04eeca6b65470/shared/sim_shared.core), [simple system core](https://github.com/lowRISC/ibex/blob/38c070939183cc10940b66c8e9e04eeca6b65470/examples/simple_system/ibex_simple_system_core.core), [OpenTitan Ibex vendor lock](https://github.com/lowRISC/opentitan/blob/a78922f14a8cc20c7ee569f322a04626f2ac6127/hw/vendor/lowrisc_ibex.lock.hjson).
