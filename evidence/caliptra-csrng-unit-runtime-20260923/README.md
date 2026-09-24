# Pinned CSRNG unit runtime probe

Pinned Caliptra is v2.1.2 (`49370266d12cb0c4a8f71b3a0ff7e54ba7d4866e`). The release's README gives VCS as the generic official Unit Test flow: compile `src/csrng/config/csrng_tb.vf` with `csrng_tb` as top, then run the simulator. The IP also ships `src/csrng/tb/Makefile` with a Verilator C++ harness target. This probe ran the already compiled full filelist image under Icarus/VVP using the standards-correct package-first and missing include-path-only disposable `.vf` corrections documented in the neighboring header-closure evidence.

No external vectors or `$readmem*` files are required by this CSRNG testbench: it embeds the entropy seed and expected output words and directly calls `run_entropy_source_seed_test()` and `run_smoke_test()`. Therefore, the bounded runtime was runnable without generating or inventing inputs.

## Runtime result

The exact command/environment, timeout, exit, and elapsed time are in [`command.json`](command.json). VVP ran for 7.497 seconds and exited 0 before the 60-second bound. It emitted one `* TESTCASE PASSED`, no `* TESTCASE FAILED`, no `Got/Want` mismatch diagnostic, and no stderr. All 36 statically expected `ADDR_GENBITS` comparisons appeared as 36 observed `GENBITS` reads.

There were 252 simulator warnings at `src/csrng/rtl/csrng_reg_top.sv:2386` (`unique case (addr_hit): value is unhandled`); the first is at time 0. The directed testbench's mismatch counter remained zero and it printed its pass marker. The testbench also prints `All 00 test cases completed successfully`: `tc_ctr` is initialized but never incremented, so that printed count is not a coverage count and is called out rather than interpreted as 0 tests exercised.

The raw output is [`vvp.stdout`](vvp.stdout); stderr is empty. [`result.json`](result.json) includes source, binary, and output hashes plus checker counts. This is one standalone unit-test runtime under Icarus, not full DV qualification and not a VCS equivalence claim. No pinned source or shared installation was changed; this evidence folder contains only command metadata, logs, and result summary, with no generated build products.
