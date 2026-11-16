/*
 * IEEE 1800-2023 37.16: undriven, unread declared nets are VPI objects with
 * their vpiNetType (vpiWire, vpiWand, vpiWor, vpiTri0, vpiTri1, vpiUwire).
 */
#include <string.h>
#include "vpi_user.h"

static PLI_INT32 probe(PLI_BYTE8*ud)
{
      static const char*names[] = { "top.w", "top.wa", "top.wo", "top.t0", "top.t1", "top.uw" };
      static const int types[] = { vpiWire, vpiWand, vpiWor, vpiTri0, vpiTri1, vpiUwire };
      int fails = 0, k, count = 0;
      vpiHandle it, n;
      (void)ud;
      for (k = 0; k < 6; k += 1) {
	    n = vpi_handle_by_name((PLI_BYTE8*)names[k], 0);
	    vpi_printf("%s %s nettype=%d\n", names[k], n ? "found" : "missing",
		       n ? (int)vpi_get(vpiNetType, n) : -99);
	    if (!n || vpi_get(vpiNetType, n) != types[k]) fails += 1;
      }
      it = vpi_iterate(vpiNet, vpi_handle_by_name((PLI_BYTE8*)"top", 0));
      while (it && (n = vpi_scan(it))) count += 1;
      vpi_printf("nets=%d\n", count);
      if (count != 6) fails += 1;
      if (fails == 0) vpi_printf("VPI UNDRIVEN NETS PASS\nPASSED\n");
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
