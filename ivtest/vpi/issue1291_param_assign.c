#include <stdio.h>
#include <string.h>
#include <vpi_user.h>

#ifndef vpiParamAssign
#define vpiParamAssign 40
#endif
#ifndef vpiConnByName
#define vpiConnByName 21
#endif
#ifndef vpiLhs
#define vpiLhs 77
#endif
#ifndef vpiRhs
#define vpiRhs 82
#endif

static int count_parameter_assignments(vpiHandle scope)
{
  vpiHandle iter = vpi_iterate(vpiParamAssign, scope);
  vpiHandle item;
  int count = 0;
  while (iter && (item = vpi_scan(iter)))
    ++count;
  return count;
}

static int integer_value(vpiHandle item)
{
  s_vpi_value value;
  value.format = vpiIntVal;
  vpi_get_value(item, &value);
  return value.value.integer;
}

static PLI_INT32 probe(p_cb_data cb)
{
  (void)cb;
  vpiHandle top = vpi_handle_by_name((PLI_BYTE8*)"top", NULL);
  vpiHandle child = vpi_handle_by_name((PLI_BYTE8*)"top.u", NULL);
  vpiHandle iter = child ? vpi_iterate(vpiParamAssign, child) : NULL;
  vpiHandle assign = iter ? vpi_scan(iter) : NULL;
  vpiHandle lhs = assign ? vpi_handle(vpiLhs, assign) : NULL;
  vpiHandle rhs = assign ? vpi_handle(vpiRhs, assign) : NULL;
  char *lhs_name = lhs ? vpi_get_str(vpiName, lhs) : NULL;

  if (!top || !child || count_parameter_assignments(top) != 0 ||
      count_parameter_assignments(child) != 1 || !assign ||
      vpi_get(vpiType, assign) != vpiParamAssign ||
      vpi_get(vpiConnByName, assign) != 1 || !lhs || !rhs ||
      !lhs_name || strcmp(lhs_name, "P") != 0 ||
      vpi_get(vpiType, lhs) != vpiParameter ||
      vpi_get(vpiType, rhs) != vpiConstant || integer_value(rhs) != 8) {
    vpi_printf("PARAM_ASSIGN_FAIL\n");
    vpi_control(vpiFinish, 1);
    return 0;
  }

  vpi_printf("PARAM_ASSIGN_PASS\n");
  vpi_printf("PASSED\n");
  vpi_control(vpiFinish, 0);
  return 0;
}

static void startup(void)
{
  s_cb_data cb;
  memset(&cb, 0, sizeof(cb));
  cb.reason = cbStartOfSimulation;
  cb.cb_rtn = probe;
  vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = { startup, 0 };
