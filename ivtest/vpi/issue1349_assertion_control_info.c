#include <vpi_user.h>
#include <sv_vpi_user.h>

static int callbacks;
static int nonnull_info;

static PLI_INT32 control_cb(PLI_INT32 reason, p_vpi_time time,
                            vpiHandle assertion, p_vpi_attempt_info info,
                            PLI_BYTE8 *user_data)
{
      (void)time;
      (void)assertion;
      (void)reason;
      (void)user_data;
      callbacks += 1;
      if (info != 0) nonnull_info += 1;
      return 0;
}

static PLI_INT32 setup_calltf(PLI_BYTE8 *name)
{
      vpiHandle iterator, assertion;
      (void)name;
      iterator = vpi_iterate(vpiAssertion, 0);
      while (iterator && (assertion = vpi_scan(iterator))) {
            vpi_register_assertion_cb(assertion, cbAssertionDisable,
                                      control_cb, 0);
            vpi_register_assertion_cb(assertion, cbAssertionEnable,
                                      control_cb, 0);
            vpi_register_assertion_cb(assertion, cbAssertionReset,
                                      control_cb, 0);
      }
      return 0;
}

static PLI_INT32 check_calltf(PLI_BYTE8 *name)
{
      (void)name;
      if (callbacks == 4 && nonnull_info == 0)
            vpi_printf("PASSED\ncontrol callbacks=%d nonnull_info=%d\n",
                       callbacks, nonnull_info);
      else
            vpi_printf("FAILED: control callbacks=%d nonnull_info=%d\n",
                       callbacks, nonnull_info);
      return 0;
}

static void register_tasks(void)
{
      s_vpi_systf_data task;
      task.type = vpiSysTask;
      task.tfname = "$setup_control_info_cb";
      task.calltf = setup_calltf;
      task.compiletf = 0;
      task.sizetf = 0;
      task.user_data = 0;
      vpi_register_systf(&task);
      task.tfname = "$check_control_info_cb";
      task.calltf = check_calltf;
      vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
