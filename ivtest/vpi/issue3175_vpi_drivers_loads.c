/*
 * Issue #3175 (IEEE 1800-2023 37.16, 37.21, 37.46): vpiDriver, vpiLoad,
 * vpiLocalDriver and vpiLocalLoad return the continuous assignments and
 * ports connected to a net, variable, bit, array or array word. Each
 * result is written "assign@<line>" or "port <instance>.<port>".
 */
#include <stdio.h>
#include <string.h>
#include "vpi_user.h"

static unsigned failures;

static void describe(vpiHandle h, char*buf, size_t len)
{
      if (vpi_get(vpiType, h) == vpiContAssign) {
	    snprintf(buf, len, "assign@%d", (int)vpi_get(vpiLineNo, h));
      } else if (vpi_get(vpiType, h) == vpiPort) {
	    char mod[128];
	    snprintf(mod, sizeof mod, "%s",
		     vpi_get_str(vpiFullName, vpi_handle(vpiModule, h)));
	    snprintf(buf, len, "port %s.%s", mod, vpi_get_str(vpiName, h));
      } else {
	    snprintf(buf, len, "type %d", (int)vpi_get(vpiType, h));
      }
}

static void check(const char*name, int code, const char*want)
{
      vpiHandle h = vpi_handle_by_name((PLI_BYTE8*)name, 0), it, x;
      char got[512] = "", one[160];
      if (!h) {
	    vpi_printf("FAILED: no handle for %s\n", name);
	    failures += 1;
	    return;
      }
      it = vpi_iterate(code, h);
      while (it && (x = vpi_scan(it))) {
	    describe(x, one, sizeof one);
	    if (*got) strcat(got, ", ");
	    strcat(got, one);
      }
      if (strcmp(got, want) != 0) {
	    vpi_printf("FAILED: %s code %d: got \"%s\", want \"%s\"\n",
		       name, code, got, want);
	    failures += 1;
      }
}

static int int_value(vpiHandle h)
{
      s_vpi_value v;
      v.format = vpiIntVal;
      vpi_get_value(h, &v);
      return v.value.integer;
}

static PLI_INT32 probe_calltf(PLI_BYTE8*ud)
{
      vpiHandle it, ca, sel;
      int found = 0;
      (void)ud;

	/* Net drivers and loads, local and through the hierarchy. */
      check("top.scalar", vpiDriver, "assign@17");
      check("top.scalar", vpiLocalDriver, "assign@17");
      check("top.scalar", vpiLoad, "assign@4");
      check("top.scalar", vpiLocalLoad, "port top.c2.ci");
      check("top.vec", vpiDriver, "assign@18, assign@23");
      check("top.vec", vpiLocalLoad,
	    "assign@19, port top.c1.cv, port top.c2.cv");
      check("top.vec[2]", vpiLocalLoad, "assign@19, port top.c1.cv");
      check("top.vec[0]", vpiLocalDriver, "assign@18, assign@23");
      check("top.vec[0]", vpiLoad, "port top.c2.cv");
      check("top.trinet", vpiDriver, "assign@4");
      check("top.trinet", vpiLocalDriver, "port top.c2.co");
      check("top.trinet", vpiLoad, "port top.c1.ci");
      check("top.c1.ci", vpiDriver, "port top.c1.ci");
      check("top.c1.co", vpiLoad, "");
      check("top.c1.co", vpiLocalLoad, "port top.c1.co");
      check("top.o1", vpiLocalDriver, "port top.c1.co");
      check("top.warr", vpiLocalLoad, "assign@22");
      check("top.warr[1]", vpiLoad, "assign@22");
      check("top.warr[0]", vpiLoad, "");

	/* Variables: vpiDriver and vpiLoad only (37.21). */
      check("top.s", vpiLoad, "assign@21");
      check("top.s", vpiLocalLoad, "");
      check("top.outs", vpiDriver, "assign@21");
      check("top.arr", vpiLoad, "assign@20");
      check("top.arr[0]", vpiLoad, "assign@20");
      check("top.arr[1]", vpiLoad, "");

	/* The select an assignment reads keeps its parent and index. */
      it = vpi_iterate(vpiLoad, vpi_handle_by_name((PLI_BYTE8*)"top.vec[2]", 0));
      while (it && (ca = vpi_scan(it))) {
	    if (vpi_get(vpiType, ca) != vpiContAssign) continue;
	    sel = vpi_handle(vpiRhs, ca);
	    found = 1;
	    if (vpi_get(vpiType, sel) != vpiBitSelect
		|| strcmp(vpi_get_str(vpiFullName, vpi_handle(vpiParent, sel)),
			  "top.vec") != 0
		|| int_value(vpi_handle(vpiIndex, sel)) != 2) {
		  vpi_printf("FAILED: vec[2] select relations\n");
		  failures += 1;
	    }
      }
      if (!found) {
	    vpi_printf("FAILED: no assignment loads vec[2]\n");
	    failures += 1;
      }
      it = vpi_iterate(vpiDriver, vpi_handle_by_name((PLI_BYTE8*)"top.vec[0]", 0));
      while (it && (ca = vpi_scan(it))) {
	    sel = vpi_handle(vpiLhs, ca);
	    if (vpi_get(vpiType, sel) != vpiPartSelect) continue;
	    if (int_value(vpi_handle(vpiLeftRange, sel)) != 1
		|| int_value(vpi_handle(vpiRightRange, sel)) != 0) {
		  vpi_printf("FAILED: vec[1:0] select range\n");
		  failures += 1;
	    }
      }

      if (failures == 0)
	    vpi_printf("VPI DRIVERS LOADS PASS\nPASSED\n");
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
