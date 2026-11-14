#include <string.h>
#include "vpi_user.h"

static void show(const char *what, vpiHandle h, PLI_INT32 relation)
{
      vpiHandle result = h ? vpi_handle(relation, h) : 0;
      vpi_printf("%s=%s\n", what,
                 result ? vpi_get_str(vpiFullName, result) : "(null)");
}

static PLI_INT32 probe(PLI_BYTE8 *ud)
{
      vpiHandle g = vpi_handle_by_name((PLI_BYTE8 *)"top.g", 0);
      vpiHandle it = g ? vpi_iterate(vpiContAssign, g) : 0;
      vpiHandle ca = it ? vpi_scan(it) : 0;
      (void)ud;
      show("net module", vpi_handle_by_name((PLI_BYTE8 *)"top.g.gw", 0), vpiModule);
      show("contassign module", ca, vpiModule);
      show("contassign scope", ca, vpiScope);
      show("contassign parent", ca, vpiParent);
      return 0;
}

static void reg_probe(void)
{
      s_vpi_systf_data d;
      memset(&d, 0, sizeof d);
      d.type = vpiSysTask;
      d.tfname = (PLI_BYTE8 *)"$probe";
      d.calltf = probe;
      vpi_register_systf(&d);
}

void (*vlog_startup_routines[])(void) = { reg_probe, 0 };
