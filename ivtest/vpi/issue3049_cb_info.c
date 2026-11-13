#include <string.h>
#include "vpi_user.h"

static int errors, delay_fired, change_fired;
static char marker[] = "callback data";

static PLI_INT32 delayed(p_cb_data data)
{
      if (data->reason != cbAfterDelay || data->user_data != marker) errors++;
      delay_fired++;
      return 0;
}

static PLI_INT32 changed(p_cb_data data)
{
      if (data->reason != cbValueChange || data->user_data != marker) errors++;
      change_fired++;
      return 0;
}

static PLI_INT32 setup(PLI_BYTE8 *unused)
{
      s_cb_data cb, info;
      s_vpi_time when;
      s_vpi_value value;
      vpiHandle handle, signal;
      (void)unused;
      memset(&cb, 0, sizeof cb);
      memset(&when, 0, sizeof when);
      when.type = vpiSimTime;
      when.low = 3;
      cb.reason = cbAfterDelay;
      cb.cb_rtn = delayed;
      cb.time = &when;
      cb.user_data = marker;
      handle = vpi_register_cb(&cb);
      if (!handle) { errors++; return 0; }
      memset(&info, 0, sizeof info);
      vpi_get_cb_info(handle, &info);
      if (info.reason != cbAfterDelay || info.cb_rtn != delayed ||
          info.obj != 0 || !info.time || info.time->type != vpiSimTime ||
          info.time->low != 3 || info.time->high != 0 ||
          info.value != 0 || info.index != 0 || info.user_data != marker)
            errors++;

      signal = vpi_handle_by_name("top.signal", 0);
      if (!signal) { errors++; return 0; }
      memset(&cb, 0, sizeof cb);
      memset(&value, 0, sizeof value);
      value.format = vpiIntVal;
      when.type = vpiSimTime;
      cb.reason = cbValueChange;
      cb.cb_rtn = changed;
      cb.obj = signal;
      cb.time = &when;
      cb.value = &value;
      cb.user_data = marker;
      handle = vpi_register_cb(&cb);
      if (!handle) { errors++; return 0; }
      memset(&info, 0, sizeof info);
      vpi_get_cb_info(handle, &info);
      if (info.reason != cbValueChange || info.cb_rtn != changed ||
          info.obj != signal || !info.time || info.time->type != vpiSimTime ||
          !info.value || info.value->format != vpiIntVal ||
          info.index != 0 || info.user_data != marker)
            errors++;
      return 0;
}

static PLI_INT32 check(PLI_BYTE8 *unused)
{
      (void)unused;
      if (errors || delay_fired != 1 || change_fired != 1)
            vpi_printf("FAILED errors=%d delay=%d change=%d\n", errors, delay_fired, change_fired);
      else vpi_printf("PASSED\n");
      return 0;
}

static void start(void)
{
      s_vpi_systf_data task;
      memset(&task, 0, sizeof task);
      task.type = vpiSysTask;
      task.tfname = "$setup_callbacks";
      task.calltf = setup;
      vpi_register_systf(&task);
      task.tfname = "$check_callbacks";
      task.calltf = check;
      vpi_register_systf(&task);
}
void (*vlog_startup_routines[])(void) = { start, 0 };
