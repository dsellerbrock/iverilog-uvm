#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <string.h>

static PLI_INT32 assertion_cb(PLI_INT32 reason, p_vpi_time time,
                             vpiHandle assertion,
                             p_vpi_attempt_info info,
                             PLI_BYTE8 *user_data)
{
      (void)assertion;
      (void)info;
      (void)user_data;
      if (reason == cbAssertionFailure)
            vpi_printf("FAILURE t=%d\n", (int)time->low);
      else if (reason == cbAssertionStepSuccess)
            vpi_printf("STEP_OK t=%d\n", (int)time->low);
      else if (reason == cbAssertionStepFailure)
            vpi_printf("STEP_FAIL t=%d\n", (int)time->low);
      return 0;
}

static PLI_INT32 setup_calltf(PLI_BYTE8 *name)
{
      vpiHandle iterator, assertion;
      (void)name;
      iterator = vpi_iterate(vpiAssertion, NULL);
      if (iterator) while ((assertion = vpi_scan(iterator))) {
            vpi_register_assertion_cb(
                  assertion, cbAssertionFailure, assertion_cb, 0);
            vpi_register_assertion_cb(
                  assertion, cbAssertionStepSuccess, assertion_cb, 0);
            vpi_register_assertion_cb(
                  assertion, cbAssertionStepFailure, assertion_cb, 0);
      }
      return 0;
}

static void register_all(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$setup_endpoint_fanout_step";
      tf.calltf = setup_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_all, 0 };
