# IEEE 1800 probabilistic distribution functions

- IEEE 1800-2017 §§20.15.1–20.15.2 describe `$random` and the distribution functions. §20.15.2 says calls with the same seed are repeatable and refers to Annex N for the specified algorithm. Annex N.2 is printed on pp. 1298–1305.
- IEEE 1800-2023 §§20.14.1–20.14.2 carry the corresponding requirements. Annex N.2 is printed on pp. 1337–1344.
- The shared requirement is: “The system functions shall always return the same value given the same seed.” The argument constraints are positive mean/degrees/k for the functions that require them; this probe uses valid values.
- Comparing the extracted Annex N.2 bodies shows identical algorithm statements in both editions; only the edition banner and the hyphenation in one explanatory comment differ.
- The Annex source spells its state type `long`, assumes the historical 32-bit width, and uses signed wraparound in the LCG. The oracle preserves the source while mapping that assumed width with `#define long int32_t`, setting `LONG_MIN/MAX` to the 32-bit limits, and compiling with `-fwrapv`. This avoids host-ABI drift on 64-bit DAN-DESKTOP and matches the fixed 32-bit seed stream used by the simulator implementation.

The paired SV probe starts each function from integer seed 1, records five results and the updated seed, under `-g2017` and `-g2023`. It covers `$random`, `$dist_uniform(seed,0,100)`, `$dist_normal(seed,0,10)`, `$dist_exponential(seed,10)`, `$dist_poisson(seed,5)`, `$dist_chi_square(seed,3)`, `$dist_t(seed,4)`, and `$dist_erlang(seed,2,10)`.
