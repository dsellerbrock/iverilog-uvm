# IEEE 1800 §18.6.2–18.6.3 supplementary audit — 2026-10-17

This follow-up covers the §18.6.2 and §18.6.3 behaviors left unprobed by
[c18a](../ieee1800-audit-c18a-20261017/README.md), for IEEE 1800-2017
(pp. 529–530) and IEEE 1800-2023 (p. 551). The lead's review of the clauses
found no relevant text changes between editions.

`p18_06_supplement.sv` checks that `pre_randomize` runs before solving and on
an infeasible call, `post_randomize` sees assigned values, hook dispatch uses
the dynamic type, and hooks run for nested rand object members. It also
checks that a static rand variable changes across calls and is visible through
another instance, and that equal `srandom` seeds produce matching sequences.
`neg/n18_06_task_pre_randomize.sv` checks that a randomization hook cannot be
a task. The earlier `neg/n18_06_override_randomize.sv` checks that
`randomize()` cannot be overridden.

Slurm job 2245 ran on DAN-DESKTOP (`Linux x86_64`) using the protected
`/home/dsell/toolchains/iverilog-uvm-9b5fad2afb4104caa816b257d5bccc40f01b8c66`
toolchain built from source `9b5fad2af`. Current compute policy allows Slurm;
the job was 1 CPU/1 GiB and did not rebuild the compiler. GCC was
`15.2.0-16ubuntu1`. Each of the six positive assertions passed in both modes;
the task-form hook was rejected with the expected diagnostic in both modes.
`script.exit` is `exit=0`.

The raw result, per-test output, tool versions, and hashes are in
[`results/`](results/). The iverilog and vvp SHA256 values are respectively
`6cd9749cb1e981820f64fdc737ae458bf6c46e3fcad8927afaf92649ee9a3288` and
`c2474d2a745aa7d896885202314a5244ee26af56a32dda59a6c8fbd3ba362e3a`.
These differ from c18a's freshly built binary hashes; both runs used source
commit `9b5fad2af`, and the c18b run's exact executable hashes are retained
with its output.
