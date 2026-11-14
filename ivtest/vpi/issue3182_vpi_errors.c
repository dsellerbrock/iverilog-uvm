#include <stdio.h>
#include <string.h>
#include "vpi_user.h"

#ifndef cbPLIError
#define cbPLIError 28
#endif
#ifndef vpiPLI
#define vpiPLI 2
#endif

static int pli_errors, errors, failed;

static PLI_INT32 on_error(p_cb_data cb)
{
      if (cb->reason == cbPLIError) pli_errors += 1;
      if (cb->reason == cbError) errors += 1;
      return 0;
}

static void check_error(const char *name, int count)
{
      s_vpi_error_info info;
      int level = vpi_chk_error(&info);
      if (level != vpiError || info.state != vpiPLI || !info.message ||
          pli_errors != count || errors != count) {
            vpi_printf("FAIL %s level=%d callbacks=%d/%d\n", name, level,
                       pli_errors, errors);
            failed = 1;
      }
}

static void check_clear(const char *name)
{
      s_vpi_error_info info;
      int level = vpi_chk_error(&info);
      if (level != 0) {
            vpi_printf("FAIL %s did not clear error: %d\n", name, level);
            failed = 1;
      }
}

static PLI_INT32 probe(PLI_BYTE8 *ud)
{
      vpiHandle w = vpi_handle_by_name((PLI_BYTE8*)"top.w", 0);
      s_vpi_value val;
      PLI_INT32 result;
      (void)ud;

      result = vpi_get(vpiSize, 0);
      check_error("global property", 1);
      if (result != vpiUndefined) failed = 1;
      val.format = vpiIntVal;
      vpi_get_value(w, &val);
      check_clear("get value");
      if (val.value.integer != 0x5a) failed = 1;

      val.format = 99999;
      val.value.integer = 12345;
      vpi_get_value(w, &val);
      check_error("bad format", 2);
      if (val.format != 99999 || val.value.integer != 12345) failed = 1;
      val.format = vpiIntVal;
      val.value.integer = 0x33;
      vpi_put_value(w, &val, 0, vpiNoDelay);
      check_clear("put value");

      if (vpi_put_value(0, &val, 0, vpiNoDelay) != 0) failed = 1;
      check_error("null put", 3);
      result = vpi_get(vpiSize, w);
      check_clear("get property");
      if (result != 8) failed = 1;

      if (failed) vpi_printf("FAILED\n");
      else vpi_printf("PASSED\n");
      return 0;
}

static void reg(void)
{
      s_vpi_systf_data task;
      s_cb_data cb;
      int i;
      memset(&task, 0, sizeof task);
      task.type = vpiSysTask;
      task.tfname = (PLI_BYTE8*)"$probe";
      task.calltf = probe;
      vpi_register_systf(&task);
      for (i = 0; i < 2; i += 1) {
            memset(&cb, 0, sizeof cb);
            cb.reason = i ? cbError : cbPLIError;
            cb.cb_rtn = on_error;
            if (!vpi_register_cb(&cb)) failed = 1;
      }
}

void (*vlog_startup_routines[])(void) = { reg, 0 };
