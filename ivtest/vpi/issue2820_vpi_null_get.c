#include <string.h>
#include "vpi_user.h"

static PLI_INT32 probe(PLI_BYTE8*ud)
{
      (void)ud;
      vpi_printf("SIZE=%d\n", (int)vpi_get(vpiSize, 0));
      vpi_printf("UNIT=%d\n", (int)vpi_get(vpiTimeUnit, 0));
      vpi_printf("VPI NULL GET PASS\nPASSED\n");
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
