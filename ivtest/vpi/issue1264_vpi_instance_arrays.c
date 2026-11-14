/*
 * Issue #1264 (IEEE 1800-2023 37.10, 37.11): an instance array is a VPI
 * object with a name, a size, its range, indexed access to its elements
 * and its connection list; the instantiating module iterates it and each
 * element knows its array.
 */
#include <stdio.h>
#include <string.h>
#include "vpi_user.h"

#define IEEE_vpiInterfaceArray 603
#define IEEE_vpiListOp 37
#define IEEE_vpiOperand 97

static unsigned failures;

static void expect(int ok, const char*what)
{
      if (!ok) {
	    vpi_printf("FAILED: %s\n", what);
	    failures += 1;
      }
}

static int int_of(vpiHandle h)
{
      s_vpi_value v;
      v.format = vpiIntVal;
      vpi_get_value(h, &v);
      return v.value.integer;
}

static int count(vpiHandle it)
{
      int n = 0;
      while (it && vpi_scan(it)) n += 1;
      return n;
}

static int same_name(vpiHandle h, const char*full)
{
      return h && strcmp(vpi_get_str(vpiFullName, h), full) == 0;
}

static PLI_INT32 probe_calltf(PLI_BYTE8*ud)
{
      vpiHandle top = vpi_handle_by_name((PLI_BYTE8*)"top", 0);
      vpiHandle arr = vpi_handle_by_name((PLI_BYTE8*)"top.inst", 0);
      vpiHandle rev = vpi_handle_by_name((PLI_BYTE8*)"top.rev", 0);
      vpiHandle bus = vpi_handle_by_name((PLI_BYTE8*)"top.buses", 0);
      vpiHandle elem = vpi_handle_by_name((PLI_BYTE8*)"top.inst[3]", 0);
      vpiHandle one = vpi_handle_by_name((PLI_BYTE8*)"top.one", 0);
      vpiHandle it, h, expr;
      (void)ud;

      expect(arr && vpi_get(vpiType, arr) == vpiModuleArray, "inst is a module array");
      if (!arr) return 0;
      expect(strcmp(vpi_get_str(vpiName, arr), "inst") == 0, "array vpiName");
      expect(strcmp(vpi_get_str(vpiFullName, arr), "top.inst") == 0, "array vpiFullName");
      expect(vpi_get(vpiSize, arr) == 3, "array vpiSize");
      expect(int_of(vpi_handle(vpiLeftRange, arr)) == 2
	     && int_of(vpi_handle(vpiRightRange, arr)) == 4, "array bounds");
      expect(count(vpi_iterate(vpiRange, arr)) == 1, "one range");
      expect(vpi_handle_by_index(arr, 3) == elem, "index 3 is inst[3]");
      expect(vpi_handle_by_index(arr, 5) == 0, "index 5 is out of range");
      it = vpi_iterate(vpiModule, arr);
      h = it ? vpi_scan(it) : 0;
      expect(same_name(h, "top.inst[2]"), "first element is inst[2]");
      if (it && h) vpi_free_object(it);
      expect(count(vpi_iterate(vpiModule, arr)) == 3, "three elements");
      expect(vpi_handle(vpiModuleArray, elem) == arr, "element's module array");
      expect(vpi_handle(vpiInstanceArray, elem) == arr, "element's instance array");
      expect(vpi_handle(vpiModuleArray, one) == 0, "a single instance has no array");
      expect(vpi_handle(vpiScope, arr) == top, "array scope");

	/* 37.11 detail 1: the connection list. */
      expr = vpi_handle(vpiExpr, arr);
      expect(expr && vpi_get(vpiType, expr) == vpiOperation
	     && vpi_get(vpiOpType, expr) == IEEE_vpiListOp, "connections are a list");
      if (expr) {
	    it = vpi_iterate(IEEE_vpiOperand, expr);
	    h = it ? vpi_scan(it) : 0;
	    expect(same_name(h, "top.a"), "first connection is a");
	    if (it && h) vpi_free_object(it);
	    expect(count(vpi_iterate(IEEE_vpiOperand, expr)) == 2, "two connections");
      }

	/* A descending range indexes by the declared address. */
      expect(rev && vpi_handle_by_index(rev, 0)
	     == vpi_handle_by_name((PLI_BYTE8*)"top.rev[0]", 0), "rev index 0");

	/* An interface array, and the parent's iterations. */
      expect(bus && vpi_get(vpiType, bus) == IEEE_vpiInterfaceArray
	     && vpi_get(vpiSize, bus) == 2, "buses is an interface array");
      expect(count(vpi_iterate(vpiModuleArray, top)) == 2, "two module arrays");
      expect(count(vpi_iterate(vpiInstanceArray, top)) == 3, "three instance arrays");

      if (failures == 0)
	    vpi_printf("VPI INSTANCE ARRAYS PASS\nPASSED\n");
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
