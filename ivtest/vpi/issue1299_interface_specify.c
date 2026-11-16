#include <string.h>
#include "vpi_user.h"
#include "sv_vpi_user.h"

static int check_path(const char *name, int is_interface)
{
      vpiHandle scope = vpi_handle_by_name((PLI_BYTE8 *)name, 0);
      vpiHandle iter = scope ? vpi_iterate(vpiModPath, scope) : 0;
      vpiHandle path = iter ? vpi_scan(iter) : 0;
      int ok = path && vpi_handle(vpiInstance, path) == scope
            && vpi_handle(vpiModule, path) == (is_interface ? 0 : scope);
      if (iter && vpi_scan(iter)) ok = 0;
      return ok;
}

static PLI_INT32 check(PLI_BYTE8 *unused)
{
      s_vpi_value value;
      (void)unused;
      value.format = vpiIntVal;
      value.value.integer = check_path("top.intf", 1) && check_path("top.dut", 0);
      vpi_put_value(vpi_handle(vpiSysTfCall, 0), &value, 0, vpiNoDelay);
      return 0;
}

static void register_check(void)
{
      s_vpi_systf_data data;
      memset(&data, 0, sizeof data);
      data.type = vpiSysFunc;
      data.sysfunctype = vpiIntFunc;
      data.tfname = (PLI_BYTE8 *)"$issue1299_vpi_check";
      data.calltf = check;
      vpi_register_systf(&data);
}
void (*vlog_startup_routines[])(void) = {register_check, 0};
