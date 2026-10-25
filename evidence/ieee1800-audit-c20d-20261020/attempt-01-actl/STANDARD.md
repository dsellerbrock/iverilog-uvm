# IEEE 1800 assertion control tasks

IEEE 1800-2017 §20.12 and 1800-2023 §20.11 give `$assertcontrol` the ordered arguments `control_type`, optional `assertion_type`, optional `directive_type`, `levels`, then a list of scopes or individual assertions. Table 20-5 in both editions includes these relevant control values: `3 On`, `4 Off`, `5 Kill`, `8 FailOn`, `9 FailOff`.

The standards say `$asserton(levels[, list])` is equivalent to `$assertcontrol(3, 15, 7, levels[, list])`; `$assertoff` uses control value 4; `$assertkill` uses control value 5. Thus the probe's 8/9 calls change only failure-action execution, leaving assertion evaluation active. Its argument order follows the syntax above: control type, assertion type 15, directive type 7, levels 0, and targeted assertions `a1` and `a2`.

The probe separates a concurrent property (`a1`) from a simple immediate assertion (`a2`), then controls both by name. A true concurrent property (`a3`) is an unaffected pass-action control.

Text sources: local IEEE 1800-2017 §20.12 and Table 20-5 (printed pp. 608–609); local IEEE 1800-2023 §20.11 and Table 20-5 (printed pp. 637–638). The relevant control-type table entries and task equivalences are the same in both editions.
