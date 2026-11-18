#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

static PLI_INT32 report_attempts(p_cb_data cb)
{
      vpiHandle it = vpi_iterate(vpiAssertion, 0);
      vpiHandle assertion;
      (void)cb;

      while (it && (assertion = vpi_scan(it))) {
            const char *name = vpi_get_str(vpiName, assertion);
            if (name && strcmp(name, "check_p") == 0)
                  vpi_printf("procedural starts=%d successes=%d\n",
                             vpi_get(vpiAssertAttemptCovered, assertion),
                             vpi_get(vpiAssertSuccessCovered, assertion));
      }
      return 0;
}

static void register_report(void)
{
      s_cb_data cb = {0};
      cb.reason = cbEndOfSimulation;
      cb.cb_rtn = report_attempts;
      vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = {register_report, 0};
