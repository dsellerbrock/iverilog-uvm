# IEEE 1800 clause 19 probe batch C — initial run

Slurm job 2263 on DAN-DESKTOP, 1 CPU, 1 GiB; Icarus 13.0 devel from source/toolchain revision `9b5fad2af`. Raw output and per-case compile logs are preserved here.

- Clocking-event sampling passes in both editions: 50% over two separate posedges and 25% when two samples occur in one time slot with `at_least=2`.
- The two-argument coverpoint `get_inst_coverage` form fails elaboration as an unknown task. The type-level two-argument file is blocked by #627's missing type-level `get_coverage` methods.
- Implicit coverpoint name lookup through `g.v` fails elaboration with “no named coverpoint or cross `v`”.
- The 2023 `covergroup extends` positive and undefined-base negative both fail with generic syntax errors at the `extends` declaration; the compiler does not yet distinguish a valid extension from an undefined base. The 2017 positive is rejected as expected.
- The script's `EXPECTED_UNDEFINED_BASE_DIAGNOSTIC` marker is a false positive: its grep matched `undefined` in the source filename, while the actual 2023 diagnostic is a generic syntax error. Attempt 02 uses a corrected diagnostic filter and bisection probes.
