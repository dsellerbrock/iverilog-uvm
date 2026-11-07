#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <stdio.h>
#include <string.h>

#define CB_ASSERTION_VACUOUS_SUCCESS 657

static int successes;
static int vacuous;
static int failures;

static PLI_INT32 assertion_cb(PLI_INT32 reason, p_vpi_time time,
                              vpiHandle assertion,
                              p_vpi_attempt_info info,
                              PLI_BYTE8 *user_data)
{
      (void)time;
      (void)assertion;
      (void)info;
      (void)user_data;
      if (reason == cbAssertionSuccess) successes += 1;
      else if (reason == CB_ASSERTION_VACUOUS_SUCCESS) vacuous += 1;
      else if (reason == cbAssertionFailure) failures += 1;
      return 0;
}

static PLI_INT32 setup_calltf(PLI_BYTE8 *name)
{
      vpiHandle iterator, assertion;
      (void)name;
      iterator = vpi_iterate(vpiAssertion, NULL);
      while (iterator && (assertion = vpi_scan(iterator))) {
            vpi_register_assertion_cb(assertion, cbAssertionSuccess,
                                      assertion_cb, 0);
            vpi_register_assertion_cb(assertion,
                                      CB_ASSERTION_VACUOUS_SUCCESS,
                                      assertion_cb, 0);
            vpi_register_assertion_cb(assertion, cbAssertionFailure,
                                      assertion_cb, 0);
      }
      return 0;
}

static PLI_INT32 check_calltf(PLI_BYTE8 *name)
{
      (void)name;
      if (successes == 10 && vacuous == 0 && failures == 0)
            vpi_printf("PASSED\n");
      else
            vpi_printf("FAILED: successes=%d vacuous=%d failures=%d\n",
                       successes, vacuous, failures);
      return 0;
}

static void register_tasks(void)
{
      s_vpi_systf_data task;
      memset(&task, 0, sizeof task);
      task.type = vpiSysTask;
      task.tfname = "$setup_issue2720_callbacks";
      task.calltf = setup_calltf;
      vpi_register_systf(&task);
      task.tfname = "$check_issue2720_callbacks";
      task.calltf = check_calltf;
      vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
