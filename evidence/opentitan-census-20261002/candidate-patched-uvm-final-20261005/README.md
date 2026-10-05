# Patched OpenTitan UVM recheck

The full patched OpenTitan UVM lane passed **35/35** with the latest rebuilt
compiler engine, SHA-256
`367e44671b5aabf7786a200c2af4c3dcbd17c449bffa3ea2bc30fbfcfbaa1abc`.
The row-level [JSON](result.json), [summary](result.md), and RAM-guard log are
preserved here.

The source is the census18 snapshot at
`/private/tmp/ot-corpus-current-spid-passthrough-20261003/source`. Its overlay
is reproducible from the clean pinned source using the
[source overlay and provenance](../candidate-census18-pinned-compile-20261005/README.md#reproducible-source-overlay)
and Trial1 relocation helper. The clean-source census remains separate and
still has actionable compiler failures and semantic debt.
