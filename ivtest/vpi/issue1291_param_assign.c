#include <stdio.h>
#include <string.h>
#include <vpi_user.h>

/* Keep the regression source compilable against the pre-fix VPI header. */
#ifndef vpiParamAssign
#define vpiParamAssign 40
#endif
#ifndef vpiLhs
#define vpiLhs 77
#endif
#ifndef vpiRhs
#define vpiRhs 82
#endif

static int count_param_assignments(const char *name, vpiHandle *first)
{
      vpiHandle scope = vpi_handle_by_name((PLI_BYTE8*)name, NULL);
      vpiHandle iter = scope ? vpi_iterate(vpiParamAssign, scope) : NULL;
      vpiHandle item;
      int count = 0;

      if (first) *first = NULL;
      while (iter && (item = vpi_scan(iter))) {
	    if (first && !*first) *first = item;
	    count += 1;
      }
      return count;
}

static PLI_INT32 probe(p_cb_data cb)
{
      (void)cb;
      vpiHandle assign = NULL;
      vpiHandle lhs, rhs, parameter;
      s_vpi_value value = {0};
      int top_count = count_param_assignments("top", NULL);
      int u_count = count_param_assignments("top.u", &assign);
      int default_count = count_param_assignments("top.d", NULL);
      int pass = top_count == 0 && u_count == 1 && default_count == 0;

      lhs = assign ? vpi_handle(vpiLhs, assign) : NULL;
      rhs = assign ? vpi_handle(vpiRhs, assign) : NULL;
      parameter = vpi_handle_by_name((PLI_BYTE8*)"top.u.P", NULL);
      if (!lhs || !rhs || lhs != parameter
	  || vpi_get(vpiType, rhs) != vpiConstant
	  || vpi_get(vpiConstType, rhs) != vpiBinaryConst)
	    pass = 0;

      if (rhs) {
	    value.format = vpiIntVal;
	    vpi_get_value(rhs, &value);
	    if (value.value.integer != 8) pass = 0;
      }
      if (parameter) {
	    value.format = vpiIntVal;
	    vpi_get_value(parameter, &value);
	    if (value.value.integer != 8) pass = 0;
      }

      if (pass)
	    vpi_printf("ISSUE1291_PARAM_ASSIGN_PASS\nPASSED\n");
      else
	    vpi_printf("ISSUE1291_PARAM_ASSIGN_FAIL top=%d instance=%d default=%d\n",
		       top_count, u_count, default_count);
      vpi_control(vpiFinish, 0);
      return 0;
}

static void startup(void)
{
      s_cb_data cb = {0};
      cb.reason = cbStartOfSimulation;
      cb.cb_rtn = probe;
      vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = {startup, 0};
