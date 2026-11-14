/*
 * Issues #1290 and #1292 (IEEE 1800-2023 37.28): vpiExpr of a value
 * parameter returns its default expression, and vpi_iterate(vpiDefParam,
 * module) returns the module's defparam statements with vpiLhs (the
 * parameter) and vpiRhs (the r-value expression).
 *
 * A default that refers to another parameter is evaluated in the
 * declaring instance after overrides (provisional reading; IEEE does not
 * settle it): top.u2.Q's default P + 1 reads 11 because u2 sets P = 10.
 */
#include <stdio.h>
#include <string.h>
#include "vpi_user.h"

#define IEEE_vpiDefParam 10
#define IEEE_vpiOperation 39
#define IEEE_vpiAddOp 24
#define IEEE_vpiDecompile 54

static unsigned failures;

static void expect(int ok, const char*what)
{
      if (!ok) {
	    vpi_printf("FAILED: %s\n", what);
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

/* Check NAME's value and its default expression's value and type. */
static void check_param(const char*name, int value, int def, int def_type)
{
      vpiHandle p = vpi_handle_by_name((PLI_BYTE8*)name, 0);
      vpiHandle e = p ? vpi_handle(vpiExpr, p) : 0;
      char what[96];
      vpi_printf("%s value=%d default=%d type=%d\n", name,
		 p ? int_value(p) : -1, e ? int_value(e) : -1,
		 e ? (int)vpi_get(vpiType, e) : -1);
      snprintf(what, sizeof what, "%s", name);
      expect(p && e && int_value(p) == value && int_value(e) == def
	     && vpi_get(vpiType, e) == def_type, what);
}

static PLI_INT32 probe_calltf(PLI_BYTE8*ud)
{
      (void)ud;
      check_param("top.A", 1, 1, vpiConstant);
      check_param("top.u1.P", 4, 4, vpiConstant);
      check_param("top.u1.Q", 5, 5, IEEE_vpiOperation);
      check_param("top.u1.N", 9, 9, vpiConstant);
      check_param("top.u2.P", 10, 4, vpiConstant);
      check_param("top.u2.Q", 11, 11, IEEE_vpiOperation);
      check_param("top.u2.N", 2, 9, vpiConstant);
      check_param("top.u3.P", 7, 4, vpiConstant);

      {
	    vpiHandle q = vpi_handle_by_name((PLI_BYTE8*)"top.u1.Q", 0);
	    vpiHandle e = q ? vpi_handle(vpiExpr, q) : 0;
	    char*text = e ? vpi_get_str(IEEE_vpiDecompile, e) : 0;
	    vpi_printf("top.u1.Q default text=%s op=%d\n", text ? text : "<null>",
		       e ? (int)vpi_get(vpiOpType, e) : -1);
	    expect(text && !strcmp(text, "P + 1")
		   && vpi_get(vpiOpType, e) == IEEE_vpiAddOp, "Q default text");
      }

      {
	    vpiHandle top = vpi_handle_by_name((PLI_BYTE8*)"top", 0);
	    vpiHandle u1 = vpi_handle_by_name((PLI_BYTE8*)"top.u1", 0);
	    vpiHandle it = vpi_iterate(IEEE_vpiDefParam, top), dp, first = 0;
	    unsigned count = 0;
	    while (it && (dp = vpi_scan(it))) {
		  if (!first) first = dp;
		  count += 1;
	    }
	    vpi_printf("DEFPARAM_COUNT=%u\n", count);
	    expect(count == 1, "one defparam in top");
	    expect(vpi_iterate(IEEE_vpiDefParam, u1) == 0, "no defparam in u1");
	    if (first) {
		  vpiHandle lhs = vpi_handle(vpiLhs, first);
		  vpiHandle rhs = vpi_handle(vpiRhs, first);
		  char*name = lhs ? vpi_get_str(vpiFullName, lhs) : 0;
		  char lhs_name[64];
		  snprintf(lhs_name, sizeof lhs_name, "%s", name ? name : "<null>");
		  char*text = rhs ? vpi_get_str(IEEE_vpiDecompile, rhs) : 0;
		  vpi_printf("defparam lhs=%s rhs=%s value=%d line=%d\n", lhs_name,
			     text ? text : "<null>", rhs ? int_value(rhs) : -1,
			     (int)vpi_get(vpiLineNo, first));
		  expect(!strcmp(lhs_name, "top.u3.P"), "defparam lhs");
		  expect(rhs && vpi_get(vpiType, rhs) == IEEE_vpiOperation
			 && int_value(rhs) == 7, "defparam rhs");
		  expect(text && !strcmp(text, "A + 6"), "defparam rhs text");
		  expect(vpi_get(vpiLineNo, first) == 13, "defparam line");
		  expect(vpi_handle(vpiParent, first) == top, "defparam parent");
	    }
      }
      if (failures == 0) vpi_printf("VPI PARAM DEFAULT PASS\nPASSED\n");
      return 0;
}

static void reg(void)
{
      s_vpi_systf_data d;
      memset(&d, 0, sizeof d);
      d.type = vpiSysTask;
      d.tfname = (PLI_BYTE8*)"$pprobe";
      d.calltf = probe_calltf;
      vpi_register_systf(&d);
}

void (*vlog_startup_routines[])(void) = { reg, 0 };
