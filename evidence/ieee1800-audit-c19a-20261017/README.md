# IEEE 1800 clause 19 probe batch A — 2026-10-17

Lead-selected scope: §19.5.1 bin declarations/distribution and §19.11.1
coverage computation in both editions, plus the 2023 tolerance-range syntax
from §19.5.1. The probes are [`p19_05_bins_cov.sv`](../../tests/1800_audit/c19/p19_05_bins_cov.sv)
and [`p19_05_tolerance_2023.sv`](../../tests/1800_audit/c19/p19_05_tolerance_2023.sv).

## Environment

- Host: DAN-DESKTOP, Linux x86_64, WSL2; Slurm jobs 2254, 2256, and 2258.
- Compiler: Icarus 13.0 devel, source revision `9b5fad2af`, protected install
  `/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66/install`.
- Compiler SHA-256: `6cd9749cb1e981820f64fdc737ae458bf6c46e3fcad8927afaf92649ee9a3288`.
- VVP SHA-256: `c2474d2a745aa7d896885202314a5244ee26af56a32dda59a6c8fbd3ba362e3a`.
- Each compile had a 60 s timeout; each simulation had a 30 s timeout.
- Raw combined outputs, command scripts, generated bisection sources, and
  per-case logs are preserved in [`attempt-01`](attempt-01/),
  [`attempt-02`](attempt-02/), and [`attempt-03`](attempt-03/).

## Results

- `p19_05_tolerance_2023.sv` was rejected under `-g2017` as expected. Under
  `-g2023`, it compiled and printed `PASS` for both outside and inside cases;
  measured coverage was 0.0% and 66.666667% respectively.
- The full §19.5.1 probe was rejected under both editions at
  `bins others[] = default;`. That is the same array-of-default-bins form
  shown in IEEE 1800-2017 §19.5.1 (p. 561) and IEEE 1800-2023 §19.5.1
  (p. 585). A bisection with the declaration removed compiled and ran in both
  editions; replacing it with `bins others = default;` also compiled and ran.
  The first no-default bisection edit was invalid because its inline comment
  hid the closing covergroup brace; it is retained in attempt 02 and not used
  as behavior evidence.
- In both valid variants and editions, reported coverage was 7.142857% for
  the first covergroup and 33.333333% for the empty-bin case. Fixed-bin
  remainder distribution, duplicate retention, iff gating, zero-denominator
  handling, and zero item weights printed `PASS`.
- The optional `get_inst_coverage(ref int, ref int)` outputs remained `n=0,
  d=0` after sampling. This caused the two explicit checks to print `FAIL`
  under both editions, although the scalar coverage percentages matched the
  expected 5/70 and 1/3 ratios. IEEE 1800-2017/2023 Table 19-5 and §19.11.1
  require these output arguments to report covered and defined bin counts.

Lead classification: §19.5 is implemented for the tested `iff` guard subset;
§19.5.1 is partial because array default-bin syntax is rejected (#623);
§19.8 and §19.11 are partial because the two-argument instance-coverage form
does not assign numerator and denominator outputs (#622); §19.11.1 is
implemented for the tested scalar coverage arithmetic subset. §19.1–.4,
§19.6–.7, and §19.9–.10 remain unassessed. The full clause matrix records
these statuses and links each tested subset to its probe and evidence.
