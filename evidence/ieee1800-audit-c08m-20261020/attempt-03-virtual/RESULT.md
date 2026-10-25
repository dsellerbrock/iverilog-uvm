# Attempt 03 result — behavior reproduced, expected-output harness mismatch

Slurm job 3498 completed on DAN-DESKTOP with 1 CPU and 1 GiB. The corrected
positive source compiled in both editions and produced all expected semantic
lines:

```text
V1 C C
V2 A2 C2
AB1 5
AB2 x
POLY Ether Token GPS
```

The exact-output check reported a harness mismatch because Icarus appends a
`$finish called at 0` line to the captured output. The probe now lets simulation
end naturally; attempt 04 repeats the paired run with the same observable
expectation.

The four §8.21 negatives otherwise matched expectations in both editions:
direct abstract construction, a pure method in a non-virtual class, and a
pure-method declaration with a body were rejected. The subclass
`MissingImplementation` was accepted, constructed, and its inherited pure
method call printed `MISSING x` in both editions. This is a candidate §8.21
gap pending audit-lead classification. Exact compiler hashes and raw logs are
in `results-3498.tar.gz`; issue-search results are recorded in
`../attempt-02-virtual/dedupe-open-closed.txt`.
