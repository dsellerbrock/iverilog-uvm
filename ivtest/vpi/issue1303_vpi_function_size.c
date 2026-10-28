#include "vpi_user.h"

static PLI_INT32 probe(p_cb_data cb)
{
      vpiHandle function = vpi_handle_by_name((PLI_BYTE8 *)"top.f", NULL);
      vpiHandle void_function = vpi_handle_by_name((PLI_BYTE8 *)"top.vf", NULL);
      int size = function ? vpi_get(vpiSize, function) : -1;
      int type = function ? vpi_get(vpiFuncType, function) : -1;
      int void_size = void_function ? vpi_get(vpiSize, void_function) : -1;

      (void)cb;
      if (size == 32 && type == vpiSizedFunc && void_size == 0)
            vpi_printf("ISSUE 1303 VPI PASS\n");
      else
            vpi_printf("ISSUE 1303 FAIL size=%d type=%d void_size=%d\n",
                       size, type, void_size);
      return 0;
}

static void startup(void)
{
      s_cb_data cb = {0};
      cb.reason = cbStartOfSimulation;
      cb.cb_rtn = probe;
      vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = {startup, 0};
