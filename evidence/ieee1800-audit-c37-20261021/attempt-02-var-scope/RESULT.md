# Clause 37 variable and instance-scope results

Slurm job 3687 completed with Icarus 13.0-devel source `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`. The VPI module built successfully, and all four fixtures compiled and ran with exit 0 under both `-g2017` and `-g2023`. The probe included the pinned toolchain's `sv_vpi_user.h`, which defines `vpiInstance` as 745; its SHA-256 is `7d18188bb855ea83dea8ba0f8c64a411023ba1edceef872ecf8173fedb0b1ba9`.

- In all eight runs, `vpi_iterate(vpiVariables, p37)` returned count 0.
- For `p37_var_unref.sv`, `vpiReg` returned only output port `y` (size 4); it did not return the unused `logic [7:0] v`.
- For `p37_var_ref.sv`, `vpiReg` returned both `v` (size 8) and `y` (size 4). The SV display printed `v=x`.
- For `p37_reg.sv`, `vpiReg` returned only `y`; the unused `reg [7:0] v` was absent.
- For child instance `u`, output was `child=p37.u def=sub instance=<null> scope=p37 module=p37` in both editions. Thus `vpiScope` and `vpiModule` identified the containing module `p37`; `vpiInstance` returned NULL.

The first follow-up attempt (job 3685) never loaded a VPI module because it omitted the public SV VPI header. Job 3686 built and ran, but its child-handle strings were ambiguous due to reused `vpi_get_str` buffers; it is retained as a harness iteration. The job 3687 result above uses separately printed strings.

Issue classification is pending the 1800-audit lead. `DEDUPE.md` records the open-and-closed search results.
