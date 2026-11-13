/*
 * Issue #3180 (IEEE 1800-2023 37.14 detail 5, 37.15): the vpiHighConn and
 * vpiLowConn of an interface or modport port are vpiRefObj handles. Their
 * vpiActual is the interface instance, or the modport the port selects.
 */
#include <stdio.h>
#include <string.h>
#include "vpi_user.h"

#define IEEE_vpiRefObj 608
#define IEEE_vpiActual 700
#define IEEE_vpiInterface 601
#define IEEE_vpiModport 603

static unsigned failures;

static void check_ref(vpiHandle ref, const char*what, const char*full,
		      int actual_type, const char*actual_full)
{
      vpiHandle actual;
      char got[128];
      if (!ref || vpi_get(vpiType, ref) != IEEE_vpiRefObj) {
	    vpi_printf("FAILED: %s is not a vpiRefObj\n", what);
	    failures += 1;
	    return;
      }
      snprintf(got, sizeof got, "%s", vpi_get_str(vpiFullName, ref));
      if (strcmp(got, full) != 0) {
	    vpi_printf("FAILED: %s vpiFullName %s, want %s\n", what, got, full);
	    failures += 1;
      }
      actual = vpi_handle(IEEE_vpiActual, ref);
      if (!actual || vpi_get(vpiType, actual) != actual_type
	  || strcmp(vpi_get_str(vpiFullName, actual), actual_full) != 0) {
	    vpi_printf("FAILED: %s vpiActual is not %s\n", what, actual_full);
	    failures += 1;
      }
}

static vpiHandle port_of(const char*inst, int index)
{
      vpiHandle it = vpi_iterate(vpiPort,
				 vpi_handle_by_name((PLI_BYTE8*)inst, 0)), p;
      while (it && (p = vpi_scan(it)))
	    if (vpi_get(vpiPortIndex, p) == index) {
		  vpi_free_object(it);
		  return p;
	    }
      return 0;
}

static PLI_INT32 probe_calltf(PLI_BYTE8*ud)
{
      vpiHandle b = port_of("top.l", 0), bm = port_of("top.l", 1);
      vpiHandle d = port_of("top.l", 2), q = port_of("top.l.n", 0);
      (void)ud;

      check_ref(vpi_handle(vpiHighConn, b), "l.b high", "top.i",
		IEEE_vpiInterface, "top.i");
      check_ref(vpi_handle(vpiLowConn, b), "l.b low", "top.l.b",
		IEEE_vpiInterface, "top.i");
      check_ref(vpi_handle(vpiHighConn, bm), "l.bm high", "top.i",
		IEEE_vpiModport, "top.i.m");
      check_ref(vpi_handle(vpiLowConn, bm), "l.bm low", "top.l.bm",
		IEEE_vpiModport, "top.i.m");
	/* A forwarded interface port: the actual is leaf's own port b. */
      check_ref(vpi_handle(vpiHighConn, q), "n.q high", "top.l.b",
		IEEE_vpiModport, "top.i.m");
      check_ref(vpi_handle(vpiLowConn, q), "n.q low", "top.l.n.q",
		IEEE_vpiModport, "top.i.m");
	/* An ordinary port keeps its net connections. */
      if (!d || vpi_get(vpiType, vpi_handle(vpiHighConn, d)) != vpiNet
	  || vpi_get(vpiType, vpi_handle(vpiLowConn, d)) != vpiNet) {
	    vpi_printf("FAILED: l.d connections\n");
	    failures += 1;
      }

      if (failures == 0)
	    vpi_printf("VPI INTERFACE PORTS PASS\nPASSED\n");
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
