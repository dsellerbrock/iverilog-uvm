/*
 * Issue #2825 / #1344 (IEEE 1800-2023 38.2, 38.36.3): after a vpi_get()
 * of an unknown property, vpi_chk_error() reports vpiError with state
 * vpiPLI, and the registered cbPLIError and cbError callbacks run once;
 * after a successful vpi_get() it reports 0.
 */
#include <stdio.h>
#include <string.h>
#include "vpi_user.h"

#ifndef cbPLIError
#define cbPLIError 28
#endif
#ifndef vpiPLI
#define vpiPLI 2
#endif

static int pli_errors, errors;

static PLI_INT32 on_error(p_cb_data cb)
{
      if (cb->reason == cbPLIError) pli_errors += 1;
      if (cb->reason == cbError) errors += 1;
      return 0;
}

static PLI_INT32 probe(PLI_BYTE8*ud)
{
      vpiHandle v = vpi_handle_by_name((PLI_BYTE8*)"top.v", 0);
      s_vpi_error_info e;
      int ret, level, ok = 1;
      (void)ud;
      ret = vpi_get(999, v);
      level = vpi_chk_error(&e);
      vpi_printf("BAD ret=%d level=%d state=%d callbacks=%d/%d\n", ret, level,
		 level ? (int)e.state : 0, pli_errors, errors);
      ok = ok && ret == vpiUndefined && level == vpiError && e.state == vpiPLI
	    && e.message && strstr(e.message, "999") && pli_errors == 1
	    && errors == 1;
      ret = vpi_get(vpiSize, v);
      level = vpi_chk_error(&e);
      vpi_printf("GOOD ret=%d level=%d callbacks=%d/%d\n", ret, level,
		 pli_errors, errors);
      ok = ok && ret == 8 && level == 0 && pli_errors == 1 && errors == 1;
      if (ok) vpi_printf("VPI CHK ERROR PASS\nPASSED\n");
      return 0;
}

static void reg(void)
{
      s_vpi_systf_data d;
      s_cb_data cb;
      int reason;
      memset(&d, 0, sizeof d);
      d.type = vpiSysTask;
      d.tfname = (PLI_BYTE8*)"$probe";
      d.calltf = probe;
      vpi_register_systf(&d);
      for (reason = 0; reason < 2; reason += 1) {
	    memset(&cb, 0, sizeof cb);
	    cb.reason = reason ? cbError : cbPLIError;
	    cb.cb_rtn = on_error;
	    if (!vpi_register_cb(&cb))
		  vpi_printf("FAILED: register %s\n", reason ? "cbError" : "cbPLIError");
      }
}

void (*vlog_startup_routines[])(void) = { reg, 0 };
