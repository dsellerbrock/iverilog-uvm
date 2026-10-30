#include <vpi_user.h>

#ifndef vpiCoverageMerge
#define vpiCoverageMerge 754
#endif
#ifndef vpiAssertCoverage
#define vpiAssertCoverage 760
#endif

static PLI_INT32 issue1593_calltf(PLI_BYTE8 *user_data)
{
      PLI_INT32 result;
      (void)user_data;

      result = vpi_control(vpiCoverageMerge, vpiAssertCoverage, "missing");
      vpi_printf("coverage_merge=%d\n", result);
      return 0;
}

static void issue1593_register(void)
{
      s_vpi_systf_data tf = {0};
      tf.type = vpiSysTask;
      tf.tfname = "$issue1593_coverage_merge";
      tf.calltf = issue1593_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { issue1593_register, 0 };
