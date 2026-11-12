#include <string.h>
#include "vpi_user.h"

static PLI_INT32 probe(PLI_BYTE8*ud)
{
      (void)ud;
      vpiHandle v = vpi_handle_by_name((PLI_BYTE8*)"top.v", 0);
      s_vpi_error_info e;
      memset(&e, 0, sizeof e);
      int ret = vpi_get(999, v);
      int level = vpi_chk_error(&e);
      vpi_printf("BAD ret=%d level=%d state=%d message=%s\n",
                 ret, level, e.state, e.message);
      ret = vpi_get(vpiSize, v);
      level = vpi_chk_error(&e);
      vpi_printf("GOOD ret=%d level=%d\n", ret, level);
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
