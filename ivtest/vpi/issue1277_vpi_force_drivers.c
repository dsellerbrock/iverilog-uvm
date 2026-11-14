/*
 * Issue #1277 (IEEE 1800-2023 37.16 details 14-15, 37.21): vpiDriver and
 * vpiLoad include the active force and procedural assign statements. Each
 * result is written "<vpiType>@<line>": 8 cont assign, 16 force, 2 assign.
 */
#include <stdio.h>
#include <string.h>
#include "vpi_user.h"

static unsigned failures;

static void check(const char*name, int code, const char*want, int step)
{
      vpiHandle h = vpi_handle_by_name((PLI_BYTE8*)name, 0), it, x;
      char got[256] = "", one[32];
      it = h ? vpi_iterate(code, h) : 0;
      while (it && (x = vpi_scan(it))) {
	    snprintf(one, sizeof one, "%s%d@%d", *got ? " " : "",
		     (int)vpi_get(vpiType, x), (int)vpi_get(vpiLineNo, x));
	    strcat(got, one);
      }
      if (strcmp(got, want) != 0) {
	    vpi_printf("FAILED step %d: %s code %d: got \"%s\", want \"%s\"\n",
		       step, name, code, got, want);
	    failures += 1;
      }
}

static PLI_INT32 probe_calltf(PLI_BYTE8*ud)
{
      vpiHandle call = vpi_handle(vpiSysTfCall, 0);
      vpiHandle args = vpi_iterate(vpiArgument, call), it, x;
      s_vpi_value val;
      int step;
      (void)ud;
      val.format = vpiIntVal;
      vpi_get_value(vpi_scan(args), &val);
      vpi_free_object(args);
      step = val.value.integer;

      switch (step) {
	  case 1:
	    check("top.scalar", vpiDriver, "8@8 16@11", step);
	    check("top.scalar", vpiLocalDriver, "8@8 16@11", step);
	    check("top.vec[0]", vpiDriver, "8@9 16@12", step);
	    check("top.vec[3]", vpiDriver, "8@9", step);
	    check("top.r", vpiLoad, "16@11 2@13", step);
	    check("top.q", vpiDriver, "2@13", step);
	      /* The force's own relations. */
	    it = vpi_iterate(vpiDriver,
			     vpi_handle_by_name((PLI_BYTE8*)"top.scalar", 0));
	    while (it && (x = vpi_scan(it))) {
		  if (vpi_get(vpiType, x) != vpiForce) continue;
		  if (strcmp(vpi_get_str(vpiFullName, vpi_handle(vpiLhs, x)),
			     "top.scalar") != 0
		      || strcmp(vpi_get_str(vpiFullName, vpi_handle(vpiRhs, x)),
				"top.r") != 0) {
			vpi_printf("FAILED: force vpiLhs/vpiRhs\n");
			failures += 1;
		  }
	    }
	    break;
	  case 2:
	    check("top.scalar", vpiDriver, "8@8 16@15", step);
	    check("top.r", vpiLoad, "2@13", step);
	    check("top.q", vpiLoad, "16@15", step);
	    break;
	  case 3:
	    check("top.scalar", vpiDriver, "8@8", step);
	    check("top.vec[0]", vpiDriver, "8@9 16@12", step);
	    check("top.q", vpiDriver, "", step);
	    check("top.r", vpiLoad, "", step);
	    if (failures == 0)
		  vpi_printf("VPI FORCE DRIVERS PASS\nPASSED\n");
	    break;
      }
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
