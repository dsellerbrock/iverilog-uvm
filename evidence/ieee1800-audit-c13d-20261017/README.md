# IEEE 1800 clause 13 probe c13d

Probe scope: §§13.3–13.3.2 task directions, lifetime and concurrent activation, plus the remaining §13.4.3 constant-function restrictions. References: 2017 §§13.3–13.3.2 pp.319–323 and §13.4.3 p.327; 2023 §§13.3–13.3.2 pp.335–339 and §13.4.3 pp.345–346.

Both attempts use the protected Icarus 13.0 devel build from source `9b5fad2afb4104caa816b257d5bccc40f01b8c66` on DAN-DESKTOP.

Attempt 01 used 1 CPU and 1 GiB. It found expected rejections for hierarchical references to automatic task locals and NBA/force writes to automatic variables. The task-direction test initially expected two untyped formals to be 32-bit integers. The correct default is 1-bit logic, so the constants 3 and 4 arrive as 1 and 0. The same run accepted `$monitor(a)` for an automatic task local (G28) and a `fork` inside a constant function (G29). Other constant-function restrictions—hierarchical/non-local references, `$random`, and NBA—were rejected with relevant diagnostics. Constant-function probes computed `Q=4` and `R=5` in both editions; the embedded `$display` did not execute during constant evaluation.

Attempt 02 corrected the task test to print the observed values and expect `u=1, v=0`. Both `-g2017` and `-g2023` pass the direction/default-type, return, empty-task, static/automatic output lifetime, local-static, and concurrent-activation checks. Raw results, source/script hashes, and the Slurm completion record are under [attempt 02](attempt-02/).

Confirmed gaps: [#637](https://github.com/dsellerbrock/iverilog-uvm/issues/637) for automatic variables traced by `$monitor`/`$dumpvars`; [#638](https://github.com/dsellerbrock/iverilog-uvm/issues/638) for fork constructs in constant functions.
