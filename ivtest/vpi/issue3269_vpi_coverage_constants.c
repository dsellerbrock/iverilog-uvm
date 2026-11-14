#include <sv_vpi_user.h>

/* Refer to each name as a C expression so absent definitions fail compilation. */
typedef char check_vpiCoverageStart[(vpiCoverageStart == 750) ? 1 : -1];
typedef char check_vpiCoverageStop[(vpiCoverageStop == 751) ? 1 : -1];
typedef char check_vpiCoverageReset[(vpiCoverageReset == 752) ? 1 : -1];
typedef char check_vpiCoverageCheck[(vpiCoverageCheck == 753) ? 1 : -1];
typedef char check_vpiCoverageMerge[(vpiCoverageMerge == 754) ? 1 : -1];
typedef char check_vpiCoverageSave[(vpiCoverageSave == 755) ? 1 : -1];
typedef char check_vpiAssertCoverage[(vpiAssertCoverage == 760) ? 1 : -1];
typedef char check_vpiFsmStateCoverage[(vpiFsmStateCoverage == 761) ? 1 : -1];
typedef char check_vpiStatementCoverage[(vpiStatementCoverage == 762) ? 1 : -1];
typedef char check_vpiToggleCoverage[(vpiToggleCoverage == 763) ? 1 : -1];
typedef char check_vpiCovered[(vpiCovered == 765) ? 1 : -1];
typedef char check_vpiCoverMax[(vpiCoverMax == 766) ? 1 : -1];
typedef char check_vpiCoveredMax[(vpiCoveredMax == 766) ? 1 : -1];
typedef char check_vpiCoveredCount[(vpiCoveredCount == 767) ? 1 : -1];
typedef char check_vpiAssertAttemptCovered[(vpiAssertAttemptCovered == 770) ? 1 : -1];
typedef char check_vpiAssertSuccessCovered[(vpiAssertSuccessCovered == 771) ? 1 : -1];
typedef char check_vpiAssertFailureCovered[(vpiAssertFailureCovered == 772) ? 1 : -1];
typedef char check_vpiAssertVacuousSuccessCovered[(vpiAssertVacuousSuccessCovered == 773) ? 1 : -1];
typedef char check_vpiAssertDisableCovered[(vpiAssertDisableCovered == 774) ? 1 : -1];
typedef char check_vpiAssertKillCovered[(vpiAssertKillCovered == 777) ? 1 : -1];
typedef char check_vpiFsmStates[(vpiFsmStates == 775) ? 1 : -1];
typedef char check_vpiFsmStateExpression[(vpiFsmStateExpression == 776) ? 1 : -1];
typedef char check_vpiFsm[(vpiFsm == 758) ? 1 : -1];
typedef char check_vpiFsmHandle[(vpiFsmHandle == 759) ? 1 : -1];

static PLI_INT32 check_coverage_constants(PLI_BYTE8 *data)
{
    (void)data;
    vpi_printf("VPI coverage constants PASSED\nPASSED\n");
    return 0;
}

static void register_check(void)
{
    s_vpi_systf_data data = {0};
    data.type = vpiSysTask;
    data.tfname = "$check_coverage_constants";
    data.calltf = check_coverage_constants;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_check, 0 };
