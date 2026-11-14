/*
 * Issue #3268 (IEEE 1800-2023 37.25 detail 1): the vpiName of a typespec is
 * the name of its user-defined typedef, and NULL for a type without one,
 * for a variable's typespec and for a member's.
 */
#include <stdio.h>
#include <string.h>
#include "vpi_user.h"
#include "sv_vpi_user.h"

static unsigned failures;

static void expect_name(vpiHandle ts, const char*what, const char*want)
{
      const char*got = ts ? vpi_get_str(vpiName, ts) : 0;
      if (!ts || (want ? !got || strcmp(got, want) != 0 : got != 0)) {
	    vpi_printf("FAILED: %s typespec vpiName %s, want %s\n", what,
		       got ? got : "NULL", want ? want : "NULL");
	    failures += 1;
      }
}

static vpiHandle typespec_of(const char*name)
{
      vpiHandle v = vpi_handle_by_name((PLI_BYTE8*)name, 0);
      return v ? vpi_handle(vpiTypespec, v) : 0;
}

static PLI_INT32 probe_calltf(PLI_BYTE8*ud)
{
      vpiHandle ts, it, m;
      (void)ud;
      expect_name(typespec_of("top.s"), "s", "st_t");
      expect_name(typespec_of("top.e"), "e", "e_t");
      expect_name(typespec_of("top.o"), "o", "outer_t");
      expect_name(typespec_of("top.anon"), "anon", 0);
      ts = typespec_of("top.o");
      it = ts ? vpi_iterate(vpiTypespecMember, ts) : 0;
      while (it && (m = vpi_scan(it))) {
	    const char*name = vpi_get_str(vpiName, m);
	    if (strcmp(name, "kind") == 0)
		  expect_name(vpi_handle(vpiTypespec, m), "member kind", "e_t");
	    else if (strcmp(name, "v") == 0)
		  expect_name(vpi_handle(vpiTypespec, m), "member v", 0);
      }
      if (failures == 0)
	    vpi_printf("VPI TYPESPEC TYPEDEF NAME PASS\nPASSED\n");
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
