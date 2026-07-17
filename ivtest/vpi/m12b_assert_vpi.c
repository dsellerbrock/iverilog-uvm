/*
 * M12B: exercise the concurrent-assertion VPI object model. The design
 * declares three concurrent assertions; $check_assertions verifies that
 * vpi_iterate(vpiAssertion, NULL) enumerates all three with a name, a
 * positive line number, and a vpiScope handle, and that the scope-scoped
 * form vpi_iterate(vpiAssertion, top) returns the same set. Output is a
 * single deterministic line so the gold diff is stable regardless of
 * enumeration order or internal numbering.
 */
#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <stdio.h>
#include <string.h>

static PLI_INT32 check_calltf(PLI_BYTE8*name)
{
      vpiHandle it, a;
      int count = 0, scoped = 0, bad = 0;
      (void)name;

      it = vpi_iterate(vpiAssertion, NULL);
      if (it) {
	    while ((a = vpi_scan(it))) {
		  char*nm = vpi_get_str(vpiName, a);
		  int   ln = vpi_get(vpiLineNo, a);
		  vpiHandle sc = vpi_handle(vpiScope, a);
		  if (!nm || nm[0] == 0) bad += 1;
		  if (ln <= 0) bad += 1;
		  if (!sc) bad += 1;
		  count += 1;
	    }
      }

      {
	    vpiHandle mods = vpi_iterate(vpiModule, NULL);
	    vpiHandle top = mods ? vpi_scan(mods) : NULL;
	    if (mods) vpi_free_object(mods);
	    if (top) {
		  vpiHandle sit = vpi_iterate(vpiAssertion, top);
		  if (sit) while ((a = vpi_scan(sit))) scoped += 1;
	    }
      }

      if (count == 3 && scoped == 3 && bad == 0)
	    vpi_printf("PASS: m12b assertion vpi (global=%d scoped=%d)\n",
		       count, scoped);
      else
	    vpi_printf("FAIL: m12b assertion vpi (global=%d scoped=%d bad=%d)\n",
		       count, scoped, bad);
      return 0;
}

static void register_check(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type   = vpiSysTask;
      tf.tfname = "$check_assertions";
      tf.calltf = check_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_check, 0 };
