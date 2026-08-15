#include <string.h>
#include "vpi_user.h"

static unsigned dumped_changes;
static unsigned control_changes;

static PLI_INT32 value_change_cb(p_cb_data cb)
{
      unsigned *count = (unsigned *)cb->user_data;
      *count += 1;
      return 0;
}

static PLI_INT32 start_cb(p_cb_data cb)
{
      const char *const names[2] = {
            "dumpports_activity_cb.dumped.value",
            "dumpports_activity_cb.control.value"
      };
      unsigned *const counts[2] = { &dumped_changes, &control_changes };
      unsigned idx;
      (void)cb;

      for (idx = 0; idx < 2; idx += 1) {
            s_cb_data data;
            s_vpi_time time;
            vpiHandle signal = vpi_handle_by_name(names[idx], 0);
            if (!signal) {
                  vpi_printf("FAIL: cannot find %s\n", names[idx]);
                  vpi_control(vpiFinish, 1);
                  return 0;
            }
            memset(&data, 0, sizeof data);
            memset(&time, 0, sizeof time);
            time.type = vpiSuppressTime;
            data.reason = cbValueChange;
            data.cb_rtn = value_change_cb;
            data.obj = signal;
            data.time = &time;
            data.user_data = (PLI_BYTE8 *)counts[idx];
            if (!vpi_register_cb(&data)) {
                  vpi_printf("FAIL: cannot register callback for %s\n",
                             names[idx]);
                  vpi_control(vpiFinish, 1);
                  return 0;
            }
      }
      return 0;
}

static PLI_INT32 check_calltf(PLI_BYTE8 *user_data)
{
      (void)user_data;
      if (dumped_changes == control_changes && dumped_changes != 0)
            vpi_printf("PASS: ordinary callbacks unchanged (%u/%u)\n",
                       dumped_changes, control_changes);
      else {
            vpi_printf("FAIL: ordinary callbacks differ (%u/%u)\n",
                       dumped_changes, control_changes);
            vpi_control(vpiFinish, 1);
      }
      return 0;
}

static void register_dumpports_activity_cb(void)
{
      s_vpi_systf_data tf;
      s_cb_data cb;

      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$check_dumpports_activity_callbacks";
      tf.calltf = check_calltf;
      vpi_register_systf(&tf);

      memset(&cb, 0, sizeof cb);
      cb.reason = cbStartOfSimulation;
      cb.cb_rtn = start_cb;
      vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = {
      register_dumpports_activity_cb,
      0
};
