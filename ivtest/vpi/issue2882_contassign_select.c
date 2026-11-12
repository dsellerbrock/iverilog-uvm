/*
 * Issue #2882: every continuous assignment of top is a cont assign object,
 * including those with a bit- or part-select r-value and those with a
 * part-select or concatenation l-value (IEEE 1800-2023 37.47).
 */
#include <stdio.h>
#include <string.h>
#include "vpi_user.h"

#define IEEE_vpiDecompile 54

static const char*expected[] = {
      "line=12 lhs=o1 rhs=src[2:1] value=11",
      "line=13 lhs=o2 rhs=src[0] value=0",
      "line=14 lhs=cat[3:0] rhs=src value=0110",
      "line=15 lhs={hi, lo} rhs=src value=0110",
      "line=16 lhs=o3 rhs=asc[1:3] value=110",
};

static void text_of(vpiHandle h, char*buf, size_t len)
{
      char*text = h ? vpi_get_str(IEEE_vpiDecompile, h) : 0;
      snprintf(buf, len, "%s", text ? text : "<null>");
}

static PLI_INT32 probe(PLI_BYTE8*ud)
{
      vpiHandle top = vpi_handle_by_name((PLI_BYTE8*)"top", 0);
      vpiHandle it = vpi_iterate(vpiContAssign, top), ca;
      unsigned n = 0, failures = 0;
      (void)ud;
      while (it && (ca = vpi_scan(it))) {
	    char lhs[64], rhs[64], line[160];
	    s_vpi_value v;
	    v.format = vpiBinStrVal;
	    vpi_get_value(ca, &v);
	    text_of(vpi_handle(vpiLhs, ca), lhs, sizeof lhs);
	    text_of(vpi_handle(vpiRhs, ca), rhs, sizeof rhs);
	    snprintf(line, sizeof line, "line=%d lhs=%s rhs=%s value=%s",
		     (int)vpi_get(vpiLineNo, ca), lhs, rhs, v.value.str);
	    vpi_printf("%s\n", line);
	    if (n >= 5 || strcmp(line, expected[n]) != 0) failures += 1;
	    n += 1;
      }
      if (n != 5) failures += 1;
      if (failures == 0) vpi_printf("VPI CONTASSIGN SELECT PASS\nPASSED\n");
      else vpi_printf("FAILED: %u\n", failures);
      return 0;
}

static void reg(void)
{
      s_vpi_systf_data d;
      memset(&d, 0, sizeof d);
      d.type = vpiSysTask;
      d.tfname = (PLI_BYTE8*)"$probe";
      d.calltf = probe;
      vpi_register_systf(&d);
}

void (*vlog_startup_routines[])(void) = { reg, 0 };
