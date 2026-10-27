# IEEE 1800-2023 §8.20 method override specifier probe (Slurm job 3503)

Host DAN-DESKTOP; Icarus 13.0-devel source `cc25756d1`; tool hashes and raw logs are in `results-3503.tar.gz`.

Under `-g2023`, all five Example 3 declarations marked “NOT OK” and the three extra negatives were rejected (compile rc=1). Under `-g2017`, the legal file was rejected as expected for 2023 syntax. The positive control did not compile: the literal standard Example 3 uses `class base;` with a `pure virtual function`, and Icarus correctly diagnosed that a pure virtual method may only be declared in a virtual class.

The tech lead compared IEEE 1800-2017/2023 §8.21 and confirmed the Example 3 `class base;` spelling is an editorial slip; it must be `virtual class base;`. This is a source correction, not a conformance gap. The corrected positive is rerun in attempt 02. The direct #455 reread and all-state dedupe are preserved beside this result.
