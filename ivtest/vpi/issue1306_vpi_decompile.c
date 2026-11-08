/*
 * Issue #1306: vpiDecompile (Annex K value 54) returns functionally
 * equivalent text for a system task call (IEEE 1800-2023 37.42 detail 9)
 * and for an argument expression (37.59 detail 2).
 */
#include <string.h>
#include "vpi_user.h"

#define IEEE_vpiDecompile 54

static const char*expected[] = {
      "$probe(1, \"\", , null, )",
      "$probe(my_var, \"x\\\"y\", 4'b10x1, 8'shf0, a)",
};
static unsigned calls, failures;

static void check(const char*what, const char*got, const char*want)
{
      vpi_printf("%s=%s\n", what, got ? got : "<null>");
      if (!got || strcmp(got, want) != 0) {
	    vpi_printf("FAILED: expected %s\n", want);
	    failures += 1;
      }
}

static PLI_INT32 probe_calltf(PLI_BYTE8*ud)
{
      vpiHandle call = vpi_handle(vpiSysTfCall, 0);
      (void)ud;
      check("DECOMPILE", vpi_get_str(IEEE_vpiDecompile, call),
	    calls < 2 ? expected[calls] : "");
      calls += 1;
      return 0;
}

static PLI_INT32 expr_calltf(PLI_BYTE8*ud)
{
      vpiHandle it = vpi_iterate(vpiArgument, vpi_handle(vpiSysTfCall, 0));
      vpiHandle arg = it ? vpi_scan(it) : 0;
      (void)ud;
      if (it && arg) vpi_free_object(it);
      check("EXPR_DECOMPILE", arg ? vpi_get_str(IEEE_vpiDecompile, arg) : 0, "3");
      if (calls == 2 && failures == 0) vpi_printf("VPI DECOMPILE PASS\nPASSED\n");
      return 0;
}

static void reg(void)
{
      s_vpi_systf_data d;
      memset(&d, 0, sizeof d);
      d.type = vpiSysTask;
      d.tfname = (PLI_BYTE8*)"$probe";
      d.calltf = probe_calltf;
      vpi_register_systf(&d);
      d.tfname = (PLI_BYTE8*)"$exprprobe";
      d.calltf = expr_calltf;
      vpi_register_systf(&d);
}

void (*vlog_startup_routines[])(void) = { reg, 0 };
