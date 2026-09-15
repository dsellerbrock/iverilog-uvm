#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "vpi_user.h"

static unsigned callback_count[3];

static const char*get_bin(vpiHandle obj)
{
      s_vpi_value value;
      value.format = vpiBinStrVal;
      vpi_get_value(obj, &value);
      return value.value.str;
}

static PLI_INT32 value_changed(p_cb_data data)
{
      uintptr_t index = (uintptr_t)data->user_data;
      callback_count[index] += 1;
      return 0;
}

static void register_change(vpiHandle obj, uintptr_t index)
{
      s_cb_data callback;
      memset(&callback, 0, sizeof callback);
      callback.reason = cbValueChange;
      callback.cb_rtn = value_changed;
      callback.obj = obj;
      callback.user_data = (PLI_BYTE8*)index;
      vpi_register_cb(&callback);
}

static PLI_INT32 test_calltf(PLI_BYTE8*data)
{
      (void)data;
      vpiHandle call = vpi_handle(vpiSysTfCall, 0);
      vpiHandle iter = vpi_iterate(vpiArgument, call);
      vpiHandle wide = vpi_scan(iter);
      vpiHandle dynamic_wide = vpi_scan(iter);
      vpiHandle partial = vpi_scan(iter);
      vpiHandle normal = vpi_scan(iter);
      vpiHandle parent = vpi_handle(vpiParent, wide);

      if (strcmp(get_bin(wide), "xxxx") != 0 ||
          strcmp(get_bin(dynamic_wide), "xxxx") != 0 ||
          strcmp(get_bin(partial), "01xx") != 0 ||
          strcmp(get_bin(normal), "1001") != 0) {
            vpi_printf("FAILED initial VPI part-select values\n");
            vpi_control(vpiFinish, 1);
            return 0;
      }

      s_vpi_value put;
      put.format = vpiBinStrVal;
      put.value.str = (PLI_BYTE8*)"0000";
      vpi_put_value(wide, &put, 0, vpiNoDelay);
      if (strcmp(get_bin(parent), "10100101") != 0) {
            vpi_printf("FAILED out-of-range VPI write changed parent\n");
            vpi_control(vpiFinish, 1);
            return 0;
      }

      put.value.str = (PLI_BYTE8*)"1111";
      vpi_put_value(partial, &put, 0, vpiNoDelay);
      if (strcmp(get_bin(parent), "10100111") != 0) {
            vpi_printf("FAILED partial VPI write or neighbor preservation\n");
            vpi_control(vpiFinish, 1);
            return 0;
      }

      register_change(wide, 0);
      register_change(partial, 1);
      register_change(normal, 2);
      return 0;
}

static PLI_INT32 done_calltf(PLI_BYTE8*data)
{
      (void)data;
      if (callback_count[0] != 0 || callback_count[1] != 1 ||
          callback_count[2] != 1) {
            vpi_printf("FAILED callback counts wide=%u partial=%u normal=%u\n",
                       callback_count[0], callback_count[1], callback_count[2]);
            vpi_control(vpiFinish, 1);
            return 0;
      }
      vpi_printf("PASSED\n");
      return 0;
}

static void register_tasks(void)
{
      s_vpi_systf_data task;
      memset(&task, 0, sizeof task);
      task.type = vpiSysTask;
      task.tfname = "$wide_pv_test";
      task.calltf = test_calltf;
      vpi_register_systf(&task);
      task.tfname = "$wide_pv_done";
      task.calltf = done_calltf;
      vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
