#include <stdio.h>
#include <string.h>
#include "vpi_user.h"

static PLI_INT32 probe(PLI_BYTE8*ud)
{
      vpiHandle top = vpi_handle_by_name((PLI_BYTE8*)"top", 0);
      vpiHandle it = vpi_iterate(vpiContAssign, top), ca;
      int n = 0;
      (void)ud;
      while (it && (ca = vpi_scan(it))) {
	    vpiHandle lhs = vpi_handle(vpiLhs, ca), rhs = vpi_handle(vpiRhs, ca);
	    const char*name = lhs ? vpi_get_str(vpiFullName, lhs) : 0;
	    char lname[64];
	    snprintf(lname, sizeof lname, "%s", name ? name : "<null>");
	    name = rhs ? vpi_get_str(vpiFullName, rhs) : 0;
	    char rname[64];
	    snprintf(rname, sizeof rname, "%s", name ? name : "<null>");
	    vpi_printf("CONTASSIGN line=%d lhs=%s rhs=%s\n",
		       (int)vpi_get(vpiLineNo, ca),
		       lname, rname);
	    if (lhs && rhs
		&& !strcmp(lname, "top.arr") && !strcmp(rname, "top.sarr"))
		  n += 1;
      }
      vpi_printf("COUNT=%d\n", n);
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
