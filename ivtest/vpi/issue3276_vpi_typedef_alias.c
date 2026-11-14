/*
 * Issue #3276 (IEEE 1800-2023 37.25 detail 1): vpiName and vpiTypedefAlias
 * of the typespecs of variables declared through typedef aliases, following
 * the clause's own example (colors aliases primary_colors).
 */
#include <stdio.h>
#include <string.h>
#include "vpi_user.h"
#include "sv_vpi_user.h"

static unsigned failures;

/* "name>alias>..." along the vpiTypedefAlias chain of NAME's typespec. */
static void chain_of(const char*name, char*buf, size_t len)
{
      vpiHandle ts = vpi_handle(vpiTypespec,
				vpi_handle_by_name((PLI_BYTE8*)name, 0));
      buf[0] = 0;
      while (ts) {
	    const char*n = vpi_get_str(vpiName, ts);
	    if (*buf) strncat(buf, ">", len - strlen(buf) - 1);
	    strncat(buf, n ? n : "NULL", len - strlen(buf) - 1);
	    ts = vpi_handle(vpiTypedefAlias, ts);
      }
}

static void expect_chain(const char*name, const char*want)
{
      char got[128];
      chain_of(name, got, sizeof got);
      if (strcmp(got, want) != 0) {
	    vpi_printf("FAILED: %s typespec chain %s, want %s\n", name, got, want);
	    failures += 1;
      }
}

static PLI_INT32 probe_calltf(PLI_BYTE8*ud)
{
      vpiHandle ts, it;
      int n = 0;
      (void)ud;
      expect_chain("top.c", "colors>primary_colors");
      expect_chain("top.p", "primary_colors");
      expect_chain("top.h", "hues>colors>primary_colors");
      expect_chain("top.s2", "st2_t>st_t");
	/* The alias answers everything else as the aliased type. */
      ts = vpi_handle(vpiTypespec, vpi_handle_by_name((PLI_BYTE8*)"top.c", 0));
      if (!ts || vpi_get(vpiType, ts) != vpiEnumTypespec) {
	    vpi_printf("FAILED: colors is not an enum typespec\n");
	    failures += 1;
      }
      it = ts ? vpi_iterate(vpiEnumConst, ts) : 0;
      while (it && vpi_scan(it)) n += 1;
      if (n != 3) {
	    vpi_printf("FAILED: colors has %d enum constants\n", n);
	    failures += 1;
      }
      if (failures == 0)
	    vpi_printf("VPI TYPEDEF ALIAS PASS\nPASSED\n");
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
