/* IEEE 1800-2023 37.5, 37.13: vpi_iterate(vpiIODecl, module) yields one
   I/O declaration per module port (#3040). */
#include <string.h>
#include "vpi_user.h"
#include "sv_vpi_user.h"

static PLI_INT32 probe(PLI_BYTE8*ud)
{
      vpiHandle mod = vpi_handle_by_name((PLI_BYTE8*)"top.u", 0);
      vpiHandle task = vpi_handle_by_name((PLI_BYTE8*)"top.t", 0);
      vpiHandle it, h;
      int ports = 0, tio = 0;
      (void)ud;
      it = vpi_iterate(vpiIODecl, mod);
      while (it && (h = vpi_scan(it))) {
	    vpiHandle expr = vpi_handle(vpiExpr, h);
	    /* vpi_get_str() results share one buffer: copy the name. */
	    char name[64];
	    strncpy(name, vpi_get_str(vpiName, h), sizeof name - 1);
	    name[sizeof name - 1] = 0;
	    vpi_printf("IODECL %s dir=%d size=%d expr=%s\n", name,
		       (int)vpi_get(vpiDirection, h), (int)vpi_get(vpiSize, h),
		       expr ? vpi_get_str(vpiFullName, expr) : "(null)");
      }
      it = vpi_iterate(vpiPort, mod);
      while (it && (h = vpi_scan(it))) ports += 1;
      it = vpi_iterate(vpiIODecl, task);
      while (it && (h = vpi_scan(it))) tio += 1;
      it = vpi_iterate(vpiIODecl, vpi_handle_by_name((PLI_BYTE8*)"top", 0));
      vpi_printf("PORTS=%d TASK_IO=%d TOP_IO=%s\n", ports, tio, it ? "some" : "none");
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
