#define VPI_COMPATIBILITY_VERSION_1800v2017 1
#include "vpi_user.h"

#ifndef vpi_get
#error "vpi_get was not remapped for the selected VPI compatibility mode"
#endif

static PLI_INT32 check_vpi_compatibility(p_cb_data data)
{
      (void)data;
      vpiHandle value = vpi_handle_by_name("top.value", 0);
      if (value && vpi_get(vpiSize, value) == 8)
            vpi_printf("VPI COMPAT 2017 PASS\n");
      else
            vpi_printf("VPI COMPAT 2017 FAIL\n");
      return 0;
}

static void register_vpi_compatibility_test(void)
{
      s_cb_data cb = {0};
      cb.reason = cbStartOfSimulation;
      cb.cb_rtn = check_vpi_compatibility;
      vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = {
      register_vpi_compatibility_test,
      0
};
