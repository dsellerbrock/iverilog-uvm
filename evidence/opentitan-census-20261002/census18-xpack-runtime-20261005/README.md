# Corrected full runtime census invocation

This run is prepared to repeat all 49 runtime rows after census17 exits. It
uses the existing OpenTitan Python environment and xPack RV32 assembler/linker
so OTBN does not enter the Bash/Bazelisk fallback path. It runs one target at
a time with an 18,000-second per-target limit and a 9,536-MiB physical-footprint
cap per runtime process. Serial execution keeps the aggregate runtime memory
bounded by that cap instead of allowing multiple capped simulators to overlap.

Run from the repository root after census17 is complete:

```sh
bash evidence/opentitan-census-20261002/census18-xpack-runtime-20261005/run-census18.sh
```

The script records its branch, commit, and assembler/linker hashes in
`runner.log`, with the full matrix results in `result.json` and `result.md`.
This is a prepared invocation, not a result; census18 must finish with 49
`PASS` rows and no hard errors, debt, runtime errors, timeouts, or memory-cap
hits to satisfy the runtime gate. It uses the installed pre-candidate
compiler; the candidate compiler's RTL/SVA/UVM census remains a separate gate.
