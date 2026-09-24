#include "vpi_user.h"

static int end_of_compile_seen;

static PLI_INT32 end_of_compile_cb(p_cb_data data)
{
      (void)data;
      end_of_compile_seen = 1;
      return 0;
}

static PLI_INT32 start_of_sim_cb(p_cb_data data)
{
      vpiHandle default_zero, seen;
      s_vpi_value value;
      (void)data;

      if (!end_of_compile_seen) {
            vpi_printf("FAIL: StartOfSim preceded EndOfCompile\n");
            vpi_control(vpiFinish, 1);
            return 0;
      }

      default_zero = vpi_handle_by_name("startup_vpi_boundary.default_zero", 0);
      seen = vpi_handle_by_name("startup_vpi_boundary.callback_seen", 0);
      if (!default_zero || !seen) {
            vpi_printf("FAIL: startup VPI handles missing\n");
            vpi_control(vpiFinish, 1);
            return 0;
      }

      value.format = vpiBinStrVal;
      vpi_get_value(default_zero, &value);
      if (value.value.str[0] != '0') {
            vpi_printf("FAIL: two-state variable default unreadable at StartOfSim\n");
            vpi_control(vpiFinish, 1);
            return 0;
      }

      value.format = vpiIntVal;
      value.value.integer = 1;
      vpi_put_value(seen, &value, 0, vpiNoDelay);
      return 0;
}

static void register_callbacks(void)
{
      s_cb_data end_cb = { 0 };
      s_cb_data start_cb = { 0 };
      end_cb.reason = cbEndOfCompile;
      end_cb.cb_rtn = end_of_compile_cb;
      start_cb.reason = cbStartOfSimulation;
      start_cb.cb_rtn = start_of_sim_cb;
      vpi_register_cb(&end_cb);
      vpi_register_cb(&start_cb);
}

void (*vlog_startup_routines[])(void) = { register_callbacks, 0 };
