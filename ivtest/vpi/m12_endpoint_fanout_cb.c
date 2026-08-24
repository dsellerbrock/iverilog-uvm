#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <stdio.h>
#include <string.h>

static int n_success = 0;
static int n_failure = 0;

static PLI_INT32 assertion_cb(PLI_INT32 reason, p_vpi_time time,
                             vpiHandle assertion,
                             p_vpi_attempt_info info, PLI_BYTE8 *user_data)
{
      (void)time;
      (void)assertion;
      (void)info;
      (void)user_data;
      if (reason == cbAssertionSuccess) n_success += 1;
      else if (reason == cbAssertionFailure) n_failure += 1;
      return 0;
}

static PLI_INT32 setup_calltf(PLI_BYTE8 *name)
{
      vpiHandle iterator, assertion;
      (void)name;
      iterator = vpi_iterate(vpiAssertion, NULL);
      if (iterator) while ((assertion = vpi_scan(iterator))) {
            vpi_register_assertion_cb(
                  assertion, cbAssertionSuccess, assertion_cb, 0);
            vpi_register_assertion_cb(
                  assertion, cbAssertionFailure, assertion_cb, 0);
      }
      return 0;
}

static PLI_INT32 check_calltf(PLI_BYTE8 *name)
{
      vpiHandle call, iterator, argument;
      s_vpi_value value;
      int expected_success = -1, expected_failure = -1;
      (void)name;
      call = vpi_handle(vpiSysTfCall, 0);
      iterator = vpi_iterate(vpiArgument, call);
      if (iterator) {
            argument = vpi_scan(iterator);
            if (argument) {
                  value.format = vpiIntVal;
                  vpi_get_value(argument, &value);
                  expected_success = value.value.integer;
            }
            argument = vpi_scan(iterator);
            if (argument) {
                  value.format = vpiIntVal;
                  vpi_get_value(argument, &value);
                  expected_failure = value.value.integer;
                  vpi_free_object(iterator);
            }
      }
      if (n_success == expected_success && n_failure == expected_failure)
            vpi_printf("PASS: endpoint fanout callbacks (success=%d failure=%d)\n",
                       n_success, n_failure);
      else
            vpi_printf("FAIL: endpoint fanout callbacks got %d/%d expected %d/%d\n",
                       n_success, n_failure,
                       expected_success, expected_failure);
      return 0;
}

static void register_all(void)
{
      s_vpi_systf_data tf;

      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$setup_endpoint_fanout_cb";
      tf.calltf = setup_calltf;
      vpi_register_systf(&tf);

      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$check_endpoint_fanout_cb";
      tf.calltf = check_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_all, 0 };
