/*
 * Issue #1274 (IEEE 1800-2023 37.14): vpiHighConn and vpiLowConn of the
 * ports of top.u. An instance array keeps no actuals yet, so its ports
 * report a NULL vpiHighConn and keep their vpiLowConn.
 */
#include <stdio.h>
#include <string.h>
#include "vpi_user.h"

#define IEEE_vpiOperation 39
#define IEEE_vpiAddOp 24

static unsigned failures;

static void expect(int ok, const char*what)
{
      if (!ok) {
	    vpi_printf("FAILED: %s\n", what);
	    failures += 1;
      }
}

static void full_name(vpiHandle h, char*buf, size_t len)
{
      const char*name = h ? vpi_get_str(vpiFullName, h) : 0;
      snprintf(buf, len, "%s", name ? name : "<null>");
}

static int int_value(vpiHandle h)
{
      s_vpi_value v;
      v.format = vpiIntVal;
      vpi_get_value(h, &v);
      return v.value.integer;
}

static PLI_INT32 probe_calltf(PLI_BYTE8*ud)
{
      static const char*want_high[] = { "top.a", "top.y", 0, 0 };
      static const char*want_low[] = { "top.u.a", "top.u.y", "top.u.w", "top.u.z" };
      vpiHandle u = vpi_handle_by_name((PLI_BYTE8*)"top.u", 0);
      vpiHandle it = u ? vpi_iterate(vpiPort, u) : 0, port;
      unsigned idx = 0;
      (void)ud;
      while (it && (port = vpi_scan(it))) {
	    vpiHandle high = vpi_handle(vpiHighConn, port);
	    vpiHandle low = vpi_handle(vpiLowConn, port);
	    char hname[64], lname[64], what[64];
	    full_name(high, hname, sizeof hname);
	    full_name(low, lname, sizeof lname);
	    vpi_printf("port %u %s high=%s type=%d low=%s\n", idx,
		       vpi_get_str(vpiName, port), hname,
		       high ? (int)vpi_get(vpiType, high) : -1, lname);
	    snprintf(what, sizeof what, "port %u", idx);
	    if (idx < 4) {
		  expect(!strcmp(lname, want_low[idx]), what);
		  if (want_high[idx])
			expect(!strcmp(hname, want_high[idx]), what);
	    }
	    if (idx == 2)
		  expect(high && vpi_get(vpiType, high) == IEEE_vpiOperation
			 && vpi_get(vpiOpType, high) == IEEE_vpiAddOp
			 && int_value(high) == 6, "port w actual b + 1");
	    if (idx == 3)
		  expect(high == 0, "unconnected port z");
	    idx += 1;
      }
      expect(idx == 4, "four ports");

      {
	    vpiHandle a1 = vpi_handle_by_name((PLI_BYTE8*)"top.arr[1]", 0);
	    vpiHandle pit = a1 ? vpi_iterate(vpiPort, a1) : 0;
	    vpiHandle p0 = pit ? vpi_scan(pit) : 0;
	    char lname[64];
	    if (pit && p0) vpi_free_object(pit);
	    full_name(p0 ? vpi_handle(vpiLowConn, p0) : 0, lname, sizeof lname);
	    vpi_printf("arr[1] port 0 high=%s low=%s\n",
		       p0 && vpi_handle(vpiHighConn, p0) ? "set" : "<null>", lname);
	    expect(p0 && !strcmp(lname, "top.arr[1].a"), "instance array low conn");
      }
      if (failures == 0) vpi_printf("VPI PORT CONN PASS\nPASSED\n");
      return 0;
}

static void reg(void)
{
      s_vpi_systf_data d;
      memset(&d, 0, sizeof d);
      d.type = vpiSysTask;
      d.tfname = (PLI_BYTE8*)"$pprobe";
      d.calltf = probe_calltf;
      vpi_register_systf(&d);
}

void (*vlog_startup_routines[])(void) = { reg, 0 };
