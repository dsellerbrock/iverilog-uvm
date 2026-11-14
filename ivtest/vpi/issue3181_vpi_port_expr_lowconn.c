/*
 * Issue #3181 (IEEE 1800-2023 23.2.2.1, 37.14): vpiLowConn of a port whose
 * formal is a port expression is that expression: a concatenation, a
 * part-select or another net; a plain port keeps its own net.
 */
#include <stdio.h>
#include <string.h>
#include "vpi_user.h"

#define IEEE_vpiOperand 97
#define IEEE_vpiDecompile 54

static unsigned failures;

static vpiHandle low_of(int index)
{
      vpiHandle it = vpi_iterate(vpiPort,
				 vpi_handle_by_name((PLI_BYTE8*)"top.c", 0)), p;
      while (it && (p = vpi_scan(it)))
	    if (vpi_get(vpiPortIndex, p) == index) {
		  vpi_free_object(it);
		  return vpi_handle(vpiLowConn, p);
	    }
      return 0;
}

static void expect_name(vpiHandle h, const char*what, const char*full)
{
      const char*got = h ? vpi_get_str(vpiFullName, h) : 0;
      if (!got || strcmp(got, full) != 0) {
	    vpi_printf("FAILED: %s is %s, want %s\n", what,
		       got ? got : "NULL", full);
	    failures += 1;
      }
}

static PLI_INT32 probe_calltf(PLI_BYTE8*ud)
{
      vpiHandle p = low_of(0), q = low_of(1), r = low_of(2), s = low_of(3);
      vpiHandle it, op;
      const char*want[] = { "top.c.x", "top.c.y" };
      int n = 0;
      (void)ud;

	/* .p({x, y}): a concatenation of the two nets. */
      if (!p || vpi_get(vpiType, p) != vpiOperation
	  || vpi_get(vpiOpType, p) != vpiConcatOp) {
	    vpi_printf("FAILED: p low conn is not a concatenation\n");
	    failures += 1;
      } else {
	    it = vpi_iterate(IEEE_vpiOperand, p);
	    while (it && (op = vpi_scan(it))) {
		  if (n < 2) expect_name(op, "p operand", want[n]);
		  n += 1;
	    }
	    if (n != 2) {
		  vpi_printf("FAILED: p has %d operands\n", n);
		  failures += 1;
	    }
      }
	/* .q(z[1:0]): a part-select of z. */
      if (!q || vpi_get(vpiType, q) != vpiPartSelect) {
	    vpi_printf("FAILED: q low conn is not a part-select\n");
	    failures += 1;
      } else {
	    const char*text = vpi_get_str(IEEE_vpiDecompile, q);
	    if (!text || strcmp(text, "z[1:0]") != 0) {
		  vpi_printf("FAILED: q decompiles to %s\n", text ? text : "NULL");
		  failures += 1;
	    }
      }
	/* .r(w): another net. s: its own net. */
      expect_name(r, "r low conn", "top.c.w");
      expect_name(s, "s low conn", "top.c.s");

      if (failures == 0)
	    vpi_printf("VPI PORT EXPR LOWCONN PASS\nPASSED\n");
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
