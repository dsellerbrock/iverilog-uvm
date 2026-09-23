#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <string.h>

static int failures = 0;
static int bad = 0;

static PLI_INT32 on_failure(PLI_INT32 reason, p_vpi_time event_time,
                            vpiHandle assertion, p_vpi_attempt_info info,
                            PLI_BYTE8 *user_data)
{
      unsigned long event = event_time->low;
      unsigned long start = info->attemptStartTime.low;
      (void)reason; (void)assertion; (void)user_data;
      failures++;
      if ((failures == 1 && (event != 25000 || start != 5000)) ||
          (failures == 2 && (event != 60000 || start != 60000)) ||
          failures > 2)
            bad = 1;
      return 0;
}

static PLI_INT32 setup(PLI_BYTE8 *user_data)
{
      vpiHandle it = vpi_iterate(vpiAssertion, 0);
      vpiHandle assertion;
      (void)user_data;
      while (it && (assertion = vpi_scan(it)))
            vpi_register_assertion_cb(assertion, cbAssertionFailure,
                                      on_failure, 0);
      return 0;
}

static PLI_INT32 check(PLI_BYTE8 *user_data)
{
      (void)user_data;
      if (failures == 2 && !bad) vpi_printf("PASSED\n");
      else vpi_printf("FAILED: callbacks=%d bad=%d\n", failures, bad);
      return 0;
}

static void register_tasks(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$m12ai_setup";
      tf.calltf = setup;
      vpi_register_systf(&tf);
      tf.tfname = "$m12ai_check";
      tf.calltf = check;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
