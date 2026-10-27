# §18 function-result constraint depth

Five isolated probes cover a non-rand state-variable argument (G1), the #844 form (G2), its inline-constraint variant (G3), an always-satisfiable additional bound (G4), and a function result in an implication (G5). Each source is compiled and run separately under `-g2017` and `-g2023`; every run has a 60-second timeout. See `STANDARD.md` and `DEDUPE.md`.

Slurm job 3719 uses 1 CPU, 1 GiB, and a 10-minute limit on DAN-DESKTOP. It stages the five sources from branch `m7-1800-audit-c08`, HEAD `27f53df2400f309a7b0d8e5ed5fc7ff9b0e0566e`, into a fresh run directory; the repository was already dirty, so the staged inputs are listed by SHA-256 in `INPUT-SHA256SUMS.txt`. Toolchain: Icarus 13.0-devel at `/home/dsell/toolchains/iverilog-uvm-main-cc25756d187314742d347267c2a513b3e640a7fb`, commit `cc25756d`; `iverilog` SHA-256 `87bb417df23d260bcfde3fb372b4a80eaad69e4fd2eea1ffb8b0eff10f7af08e`, `vvp` SHA-256 `dfc193c466a70a0917a16ab4198a111de616657d6004de79456db2a4b603b437`.

The expected G2/G3 range is 1–27 successes of 200 under the standard's implicit function-argument ordering; G1, G4 and G5 must all succeed in every trial. Raw output is in `results/` and `slurm-3719.out` after collection. G1/G4 match expectations, G2/G3 each return 0/200, and G5 returns 8/200 in both editions; see `RESULT.md` for the lead check on G5's unexpected count.
