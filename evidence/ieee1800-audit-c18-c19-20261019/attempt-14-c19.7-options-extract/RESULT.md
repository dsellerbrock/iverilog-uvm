# Clause 19.7 probe results

Slurm job 2998 ran on DAN-DESKTOP using one CPU and a 1 GiB memory limit.
It completed in 1 second with exit code 1 because three expected compiler
rejections were accepted. This is a standards-probe result, not an
infrastructure failure.

Toolchain: `/home/dsell/toolchains/iverilog-a3-main-82023726-679`.
`iverilog` SHA-256: `17661deebeaf8180f5761c82d1eeb31f30b5605739c724cb82dc4a04975a8256`.
`vvp` SHA-256: `911cd2ba4a1f1a62afeb6b9463ee18a3aab338e09cb5eb89c8b1a73b0b4138cc`.
The maximum per-command peak RSS was 12,020 KiB across 11 commands; each
compiler and runtime invocation had a 60-second timeout.

Results:

- The common probe passed in both editions: `option.at_least`, zero-weight
  exclusion, four-bin `auto_bin_max`, and declaration/instantiation of
  `type_option.weight` and `type_option.goal` behaved as checked.
- The 2023 probe passed in `-g2023`, exercising `type_option.real_interval`
  and `option.cross_retain_auto_bins`. Under `-g2017`, compilation rejected
  both 2023-only features (exit 2).
- Duplicate `option.weight` assignments compiled successfully in both
  editions (exit 0). IEEE 1800-2017 §19.7 p. 578 and IEEE 1800-2023 §19.7
  p. 605 require an error for the same option specified more than once
  within one covergroup definition.
- `type_option.auto_bin_max` compiled successfully in both editions (exit 0)
  with the non-fatal diagnostic `sorry: unknown covergroup option
  'type_option.auto_bin_max' in covergroup is ignored.` `auto_bin_max` is an
  instance option in Table 19-1, not a type option in Table 19-3.

Raw commands, per-command exit codes/timing/RSS, and complete logs are in
`results-2998.tar.gz` (SHA-256
`968a89ae75f6f4cfe8a0d9cb42d2880eca4840392b41ce18f77420b8ed79defe`). The
four frozen inputs are in `input/c19.7-probes.tar.gz` (SHA-256
`61c060d0372e18b40d9f02f70b040029753971f3b8824748b62126001f942903`).
Lead classification: **PARTIAL**. The audit lead filed [#686](https://github.com/dsellerbrock/iverilog-uvm/issues/686)
for duplicate option acceptance and [#687](https://github.com/dsellerbrock/iverilog-uvm/issues/687)
for non-fatal acceptance of an instance-only option on `type_option`.
