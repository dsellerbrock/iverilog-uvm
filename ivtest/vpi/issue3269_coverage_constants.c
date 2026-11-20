#include <sv_vpi_user.h>

/* All Annex M.2 coverage constants have nonzero values, so these checks
 * reject both undefined macros and incorrect values. */
#if vpiCoverageStart != 750 || vpiCoverageStop != 751 || \
    vpiCoverageReset != 752 || vpiCoverageCheck != 753 || \
    vpiCoverageMerge != 754 || vpiCoverageSave != 755
#error "Incorrect or missing coverage control constants"
#endif

#if vpiAssertCoverage != 760 || vpiFsmStateCoverage != 761 || \
    vpiStatementCoverage != 762 || vpiToggleCoverage != 763
#error "Incorrect or missing coverage type constants"
#endif

#if vpiCovered != 765 || vpiCoverMax != 766 || \
    vpiCoveredMax != 766 || vpiCoveredCount != 767
#error "Incorrect or missing coverage status constants"
#endif

#if vpiAssertAttemptCovered != 770 || vpiAssertSuccessCovered != 771 || \
    vpiAssertFailureCovered != 772 || vpiAssertVacuousSuccessCovered != 773 || \
    vpiAssertDisableCovered != 774 || vpiAssertKillCovered != 777
#error "Incorrect or missing assertion coverage status constants"
#endif

#if vpiFsmStates != 775 || vpiFsmStateExpression != 776 || \
    vpiFsm != 758 || vpiFsmHandle != 759
#error "Incorrect or missing FSM coverage constants"
#endif

static PLI_INT32 check_calltf(PLI_BYTE8 *data)
{
      (void)data;
      vpi_printf("PASSED\n");
      return 0;
}

static void register_check(void)
{
      s_vpi_systf_data tf = {0};
      tf.type = vpiSysTask;
      tf.tfname = "$check_coverage_constants";
      tf.calltf = check_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_check, 0 };
