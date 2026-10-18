# IEEE 1800 clause 19 probe batch B — 2026-10-17

Lead-selected scope: §19.3/§19.4 covergroup declaration/use and the remaining §19.8 predefined methods. Three Slurm attempts used protected Icarus 13.0 devel source/toolchain revision `9b5fad2af`; raw inputs, compiler hashes, and logs are preserved under `attempt-01` through `attempt-03`.

## Results so far

- Covergroup formal arguments, `ref` sampling, and per-instance isolation pass in both editions; covergroup `sample(args)`, `stop()`, and `start()` also pass in both.
- Output-direction covergroup formals are rejected under both editions with an explicit §19.3 diagnostic.
- Coverpoint instance `get_inst_coverage()` returns the expected 50% in both editions when the coverpoint has an explicit identifier.
- Type-level `get_coverage()` (covergroup and coverpoint) fails elaboration in both editions.
- `set_inst_name()` is silently ignored as an unknown task; `option.name` remains empty.
- A block-event coverage declaration `@@(end t1)` fails parsing and triggers a pform assertion in both editions.
- An embedded covergroup event tied to a local member records the first of two changed bins, then fails to record the second. The compiler warns that the event expression was skipped.
- Assigning an embedded covergroup variable outside `new` compiles and executes; the instance coverage resets from 50% to 0%. This contradicts §19.4.
- `covergroup extends` outside a class is rejected by a generic syntax error in both editions; the 2023 rejection reason is not distinguished from missing `extends` parsing.

Attempt 01 is the exact lead-provided composite probe. Its compile failures triggered bisection. Attempt 02 established ref/input behavior and sample/stop/start but had one omitted assignment input and an unnamed-coverpoint mistake; those cases are not counted. Attempt 03 corrected the names and assignment execution. See each attempt README for scope and limitations.

Lead classification: §19.3, §19.4, and §19.8 are partial; the clocking-event runtime and two-argument coverpoint/type totals remain inconclusive. §19.8.1 sample arguments pass. The lead duplicate searches found no matching reports for the five gaps; issues were filed as [#624](https://github.com/dsellerbrock/iverilog-uvm/issues/624), [#625](https://github.com/dsellerbrock/iverilog-uvm/issues/625), [#626](https://github.com/dsellerbrock/iverilog-uvm/issues/626), [#627](https://github.com/dsellerbrock/iverilog-uvm/issues/627), and [#628](https://github.com/dsellerbrock/iverilog-uvm/issues/628).
