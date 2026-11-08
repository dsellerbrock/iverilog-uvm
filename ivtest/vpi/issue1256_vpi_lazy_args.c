/*
 * Issue #1256: argument expressions are vpiOperation trees, available at
 * compiletf, and evaluated only by vpi_get_value (IEEE 1800-2023 36.10.3,
 * 37.42 detail 7).
 */
#include <string.h>
#include "vpi_user.h"

#define IEEE_vpiOperand 97
#define IEEE_vpiAddOp 24

static unsigned failures;

static vpiHandle first_arg(void)
{
      vpiHandle it = vpi_iterate(vpiArgument, vpi_handle(vpiSysTfCall, 0));
      vpiHandle arg = it ? vpi_scan(it) : 0;
      if (it && arg) vpi_free_object(it);
      return arg;
}

static int walk(vpiHandle h)
{
      int n = 1;
      if (h && vpi_get(vpiType, h) == vpiOperation) {
	    vpiHandle it = vpi_iterate(IEEE_vpiOperand, h), x;
	    while (it && (x = vpi_scan(it))) n += walk(x);
      }
      return n;
}

static void put_int(int value)
{
      s_vpi_value v;
      v.format = vpiIntVal;
      v.value.integer = value;
      vpi_put_value(vpi_handle(vpiSysTfCall, 0), &v, 0, vpiNoDelay);
}

static int get_int(vpiHandle h)
{
      s_vpi_value v;
      v.format = vpiIntVal;
      vpi_get_value(h, &v);
      return v.value.integer;
}

static PLI_INT32 expr_compiletf(PLI_BYTE8*ud)
{
      vpiHandle arg = first_arg();
      (void)ud;
      if (!arg || vpi_get(vpiType, arg) != vpiOperation
	  || vpi_get(vpiOpType, arg) != IEEE_vpiAddOp || walk(arg) != 5) {
	    vpi_printf("FAILED: compiletf saw type=%d op=%d nodes=%d\n",
		       arg ? vpi_get(vpiType, arg) : -1,
		       arg ? vpi_get(vpiOpType, arg) : -1, arg ? walk(arg) : 0);
	    failures += 1;
      }
      return 0;
}

static PLI_INT32 expr_calltf(PLI_BYTE8*ud) { (void)ud; put_int(walk(first_arg())); return 0; }
static PLI_INT32 noeval_calltf(PLI_BYTE8*ud) { (void)ud; (void)first_arg(); return 0; }
static PLI_INT32 value_calltf(PLI_BYTE8*ud) { (void)ud; put_int(get_int(first_arg())); return 0; }

static PLI_INT32 twice_calltf(PLI_BYTE8*ud)
{
      vpiHandle arg = first_arg();
      int x = get_int(arg), y = get_int(arg);
      (void)ud;
      put_int(x + y);
      return 0;
}

static PLI_INT32 end_cb(p_cb_data cb)
{
      (void)cb;
      if (failures == 0) vpi_printf("VPI LAZY PASS\nPASSED\n");
      return 0;
}

static void reg_func(const char*name, PLI_INT32 (*calltf)(PLI_BYTE8*),
		     PLI_INT32 (*compiletf)(PLI_BYTE8*))
{
      s_vpi_systf_data d;
      memset(&d, 0, sizeof d);
      d.type = vpiSysFunc;
      d.sysfunctype = vpiIntFunc;
      d.tfname = (PLI_BYTE8*)name;
      d.calltf = calltf;
      d.compiletf = compiletf;
      vpi_register_systf(&d);
}

static void reg(void)
{
      s_vpi_systf_data d;
      s_cb_data cb;
      reg_func("$expr", expr_calltf, expr_compiletf);
      reg_func("$value", value_calltf, 0);
      reg_func("$twice", twice_calltf, 0);
      memset(&d, 0, sizeof d);
      d.type = vpiSysTask;
      d.tfname = (PLI_BYTE8*)"$noeval";
      d.calltf = noeval_calltf;
      vpi_register_systf(&d);
      memset(&cb, 0, sizeof cb);
      cb.reason = cbEndOfSimulation;
      cb.cb_rtn = end_cb;
      vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = { reg, 0 };
