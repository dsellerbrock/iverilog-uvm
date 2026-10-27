# IEEE 1800 §§22.12–22.14 paired-edition probes

## Standard basis

IEEE 1800-2017 and 1800-2023 §22.12 use the same `line` directive rules.
For §22.14, both editions list `1800-2017`; only the 2023 edition lists
`1800-2023`. Both say an unrecognized version specifier shall cause an error.
The 2023 text additionally requires `begin_keywords` and `end_keywords` to be
used as a pair; the corresponding 2017 text does not contain that requirement.

## §22.12 result

Existing regression [`fileline2.v`](../../../ivtest/ivltests/fileline2.v)
was compiled and run with both `-g2017` and `-g2023`. In each mode, the line
numbers and file names for directive levels 0, 1, and 2 matched the checked-in
golden exactly.

## §22.14 result

Slurm job 3604 compiled the probes in both edition modes using the current-main
toolchain `fb584a251dd4cc91e56a75be662ccd5ee05c64e9` (1 CPU, 1 GiB, 5 minutes;
30-second timeout per compile/run).

- The standard-listed `1800-2017` specifier is warned as unknown and ignored
  under both `-g2017` and `-g2023`.
- The standard-listed `1800-2023` specifier is warned as unknown and ignored
  under `-g2023`.
- The unrecognized `1800-9999` specifier compiles successfully with only a
  warning under both editions, instead of producing the required error.
- A `begin_keywords "1800-2012"` with no matching `end_keywords` compiles
  under `-g2023` with no diagnostic. The same source compiles under `-g2017`,
  where §22.14 does not state the 2023 pair requirement. This isolates the
  edition-specific unpaired-directive gap.

All source hashes and raw compiler stdout/stderr are in
[`remote-3604/`](remote-3604/); the probe sources are in
[`tests/1800_audit/c22/`](../../../tests/1800_audit/c22/).

## Dedupe and lead status

Open and closed issue searches for `begin_keywords`,
`22.14 keywords version_specifier`, and `begin_keywords unpaired end_keywords`
found no matching issue. No issue was filed by the runner. The audit lead has
not yet classified these results; the helper reports its daily cap reached.
