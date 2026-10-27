# Initial Clause 37 probe attempts

## Slurm job 3683 — harness-only

The VPI module and both editions compiled and ran successfully, but the SystemVerilog fixture did not invoke `$probe37`; both run stdout files are empty. This attempt contains no conformance observations.

## Slurm job 3684 — preliminary observations

Toolchain: Icarus 13.0-devel from `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`. Both `-g2017` and `-g2023` compiled and ran with exit 0. Both editions reported ports `a` and `y` with directions 1/2 and sizes 1/4, and parameter `P=7`. With only an unreferenced `logic [7:0] v`, `vpi_iterate(vpiVariables,p37)` returned no objects. Child `u` reported definition `sub`; `vpi_handle(vpiScope,u)` and `vpi_handle(vpiModule,u)` both named `sub`.

These are preliminary results, not yet classified: follow-up job 3685 separates the unused/referenced `logic`, `reg`, and child-instance relations.
