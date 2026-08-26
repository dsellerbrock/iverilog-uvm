#include <vpi_user.h>

#include <string.h>

static vpiHandle pure_result;
static vpiHandle ordinary_result;
static int finish_called;

static int read_int(vpiHandle object)
{
      s_vpi_value value;

      value.format = vpiIntVal;
      vpi_get_value(object, &value);
      return value.value.integer;
}

static PLI_INT32 finish_on_one_cb(p_cb_data data)
{
      if (!data->value || data->value->value.integer != 1 || finish_called)
            return 0;

      finish_called = 1;
      vpi_printf("callback before finish: pure=%d ordinary=%d\n",
                 read_int(pure_result), read_int(ordinary_result));
      vpi_control(vpiFinish, 0);
      return 0;
}

static PLI_INT32 monitor_calltf(PLI_BYTE8*name)
{
      vpiHandle call = vpi_handle(vpiSysTfCall, 0);
      vpiHandle arguments = vpi_iterate(vpiArgument, call);
      vpiHandle finish_signal;
      s_cb_data callback;
      static s_vpi_time time;
      static s_vpi_value value;

      (void)name;
      finish_signal = vpi_scan(arguments);
      pure_result = vpi_scan(arguments);
      ordinary_result = vpi_scan(arguments);
      vpi_free_object(arguments);

      memset(&callback, 0, sizeof callback);
      memset(&time, 0, sizeof time);
      memset(&value, 0, sizeof value);
      time.type = vpiSuppressTime;
      value.format = vpiIntVal;
      callback.reason = cbValueChange;
      callback.cb_rtn = finish_on_one_cb;
      callback.obj = finish_signal;
      callback.time = &time;
      callback.value = &value;
      vpi_register_cb(&callback);
      return 0;
}

static void register_monitor(void)
{
      s_vpi_systf_data task;

      memset(&task, 0, sizeof task);
      task.type = vpiSysTask;
      task.tfname = "$finish_on_one";
      task.calltf = monitor_calltf;
      vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = {
      register_monitor,
      0
};
