/* IEEE 1800-2023 38.13: vpi_get_time() with a type other than
   vpiScaledRealTime/vpiSimTime is an error that leaves *time_p unchanged.
   38.19: vpi_handle_by_index() on a null parent returns a null handle.
   Neither may abort the simulator (#2821, #2824). */
#include <string.h>
#include "vpi_user.h"

static int fails = 0;

static void check(int ok, const char*what)
{
      if (!ok) {
	    vpi_printf("FAIL: %s\n", what);
	    fails += 1;
      }
}

static PLI_INT32 probe(PLI_BYTE8*ud)
{
      (void)ud;
      s_vpi_error_info info;
      PLI_INT32 types[2] = { vpiSuppressTime, 99 };
      for (int i = 0; i < 2; i += 1) {
	    s_vpi_time t;
	    t.type = types[i];
	    t.high = 7;
	    t.low = 9;
	    t.real = 2.5;
	    vpi_get_time(0, &t);
	    check(t.type == types[i] && t.high == 7 && t.low == 9
		  && t.real == 2.5, "vpi_get_time changed *time_p");
	    check(vpi_chk_error(&info) == vpiError,
		  "vpi_get_time bad type is not a vpiError");
      }

      s_vpi_time now;
      now.type = vpiSimTime;
      vpi_get_time(0, &now);
      check(now.low == 1 && now.high == 0, "vpi_get_time(vpiSimTime)");

      check(vpi_handle_by_index(0, 0) == 0, "vpi_handle_by_index(NULL) handle");
      check(vpi_chk_error(&info) == vpiError,
	    "vpi_handle_by_index(NULL) is not a vpiError");

      vpiHandle v = vpi_handle_by_name((PLI_BYTE8*)"top.v", 0);
      vpiHandle bit = v ? vpi_handle_by_index(v, 3) : 0;
      check(bit != 0, "vpi_handle_by_index(top.v, 3)");
      if (bit) {
	    s_vpi_value val;
	    val.format = vpiIntVal;
	    vpi_get_value(bit, &val);
	    check(val.value.integer == 1, "top.v[3] value");
      }

      if (fails == 0) vpi_printf("VPI NULL ARGS PASS\n");
      return 0;
}

static void reg(void)
{
      s_vpi_systf_data d;
      memset(&d, 0, sizeof d);
      d.type = vpiSysTask;
      d.tfname = (PLI_BYTE8*)"$probe";
      d.calltf = probe;
      vpi_register_systf(&d);
}

void (*vlog_startup_routines[])(void) = { reg, 0 };
