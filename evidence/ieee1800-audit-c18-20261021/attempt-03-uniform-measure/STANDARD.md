# §18.5.10 / §18.5.9 uniform distribution

IEEE 1800-2017 §18.5.10 and IEEE 1800-2023 §18.5.9 require: “The solver shall assure that the random values are selected to give a uniform value distribution over legal value combinations.” The following sentence defines that as every legal combination having the same probability of being the solution.

For `0 <= a < b < c <= 255`, the legal set contains `C(256,3) = 2,763,520` triples. Uniform selection gives expected means 63.25, 127.5, and 191.75; the expected number of samples with `a < 32` is about 662 of 2000. See `README.md` for the lead-provided 5σ windows.
