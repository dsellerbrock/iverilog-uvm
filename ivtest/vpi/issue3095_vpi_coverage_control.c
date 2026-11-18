#include <sv_vpi_user.h>

/* Keep the probe buildable against headers from before the runtime fix. */
#ifndef vpiCoverageStart
#define vpiCoverageStart     750
#define vpiCoverageStop      751
#define vpiCoverageReset     752
#define vpiCoverageCheck     753
#define vpiAssertCoverage    760
#define vpiFsmStateCoverage  761
#define vpiStatementCoverage 762
#define vpiToggleCoverage    763
#endif

static void report_control(const char *label, PLI_INT32 op, PLI_INT32 type,
                           vpiHandle handle)
{
      s_vpi_error_info info;
      PLI_INT32 result = vpi_control(op, type, handle);
      PLI_INT32 error = vpi_chk_error(&info);
      vpi_printf("%s=%d error=%d\n", label, result, error);
}

static PLI_INT32 probe(PLI_BYTE8 *user_data)
{
      static const PLI_INT32 types[] = { vpiAssertCoverage, vpiFsmStateCoverage,
            vpiStatementCoverage, vpiToggleCoverage };
      vpiHandle instance = vpi_handle_by_name("top.u", 0);
      vpiHandle signal = vpi_handle_by_name("top.u.signal", 0);
      unsigned i;
      (void)user_data;

      if (!instance || !signal) {
            vpi_printf("Missing coverage test handle\n");
            return 0;
      }

      for (i = 0; i < sizeof types / sizeof types[0]; i++) {
            PLI_INT32 type = types[i];
            PLI_INT32 start = vpi_control(vpiCoverageStart, type, instance);
            PLI_INT32 stop = vpi_control(vpiCoverageStop, type, instance);
            PLI_INT32 reset = vpi_control(vpiCoverageReset, type, instance);
            PLI_INT32 check = vpi_control(vpiCoverageCheck, type, instance);
            vpi_printf("type=%d start=%d stop=%d reset=%d check=%d\n",
                       type, start, stop, reset, check);
      }

      report_control("bad_type", vpiCoverageStop, 0, instance);
      report_control("null_handle", vpiCoverageStart, vpiToggleCoverage, 0);
      report_control("signal_handle", vpiCoverageReset, vpiToggleCoverage, signal);
      report_control("valid_check", vpiCoverageCheck, vpiToggleCoverage, instance);
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf = {0};
      tf.type = vpiSysTask;
      tf.tfname = "$probe_coverage_control";
      tf.calltf = probe;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
