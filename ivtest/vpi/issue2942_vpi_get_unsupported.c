#include <string.h>
#include "sv_vpi_user.h"

#define IEEE_vpiPacked 630

static PLI_INT32 probe(PLI_BYTE8*ud)
{
      vpiHandle p = vpi_handle_by_name((PLI_BYTE8*)"top.P", 0);
      (void)ud;
      vpi_printf("type=%d\n", (int)vpi_get(vpiType, p));
      vpi_printf("packed=%d\n", (int)vpi_get(IEEE_vpiPacked, p));
      vpi_printf("PASSED\n");
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
