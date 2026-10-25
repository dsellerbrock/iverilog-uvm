# IEEE 1800 clause 19.7 probe

The probe targets common coverage options in 2017/2023, the 2023-only
`real_interval` and `cross_retain_auto_bins` options, duplicate-option
rejection, and rejection of an instance option used as a type option.

Standards references: IEEE 1800-2017 §19.7 pp. 577–581; IEEE 1800-2023
§19.7–§19.7.1 pp. 605–609. The 2023-only options are listed in Table 19-1
(`cross_retain_auto_bins`) and Table 19-3 (`real_interval`).

The frozen inputs and submitted run script are in this directory. Raw results
and the probe summary are in `results-2998.tar.gz` and `RESULT.md`. Attempt 13
was a harness setup failure: its script omitted archive extraction, so no
probes ran.

Source worktree: branch `m7-1800-audit-c08`, HEAD
`27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`. The worktree also contains other
in-progress audit changes; the exact inputs for this run are frozen in the
archive with SHA-256 `61c060d0372e18b40d9f02f70b040029753971f3b8824748b62126001f942903`.
The read-only toolchain is `/home/dsell/toolchains/iverilog-a3-main-82023726-679`.
The submitted script SHA-256 is `4c4a65541df93f15c5ae775e2b7d2d6617294f5ef25726b60512efedd75a0d7b`.

## Archive integrity

- `results-2998.tar.gz`: 6980 bytes; SHA-256 `968a89ae75f6f4cfe8a0d9cb42d2880eca4840392b41ce18f77420b8ed79defe`.
