#include <string.h>
#include <vpi_user.h>

static unsigned long change_count;
static s_vpi_time change_time;
static s_vpi_value change_value;

static PLI_INT32 on_value_change(p_cb_data callback)
{
      (void)callback;
      change_count += 1;
      return 0;
}

static PLI_INT32 watch_value_changes(PLI_BYTE8 *user_data)
{
      (void)user_data;
      vpiHandle call = vpi_handle(vpiSysTfCall, NULL);
      vpiHandle arguments = vpi_iterate(vpiArgument, call);
      vpiHandle signal = arguments ? vpi_scan(arguments) : NULL;
      if (!signal) {
            vpi_printf("$watch_value_changes requires a signal\n");
            return 0;
      }

      memset(&change_time, 0, sizeof(change_time));
      memset(&change_value, 0, sizeof(change_value));
      change_time.type = vpiSimTime;
      change_value.format = vpiIntVal;
      s_cb_data callback;
      memset(&callback, 0, sizeof(callback));
      callback.reason = cbValueChange;
      callback.cb_rtn = on_value_change;
      callback.obj = signal;
      callback.time = &change_time;
      callback.value = &change_value;
      vpi_register_cb(&callback);
      return 0;
}

static PLI_INT32 report_value_changes(PLI_BYTE8 *user_data)
{
      (void)user_data;
      vpi_printf("cbValueChange count=%lu\n", change_count);
      return 0;
}

static void register_tasks(void)
{
      s_vpi_systf_data task;
      memset(&task, 0, sizeof(task));
      task.type = vpiSysTask;
      task.tfname = "$watch_value_changes";
      task.calltf = watch_value_changes;
      vpi_register_systf(&task);

      memset(&task, 0, sizeof(task));
      task.type = vpiSysTask;
      task.tfname = "$report_value_changes";
      task.calltf = report_value_changes;
      vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
