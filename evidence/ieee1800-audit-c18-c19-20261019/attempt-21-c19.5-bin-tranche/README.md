# Clause 19.5 bin probes — attempt 21

The IEEE PDFs use the same clause numbering in 2017 and 2023: §19.5.1
specifies bins for values (including array bins), §19.5.2 specifies transition
bins, §19.5.3 covers automatic bin creation, §19.5.4 wildcard bins, §19.5.5
ignored values/transitions, and §19.5.6 illegal values/transitions. This corrects
the subclause labels in the lead's initial checklist. The existing
`p19_05_bins_cov.sv` already exercises named and array bins for §19.5.1; this
attempt avoids duplicating it.

The automatic-bin probe is a small positive control for §19.5.3. The separate
wide, non-power-of-two `auto_bin_max` limitation is already captured by issue
#696 and its 512-bit probe (Slurm job 3113).

Probes to run with both `-g2017` and `-g2023`:

- `p19_05_02_transition_bins.sv` — ordered transitions across samples.
- `p19_05_03_auto_bins.sv` — automatic bins and complete coverage.
- `p19_05_04_wildcard_bins.sv` — wildcard match and nonmatch.
- `p19_05_05_ignore_bins.sv` — ignored values do not count toward coverage.
- `n19_05_06_illegal_bins_runtime.sv` — sampling an illegal value reports a
  runtime error.

IEEE citations: IEEE 1800-2017 §§19.5.1–19.5.6 and IEEE 1800-2023
§§19.5.1–19.5.6. Raw extracts used for the section map are from the local
standards PDFs. The staged compiler source is `6604c23e197980b69a5b6b69864ff8ef8d05eba3`.

Slurm job 3169 completed with `ExitCode=0:0` (1 CPU / 1 GiB, 1 second),
after §14 job 3166 and #457 job 3168. It used the toolchain built from staged
SHA `6604c23e197980b69a5b6b69864ff8ef8d05eba3`: `iverilog`
`f8c0376ed73753c3327b1d7f5d4d647820836799064d965be7e1a8fbb9403ccd`, `vvp`
`53ad297f5370175e0df8af51c5947b7b34c723cf258617febf716cf82168249b`.

All positive probes compiled and ran with exit 0 and their PASS markers in both
2017 and 2023. The illegal-bin probe also compiled and ran with exit 0 in both
editions; each run printed `ERROR: covergroup illegal_bin matched (prop_idx=6)`
when sampling 15, then continued to the following display, satisfying the
runtime diagnostic observation. Per-edition compile/run logs and summary are in
`results/`; the Slurm stdout and test source hashes are preserved there and in
this README's sibling input archive.


## Checksums

| File | SHA-256 |
| --- | --- |
| `input.tar.gz` | `f99f28a0feebd55d41f057cf6eb329948dbea58b1ef06f26e1271db8674f60d1` |
| `run.sbatch` | `b03ef69d91dcc63a772f036b361de6895782d4a57404381d7a4bff111f5a8ea0` |
| `p19_05_02_transition_bins.sv` | `edcf49c64fbebbf2f3992b55dafb6388d68fd54373fd0982048437dc5318e3ff` |
| `p19_05_03_auto_bins.sv` | `1b7d9c077c084f001774bb52307877dd333731cc9bd4ddfb58eecfb0d9924e27` |
| `p19_05_04_wildcard_bins.sv` | `4f3ed26dd599a15a65bfe1b79049fb89074d22cbda21c21c84a6b5aa8a5a4ec0` |
| `p19_05_05_ignore_bins.sv` | `1ba17ceca390ed5bc54b0c0697f8a790982747546ea400b3172b6dfae5dc37de` |
| `n19_05_06_illegal_bins_runtime.sv` | `d2ed9790ae6ef624dda9830dea1446e20fa3fefb9149b3c33636ae563cd71bab` |
