# IEEE 1800 §22.14 keyword directives probe

## Standard basis

IEEE 1800-2017 §22.14 lists `1800-2017` as a standard version specifier.
IEEE 1800-2023 §22.14 lists both `1800-2017` and `1800-2023`, and requires
`begin_keywords` and `end_keywords` to be used as a pair. Both editions state
that an implementation may define custom specifiers, but an unrecognized
specifier shall cause an error.

## Probe and result

The three compile-only probes are in [`tests/1800_audit/c22/`](../../../tests/1800_audit/c22/):

- [`p22_14_keywords_2017.sv`](../../../tests/1800_audit/c22/p22_14_keywords_2017.sv) uses the standard-listed `1800-2017` specifier.
- [`p22_14_keywords_2023.sv`](../../../tests/1800_audit/c22/p22_14_keywords_2023.sv) uses the standard-listed `1800-2023` specifier.
- [`n22_14_unknown_keywords_version.sv`](../../../tests/1800_audit/c22/n22_14_unknown_keywords_version.sv) uses the unrecognized `1800-9999` specifier, which should be an error.

Slurm job 3602 used current-main toolchain commit
`fb584a251dd4cc91e56a75be662ccd5ee05c64e9` (Icarus 13.0-devel), one CPU,
1 GiB, and a 5-minute allocation. Each compile had a 30-second timeout. All
three commands exited 0. For both standard-listed values the compiler printed
`Ignoring unknown keywords string` and left the directive ineffective. It
printed the same warning and accepted `1800-9999`, instead of reporting the
required error. Raw stdout/stderr and Slurm output are retained in
[`remote-3602/`](remote-3602/). Source SHA-256 values: `p22_14_keywords_2017.sv` `11621d27e802f848f670d35f9d51f1d1353e13ea6c790ab442fe9fc1d2ee4253`, `p22_14_keywords_2023.sv` `1edb41077d57a3ed5af2494284d7dac83e55932ca38b89ec242d2037914716c4`, and `n22_14_unknown_keywords_version.sv` `4da6423da5c1c69586745e8b42e47e6244def0f4d3c19d2d1bcc001818d0defe`.

This initial run used `-g2012`. The paired-edition rerun in [Slurm job 3604](../../../evidence/ieee1800-audit-c22-20261021/attempt-02-paired-editions/RESULT.md) confirms that current main supports `-g2017` and `-g2023` and also probes the 2023 begin/end pairing rule.

## Dedupe and lead status

Open and closed `1800-audit` searches for `begin_keywords` and for
`22.14 keywords version_specifier` returned no matching issues. No issue was
filed by the runner. The lead helper reports “daily lead cap reached (160)”; classification and any issue filing remain pending.
