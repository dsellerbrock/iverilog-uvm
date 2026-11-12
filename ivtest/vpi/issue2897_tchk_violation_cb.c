/*
 * IEEE 1800-2023 38.36.3: "For cbTchkViolation callbacks, the obj field
 * shall be a handle to the timing check." Callback A reports every
 * violation; callback B removes itself after its first one.
 */
#include <stdio.h>
#include <string.h>
#include "vpi_user.h"

static int count_a, count_b;
static vpiHandle cb_b;

static void show(const char*tag, p_cb_data cb)
{
      vpiHandle tchk = cb->obj;
      if (!tchk || vpi_get(vpiType, tchk) != vpiTchk) {
	    vpi_printf("%s: FAILED obj is not a vpiTchk\n", tag);
	    return;
      }
      vpiHandle scope = vpi_handle(vpiScope, tchk);
      vpiHandle n = vpi_handle_by_name("n", scope);
      s_vpi_value val;
      val.format = vpiBinStrVal;
      vpi_get_value(n, &val);
      s_vpi_time now;
      now.type = vpiSimTime;
      vpi_get_time(0, &now);
      vpi_printf("%s t=%u type=%d line=%d scope=%s n=%s\n", tag, now.low,
		 vpi_get(vpiTchkType, tchk), vpi_get(vpiLineNo, tchk),
		 vpi_get_str(vpiFullName, scope), val.value.str);
}

static PLI_INT32 on_a(p_cb_data cb)
{
      count_a += 1;
      show("CB_A", cb);
      return 0;
}

static PLI_INT32 on_b(p_cb_data cb)
{
      count_b += 1;
      show("CB_B", cb);
      vpi_remove_cb(cb_b);
      return 0;
}

static PLI_INT32 report(p_cb_data cb)
{
      (void)cb;
      vpi_printf("A=%d B=%d\n", count_a, count_b);
      vpi_printf("%s\n", count_a == 4 && count_b == 1 ? "PASSED" : "FAILED");
      return 0;
}

static void reg(void)
{
      s_cb_data cb;
      memset(&cb, 0, sizeof cb);
      cb.reason = cbTchkViolation;
      cb.cb_rtn = on_a;
      vpi_printf("register A %s\n", vpi_register_cb(&cb) ? "ok" : "null");
      cb.cb_rtn = on_b;
      cb_b = vpi_register_cb(&cb);
      vpi_printf("register B %s\n", cb_b ? "ok" : "null");
      memset(&cb, 0, sizeof cb);
      cb.reason = cbEndOfSimulation;
      cb.cb_rtn = report;
      vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = { reg, 0 };
