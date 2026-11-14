/*
 * Issue #1315 (IEEE 1800-2023 37.58): vpi_iterate(vpiUse, obj). Each use is
 * written "assign@<line>" or "port <instance>.<port>".
 */
#include <stdio.h>
#include <string.h>
#include "vpi_user.h"

static unsigned failures;

static void check(const char*name, const char*want)
{
      vpiHandle h = vpi_handle_by_name((PLI_BYTE8*)name, 0), it, x;
      char got[256] = "", one[96];
      it = h ? vpi_iterate(vpiUse, h) : 0;
      while (it && (x = vpi_scan(it))) {
	    if (vpi_get(vpiType, x) == vpiContAssign)
		  snprintf(one, sizeof one, "assign@%d", (int)vpi_get(vpiLineNo, x));
	    else if (vpi_get(vpiType, x) == vpiPort) {
		  char mod[64];
		  snprintf(mod, sizeof mod, "%s",
			   vpi_get_str(vpiFullName, vpi_handle(vpiModule, x)));
		  snprintf(one, sizeof one, "port %s.%s", mod,
			   vpi_get_str(vpiName, x));
	    } else
		  snprintf(one, sizeof one, "type %d", (int)vpi_get(vpiType, x));
	    if (*got) strcat(got, ", ");
	    strcat(got, one);
      }
      if (strcmp(got, want) != 0) {
	    vpi_printf("FAILED: vpiUse %s: got \"%s\", want \"%s\"\n", name, got, want);
	    failures += 1;
      }
}

static PLI_INT32 probe_calltf(PLI_BYTE8*ud)
{
      (void)ud;
      check("top.data", "assign@12, assign@13, assign@14, port top.c.p");
	/* The bit: its own use, the whole vector's, the containing select's. */
      check("top.data[2]", "assign@12, assign@13, assign@14");
      check("top.data[5]", "assign@12, port top.c.p");
      check("top.data[0]", "assign@12");
      check("top.whole", "assign@12");
      if (failures == 0)
	    vpi_printf("VPI USE PASS\nPASSED\n");
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$probe";
      tf.calltf = probe_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
