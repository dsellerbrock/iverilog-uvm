#include <string.h>
#include <vpi_user.h>

#ifndef vpiCoverageStart
#define vpiCoverageStart 750
#endif
#ifndef vpiCoverageCheck
#define vpiCoverageCheck 753
#endif
#ifndef vpiToggleCoverage
#define vpiToggleCoverage 763
#endif

static void report_error(const char *action)
{
      s_vpi_error_info info = {0};
      PLI_INT32 level = vpi_chk_error(&info);

      vpi_printf("%s_error_level=%d\n", action, level);
      if (level)
            vpi_printf("%s_error_message=%s\n", action,
                       info.message ? info.message : "<null>");
}

static PLI_INT32 probe_calltf(PLI_BYTE8 *user_data)
{
      vpiHandle module = vpi_handle_by_name("p40", NULL);
      PLI_INT32 result;

      (void)user_data;
      if (!module) {
            vpi_printf("module_handle=null\n");
            return 0;
      }

      result = vpi_control(vpiCoverageCheck, vpiToggleCoverage, module);
      vpi_printf("coverage_check=%d\n", result);
      report_error("coverage_check");

      result = vpi_get(vpiToggleCoverage, module);
      vpi_printf("toggle_coverage=%d\n", result);
      report_error("toggle_coverage");

      result = vpi_control(vpiCoverageStart, vpiToggleCoverage, module);
      vpi_printf("coverage_start=%d\n", result);
      report_error("coverage_start");
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf = {0};
      tf.type = vpiSysTask;
      tf.tfname = "$probe40";
      tf.calltf = probe_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
