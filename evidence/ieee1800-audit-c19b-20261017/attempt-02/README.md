# IEEE 1800 clause 19 probe batch B — bisection attempt 02

Slurm job 2260 on DAN-DESKTOP, 1 CPU, 1 GiB. The ref/input-argument probe and the §19.8.1 `sample`, `stop`, and `start` probe compiled and passed in both editions. The embedded-covergroup probe compiled in both, reached 50% after its first event, then failed to record the second event. The §19.3 block-event probe failed parsing and triggered a pform assertion in both editions. `set_inst_name` was accepted only as an ignored unknown-task warning; `option.name` remained empty.

This attempt is not conclusive for coverpoint/type-level coverage methods: the bisection source used method names for an unnamed coverpoint, so attempt 03 adds explicit coverpoint identifiers. It is also not evidence for the embedded-covergroup assignment restriction: the `n19_04_assign_outside_new.sv` input was accidentally omitted from the staged run directory. The resulting “No such file” rejection is a harness setup error, not a compiler result. The output-direction negative was rejected explicitly by the compiler. The outside-class `extends` negative was rejected with generic syntax errors.

Raw output is in `results/combined.txt`; per-case logs are beside it. Attempt 03 corrects both bisection inputs.
