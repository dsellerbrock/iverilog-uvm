#include <string.h>
#include "vpi_user.h"

static unsigned pli_hits;

static PLI_INT32 on_error(p_cb_data cb)
{
      s_vpi_error_info info;
      const char *expected = 0;
      int level = vpi_chk_error(&info);
      if (level == vpiError) {
            switch (info.line) {
                  case 23: expected = "error 17"; break;
                  case 26: expected = "error 23"; break;
                  case 20: expected = "fatal 31"; break;
            }
      }
      if (cb->reason != cbError || !expected || info.state != vpiRun ||
          info.level != vpiError || vpi_chk_error(0) != vpiError ||
          !info.message || strcmp(info.message, expected) ||
          !info.file || strcmp(info.file, "issue1344_runtime_error.sv")) {
            vpi_printf("FAIL: subscriber %s received wrong error data\n",
                       cb->user_data);
            return 0;
      }
      vpi_printf("CB %s: %s\n", cb->user_data, info.message);
      return 0;
}

static PLI_INT32 on_error_then_vpi(p_cb_data cb)
{
      s_vpi_error_info info;
      on_error(cb);
      /* Replace the last error without recursively invoking either list. */
      vpi_get(vpiSize, 0);
      if (vpi_chk_error(&info) != vpiError || info.state != vpiPLI)
            vpi_printf("FAIL: expected a VPI error from invalid vpi_get\n");
      return 0;
}

static PLI_INT32 on_pli_error(p_cb_data cb)
{
      (void)cb;
      pli_hits += 1;
      return 0;
}

static PLI_INT32 on_end(p_cb_data cb)
{
      (void)cb;
      if (vpi_chk_error(0) != 0)
            vpi_printf("FAIL: stale error at end of simulation\n");
      vpi_printf("END pli=%u\n", pli_hits);
      return 0;
}

static void reg(void)
{
      s_cb_data cb = {0};
      cb.reason = cbError;
      cb.cb_rtn = on_error;
      cb.user_data = "B";
      if (!vpi_register_cb(&cb)) vpi_printf("FAIL: register B\n");
      /* VVP visits the most recently registered subscriber first. */
      cb.cb_rtn = on_error_then_vpi;
      cb.user_data = "A";
      if (!vpi_register_cb(&cb)) vpi_printf("FAIL: register A\n");
      cb.user_data = 0;
      cb.reason = cbPLIError;
      cb.cb_rtn = on_pli_error;
      if (!vpi_register_cb(&cb)) vpi_printf("FAIL: register cbPLIError\n");
      cb.reason = cbEndOfSimulation;
      cb.cb_rtn = on_end;
      if (!vpi_register_cb(&cb)) vpi_printf("FAIL: register end callback\n");
}

void (*vlog_startup_routines[])(void) = {reg, 0};
