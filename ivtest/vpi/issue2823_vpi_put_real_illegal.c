/*
 * IEEE 1800-2023 38.34: vpi_put_value() of vpiStrengthVal or vpiStringVal
 * to a real variable or real array word is an error that leaves the value
 * unchanged; it must not abort. A legal vpiRealVal put still works.
 */
#include <string.h>
#include "vpi_user.h"

static int fails = 0;

static double get_real(vpiHandle h)
{
      s_vpi_value v;
      v.format = vpiRealVal;
      vpi_get_value(h, &v);
      return v.value.real;
}

static void bad_puts(vpiHandle h, double want, const char*what)
{
      s_vpi_strengthval sv;
      s_vpi_value val;
      s_vpi_error_info info;
      memset(&sv, 0, sizeof sv);
      val.format = vpiStrengthVal;
      val.value.strength = &sv;
      vpi_put_value(h, &val, 0, vpiNoDelay);
      if (vpi_chk_error(&info) != vpiError || get_real(h) != want) {
	    fails += 1; vpi_printf("FAIL strength %s\n", what);
      }
      val.format = vpiStringVal;
      val.value.str = (PLI_BYTE8*)"x";
      vpi_put_value(h, &val, 0, vpiNoDelay);
      if (vpi_chk_error(&info) != vpiError || get_real(h) != want) {
	    fails += 1; vpi_printf("FAIL string %s\n", what);
      }
}

static PLI_INT32 probe(PLI_BYTE8*ud)
{
      vpiHandle r = vpi_handle_by_name((PLI_BYTE8*)"top.r", 0);
      vpiHandle ra = vpi_handle_by_name((PLI_BYTE8*)"top.ra", 0);
      vpiHandle w = ra ? vpi_handle_by_index(ra, 1) : 0;
      s_vpi_value val;
      (void)ud;

      if (!r || !w) { vpi_printf("FAIL handles\n"); return 0; }
      bad_puts(r, 1.5, "real var");
      bad_puts(w, 3.5, "real array word");

      val.format = vpiRealVal;
      val.value.real = 4.25;
      vpi_put_value(w, &val, 0, vpiNoDelay);
      if (get_real(w) != 4.25) { fails += 1; vpi_printf("FAIL legal put\n"); }

      vpi_printf("R=%.1f\n", get_real(r));
      if (fails == 0) vpi_printf("VPI PUT REAL ILLEGAL PASS\nPASSED\n");
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
