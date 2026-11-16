/*
 * IEEE 1800-2023 38.38: vpi_free_object(NULL) and vpi_release_handle(NULL)
 * return 0 and report an error through vpi_chk_error(); valid handles
 * still free normally.
 */
#include <string.h>
#include "vpi_user.h"

static PLI_INT32 probe(PLI_BYTE8*ud)
{
      s_vpi_error_info info;
      int fails = 0;
      vpiHandle it;
      (void)ud;

      if (vpi_free_object(0) != 0) fails += 1;
      if (vpi_chk_error(&info) != vpiError) fails += 1;
      if (vpi_release_handle(0) != 0) fails += 1;
      if (vpi_chk_error(&info) != vpiError) fails += 1;

      it = vpi_iterate(vpiNet, vpi_handle_by_name((PLI_BYTE8*)"top", 0));
      if (!it) it = vpi_iterate(vpiReg, vpi_handle_by_name((PLI_BYTE8*)"top", 0));
      if (it && vpi_free_object(it) != 1) fails += 1;

      vpi_printf("FREE=%d RELEASE=%d\n", (int)vpi_free_object(0),
		 (int)vpi_release_handle(0));
      if (fails == 0) vpi_printf("VPI FREE NULL PASS\nPASSED\n");
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
