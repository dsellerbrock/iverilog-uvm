/*
 * Issue #3261 (IEEE 1800-2023 37.47, 37.1): vpiDelay of a continuous
 * assignment is its one delay expression, a vpiOperation vpiListOp whose
 * operands are the delays in order (rise, fall, decay), or NULL.
 */
#include <stdio.h>
#include <string.h>
#include "vpi_user.h"

static unsigned failures;

static int int_of(vpiHandle h)
{
      s_vpi_value v;
      v.format = vpiIntVal;
      vpi_get_value(h, &v);
      return v.value.integer;
}

/* The delays as "a,b,c", or "-" for none. */
static void delays_of(vpiHandle ca, char*buf, size_t len)
{
      vpiHandle d = vpi_handle(vpiDelay, ca), it, op;
      buf[0] = 0;
      if (!d) {
	    snprintf(buf, len, "-");
	    return;
      }
      if (vpi_get(vpiType, d) != vpiOperation) {
	    snprintf(buf, len, "%d", int_of(d));
	    return;
      }
      if (vpi_get(vpiOpType, d) != vpiListOp) {
	    snprintf(buf, len, "not a list");
	    return;
      }
      it = vpi_iterate(vpiOperand, d);
      while (it && (op = vpi_scan(it))) {
	    char one[16];
	    snprintf(one, sizeof one, "%s%d", *buf ? "," : "", int_of(op));
	    strncat(buf, one, len - strlen(buf) - 1);
      }
}

static PLI_INT32 probe_calltf(PLI_BYTE8*ud)
{
      static const char*want[] = { "-", "5", "7,2", "1,2,3" };
      vpiHandle it = vpi_iterate(vpiContAssign,
				 vpi_handle_by_name((PLI_BYTE8*)"top", 0)), ca;
      unsigned n = 0;
      (void)ud;
      while (it && (ca = vpi_scan(it))) {
	    char got[64];
	    unsigned line = (unsigned)vpi_get(vpiLineNo, ca);
	    if (line < 8 || line > 11) continue;
	    delays_of(ca, got, sizeof got);
	    if (strcmp(got, want[line - 8]) != 0) {
		  vpi_printf("FAILED: line %u vpiDelay %s, want %s\n", line, got,
			     want[line - 8]);
		  failures += 1;
	    }
	    n += 1;
      }
      if (n != 4) {
	    vpi_printf("FAILED: %u continuous assignments\n", n);
	    failures += 1;
      }
      if (failures == 0)
	    vpi_printf("VPI CONTASSIGN DELAY PASS\nPASSED\n");
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
