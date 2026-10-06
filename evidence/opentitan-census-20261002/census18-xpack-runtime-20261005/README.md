# Census18: corrected full runtime census

Census18 completed on 2026-10-05 with **49/49 runtime targets passing**. All
rows emitted their checked pass markers. There were zero hard errors, semantic
debt, runtime errors or debt, timeouts, memory-cap hits, or memory-monitor
errors. The OTBN row passed with its xPack RV32 tools, resolving census17's
toolchain setup failure.

The invocation used the installed pre-candidate compiler, pinned UVM 1.2,
`-gcommercial-unsafe`, native OpenSSL/libelf, and the copied OpenTitan source
snapshot under `/private/tmp/ot-corpus-current-spid-passthrough-20261003/source`.
The snapshot has no Git metadata, so the result records its revision as
`unknown`. A later source audit showed the snapshot is reconstructible from the
clean pinned checkout using the consolidated
[source-overlay patch and provenance](../candidate-census18-pinned-compile-20261005/README.md#reproducible-source-overlay)
plus the checked Trial1 relocation helper. The pinned checkout was not edited.

## RAM guard

The run executes one target at a time (`--jobs 1`) and gives each runtime
process an 18,000-second timeout and a 9,536-MiB physical-footprint limit. This
keeps capped simulators from overlapping. No process hit the limit. The largest
recorded process footprint was **3,116 MiB** for `lowrisc:dv:chip_sim:0.1`;
Flash peaked at 915 MiB and OTBN at 921 MiB. System memory-pressure samples
during the run ranged from 78% to 82% free.

## Reproduction and outputs

The recorded local run can be replayed from the repository root:

```sh
bash evidence/opentitan-census-20261002/census18-xpack-runtime-20261005/run-census18.sh
```

The script records the branch, commit, and xPack tool hashes in `runner.log`.
For an independent replication, reconstruct the source with the
[reproduction guide](../../../docs/conformance/opentitan_49of49_reproduction.md)
first, then point the matrix command at that disposable copy.
The complete row-level output is in `result.json` and `result.md`. The sum of
the 49 recorded runtime durations is 9,387.5 seconds; Flash took 3,398.499
seconds.

This result clears the selected runtime gate only. The candidate compiler's
refreshed RTL/SVA/UVM census remains a separate gate.
