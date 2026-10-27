# IEEE 1800 coverage system functions

## Clause 20 and system-function syntax

IEEE 1800-2017 §20.14 (p. 615) and 1800-2023 §20.13 (p. 644) list `$coverage_control`, `$coverage_get_max`, and `$coverage_get`, referring to §40.3.2 for their behavior. The syntax there is:

```text
$coverage_control(control_constant, coverage_type, scope_def, modules_or_instance)
$coverage_get_max(coverage_type, scope_def, modules_or_instance)
$coverage_get(coverage_type, scope_def, modules_or_instance)
```

The same §20 sections point to §19.9 for `$get_coverage()`. IEEE 1800-2017 §19.9 (p. 584) and 1800-2023 §19.9 (p. 612) say it returns a real from 0 to 100 for overall coverage of all covergroup types.

## SV_COV values and unavailable-coverage results

`SV_COV_*` are predefined macros in §40.3.1 of both editions (2017 p. 1121; 2023 p. 1156):

```text
SV_COV_START=0       SV_COV_STOP=1        SV_COV_RESET=2       SV_COV_CHECK=3
SV_COV_MODULE=10     SV_COV_HIER=11
SV_COV_ASSERTION=20  SV_COV_FSM_STATE=21  SV_COV_STATEMENT=22  SV_COV_TOGGLE=23
SV_COV_OVERFLOW=-2   SV_COV_ERROR=-1      SV_COV_NOCOV=0       SV_COV_OK=1
SV_COV_PARTIAL=2
```

Under §40.3.2.1 / Table 40-1, `$coverage_control(SV_COV_CHECK, ...)` returns `SV_COV_NOCOV` when no coverage is available in the requested hierarchy. §40.3.2.2 and §40.3.2.3 specify integer result 0 (`SV_COV_NOCOV`) for `$coverage_get_max` and `$coverage_get` when that coverage type is unavailable.

The standard's Annex M, `sv_vpi_user.h`, does not define `SV_COV_*`; it defines the corresponding VPI API properties. The coverage-control values on printed p. 1295 (2017) and p. 1333 (2023) are `vpiCoverageStart=750`, `vpiCoverageStop=751`, `vpiCoverageReset=752`, `vpiCoverageCheck=753`, `vpiCoverageMerge=754`, and `vpiCoverageSave=755`. The coverage-type properties are `vpiAssertCoverage=760`, `vpiFsmStateCoverage=761`, `vpiStatementCoverage=762`, `vpiToggleCoverage=763`; status properties are `vpiCovered=765`, `vpiCoverMax=vpiCoveredMax=766`, and `vpiCoveredCount=767`. The SystemVerilog macros used by the probe are taken from §40.3.1, where they are actually defined.
