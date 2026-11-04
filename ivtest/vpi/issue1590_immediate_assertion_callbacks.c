#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <stdio.h>
#include <string.h>

static int handle_count = 0;
static int good_success = 0;
static int good_failure = 0;
static int bad_success = 0;
static int bad_failure = 0;
static int task_success = 0;
static int task_failure = 0;
static int handles_ok = 0;

static PLI_INT32 assertion_cb(PLI_INT32 reason, p_vpi_time time,
                              vpiHandle assertion,
                              p_vpi_attempt_info info,
                              PLI_BYTE8 *user_data)
{
      const char *name = vpi_get_str(vpiName, assertion);
      (void)time;
      (void)info;
      (void)user_data;
      if (name && strcmp(name, "good") == 0) {
            if (reason == cbAssertionSuccess) good_success += 1;
            else if (reason == cbAssertionFailure) good_failure += 1;
      } else if (name && strcmp(name, "bad") == 0) {
            if (reason == cbAssertionSuccess) bad_success += 1;
            else if (reason == cbAssertionFailure) bad_failure += 1;
      } else if (name && strcmp(name, "task_good") == 0) {
            if (reason == cbAssertionSuccess) task_success += 1;
            else if (reason == cbAssertionFailure) task_failure += 1;
      }
      vpi_printf("CALLBACK %s %s\n", name ? name : "?",
                 reason == cbAssertionSuccess ? "success" : "failure");
      return 0;
}

static void register_reason(vpiHandle assertion, PLI_INT32 reason)
{
      if (assertion && vpi_register_assertion_cb(
                  assertion, reason, assertion_cb, 0) != 0)
            handle_count += 1;
}

static PLI_INT32 setup_callbacks(PLI_BYTE8 *user_data)
{
      vpiHandle good = vpi_handle_by_name((PLI_BYTE8 *)"top.good", 0);
      vpiHandle bad = vpi_handle_by_name((PLI_BYTE8 *)"top.bad", 0);
      vpiHandle task_good = vpi_handle_by_name(
            (PLI_BYTE8 *)"top.check_task.task_good", 0);
      (void)user_data;

      register_reason(good, cbAssertionSuccess);
      register_reason(good, cbAssertionFailure);
      register_reason(bad, cbAssertionSuccess);
      register_reason(bad, cbAssertionFailure);
      register_reason(task_good, cbAssertionSuccess);
      register_reason(task_good, cbAssertionFailure);
      handles_ok = good && bad && task_good
            && vpi_get(vpiType, good) == vpiImmediateAssert
            && vpi_get(vpiType, bad) == vpiImmediateAssert
            && vpi_get(vpiType, task_good) == vpiImmediateAssert
            && strcmp(vpi_get_str(vpiName, good), "good") == 0
            && strcmp(vpi_get_str(vpiName, bad), "bad") == 0
            && strcmp(vpi_get_str(vpiName, task_good), "task_good") == 0;
      vpi_printf("HANDLE_COUNT=%d types=%d/%d/%d\n", handle_count,
                 good ? vpi_get(vpiType, good) : -1,
                 bad ? vpi_get(vpiType, bad) : -1,
                 task_good ? vpi_get(vpiType, task_good) : -1);
      return 0;
}

static PLI_INT32 check_callbacks(PLI_BYTE8 *user_data)
{
      (void)user_data;
      if (handles_ok && handle_count == 6 && good_success == 1 && good_failure == 0
          && bad_success == 0 && bad_failure == 1
          && task_success == 1 && task_failure == 0) {
            vpi_printf("PASS: issue1590 immediate assertion callbacks\n");
            vpi_printf("PASSED\n");
      } else {
            vpi_printf("FAIL: issue1590 handles=%d good=%d/%d bad=%d/%d task=%d/%d\n",
                       handle_count, good_success, good_failure,
                       bad_success, bad_failure, task_success, task_failure);
      }
      return 0;
}

static PLI_INT32 start_of_simulation(p_cb_data cb)
{
      (void)cb;
      return setup_callbacks(0);
}

static void register_tasks(void)
{
      s_vpi_systf_data tf;
      s_cb_data cb;

      memset(&cb, 0, sizeof cb);
      cb.reason = cbStartOfSimulation;
      cb.cb_rtn = start_of_simulation;
      vpi_register_cb(&cb);

      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = (PLI_BYTE8 *)"$check_immediate_assertion_callbacks";
      tf.calltf = check_callbacks;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
