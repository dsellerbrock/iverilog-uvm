/*
 * IEEE 1800-2023 37.26: vpiMember on a packed struct/union variable, and
 * vpi_handle_by_name below it. Prints PASS when every check holds.
 */
#include <stdio.h>
#include <string.h>
#include "sv_vpi_user.h"

static int fails = 0;

static void check(int ok, const char*what)
{
      if (!ok) { fails += 1; vpi_printf("FAIL: %s\n", what); }
}

static const char*bin(vpiHandle h)
{
      s_vpi_value v;
      v.format = vpiBinStrVal;
      vpi_get_value(h, &v);
      return v.value.str;
}

static PLI_INT32 probe(PLI_BYTE8*ud)
{
      static const char*names[] = { "hi", "mid", "lo" };
      static const char*vals[] = { "1010", "0110", "0101" };
      static const int sizes[] = { 4, 4, 4 };
      vpiHandle ps = vpi_handle_by_name((PLI_BYTE8*)"top.ps", 0);
      vpiHandle it, m, hi, b, w;
      int idx = 0;
      s_vpi_value v;
      (void)ud;

      it = vpi_iterate(vpiMember, ps);
      check(it != 0, "vpiMember iterator on top.ps");
      while (it && (m = vpi_scan(it))) {
	    vpi_printf("member %s size=%d value=%s\n", vpi_get_str(vpiName, m),
		       (int)vpi_get(vpiSize, m), bin(m));
	    check(idx < 3 && strcmp(vpi_get_str(vpiName, m), names[idx]) == 0, "member name");
	    check(idx < 3 && vpi_get(vpiSize, m) == sizes[idx], "member size");
	    check(idx < 3 && strcmp(bin(m), vals[idx]) == 0, "member value");
	    check(vpi_handle(vpiParent, m) == ps, "member parent");
	    check(vpi_get(vpiStructUnionMember, m) == 1, "vpiStructUnionMember");
	    idx += 1;
      }
      check(idx == 3, "three members");

      hi = vpi_handle_by_name((PLI_BYTE8*)"top.ps.hi", 0);
      check(hi != 0, "by name top.ps.hi");
      if (hi) {
	    vpi_printf("by name %s value=%s\n", vpi_get_str(vpiFullName, hi), bin(hi));
	    check(strcmp(vpi_get_str(vpiFullName, hi), "top.ps.hi") == 0, "full name");
	    v.format = vpiIntVal;
	    v.value.integer = 3;
	    vpi_put_value(hi, &v, 0, vpiNoDelay);
	    check(strcmp(bin(ps), "001101100101") == 0, "write through member");
      }

      b = vpi_handle_by_name((PLI_BYTE8*)"top.ps.mid.b", 0);
      check(b != 0, "nested member top.ps.mid.b");
      if (b) {
	    check(vpi_get(vpiSize, b) == 2 && strcmp(bin(b), "10") == 0, "nested value");
	    check(vpi_get(vpiType, vpi_handle_by_name((PLI_BYTE8*)"top.ps.mid.a", 0)) == vpiBitVar,
		  "bit member type");
	    check(vpi_get(vpiType, vpi_handle(vpiParent, b)) == vpiStructVar, "nested parent type");
      }

      w = vpi_handle_by_name((PLI_BYTE8*)"top.pu.v", 0);
      check(w != 0 && strcmp(bin(w), "00111100") == 0, "union member");

      if (fails == 0) vpi_printf("VPI PACKED MEMBER PASS\nPASSED\n");
      return 0;
}

static void reg(void)
{
      s_vpi_systf_data d;
      memset(&d, 0, sizeof d);
      d.type = vpiSysTask;
      d.tfname = "$probe";
      d.calltf = probe;
      vpi_register_systf(&d);
}

void (*vlog_startup_routines[])(void) = { reg, 0 };
