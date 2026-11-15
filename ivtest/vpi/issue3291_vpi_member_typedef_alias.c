/*
 * Issue #3291 (IEEE 1800-2023 37.25 detail 1, 37.26): vpiName and
 * vpiTypedefAlias of the typespecs of struct and union members declared
 * through typedef aliases.
 */
#include <stdio.h>
#include <string.h>
#include "vpi_user.h"
#include "sv_vpi_user.h"

static unsigned failures;

/* The typespec of member MEMBER of the typespec of variable VAR. */
static vpiHandle member_typespec(const char*var, const char*member)
{
      vpiHandle ts = vpi_handle(vpiTypespec,
				vpi_handle_by_name((PLI_BYTE8*)var, 0));
      vpiHandle it = ts ? vpi_iterate(vpiTypespecMember, ts) : 0, m;
      while (it && (m = vpi_scan(it))) {
	    const char*n = vpi_get_str(vpiName, m);
	    if (n && strcmp(n, member) == 0) {
		  vpi_free_object(it);
		  return vpi_handle(vpiTypespec, m);
	    }
      }
      return 0;
}

static void expect_chain(const char*var, const char*member, const char*want)
{
      char got[128];
      vpiHandle ts = member_typespec(var, member);
      got[0] = 0;
      if (!ts) strcpy(got, "<no typespec>");
      while (ts) {
	    const char*n = vpi_get_str(vpiName, ts);
	    if (*got) strncat(got, ">", sizeof got - strlen(got) - 1);
	    strncat(got, n ? n : "NULL", sizeof got - strlen(got) - 1);
	    ts = vpi_handle(vpiTypedefAlias, ts);
      }
      if (strcmp(got, want) != 0) {
	    vpi_printf("FAILED: %s.%s typespec chain %s, want %s\n",
		       var, member, got, want);
	    failures += 1;
      }
}

static PLI_INT32 probe_calltf(PLI_BYTE8*ud)
{
      vpiHandle ts;
      (void)ud;
      expect_chain("top.px", "hue", "colors>primary_colors");
      expect_chain("top.px", "p", "primary_colors");
      expect_chain("top.px", "h", "hues>colors>primary_colors");
      expect_chain("top.px", "s", "st2_t>st_t");
      expect_chain("top.px", "x", "NULL");
      expect_chain("top.un", "c", "colors>primary_colors");
	/* The alias answers everything else as the aliased type. */
      ts = member_typespec("top.px", "hue");
      if (!ts || vpi_get(vpiType, ts) != vpiEnumTypespec) {
	    vpi_printf("FAILED: member hue is not an enum typespec\n");
	    failures += 1;
      }
      if (failures == 0)
	    vpi_printf("VPI MEMBER TYPEDEF ALIAS PASS\nPASSED\n");
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
