Clause: IEEE 1800-2017/2023 §19.8, Table 19-5.

Requirement: `set_inst_name(string)` sets the coverage instance name to the supplied string.

Probe: `evidence/ieee1800-audit-c19b-20261017/attempt-02/input/p19_08_set_inst_name.sv`, compiled/run with `-g2017` and `-g2023` using Icarus 13.0 devel at source `9b5fad2af`. Raw output: `evidence/ieee1800-audit-c19b-20261017/attempt-02/results/combined.txt`.

Observed: the call is ignored with an `unknown task` warning and `option.name` remains blank.

Expected: after `g.set_inst_name("inst_x")`, `g.option.name == "inst_x"`.
