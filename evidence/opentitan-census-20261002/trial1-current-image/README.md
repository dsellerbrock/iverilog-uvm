# Trial1 current-image replay

`lowrisc:ip:trial1_sim:0.1` passes on the current Icarus image with the named Trial1 core-layout overlay. The matrix compiler used `-gcommercial-unsafe`; the row reports zero setup warnings, compile errors/debt, runtime errors/debt, and one checked pass banner. The run uses `PYTHONHASHSEED=2` and a 4 GiB/120-second runtime guard.

The disposable root was copied from the census11 OpenTitan source root (base revision `a78922f14a8cc20c7ee569f322a04626f2ac6127`) with `.git` metadata excluded. The helper self-check passed before applying the exact-hash overlay. It moved `trial1_sim.core` from `hw/ip/trial1/dv/` to `hw/ip/trial1/`, with core SHA-256 changing from `813a8097…fb010` to `bc7ddd30…c5a37`. The original source core still has the preimage hash.

Compiler/runtime fingerprints and the exact commands are recorded in [result.json](result.json). Durable copies of the [setup](matrix-setup.log), [compile](matrix-compile.log), [runtime](matrix-runtime.log), and [compiler source list](matrix-iverilog.scr) logs are beside it. This selected row does not update the last complete 49-row census.
