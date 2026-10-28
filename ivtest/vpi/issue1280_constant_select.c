#include <stdio.h>
#include <string.h>
#include <vpi_user.h>

static PLI_INT32 probe(PLI_BYTE8 *ud)
{
      vpiHandle base = vpi_handle_by_name((PLI_BYTE8*)"top.a", 0);
      vpiHandle sel = vpi_handle_by_name((PLI_BYTE8*)"top.a[2]", 0);
      vpiHandle scalar = vpi_handle_by_name((PLI_BYTE8*)"top.s", 0);
      vpiHandle parent = base ? vpi_handle(vpiParent, base) : 0;
      vpiHandle sel_parent = sel ? vpi_handle(vpiParent, sel) : 0;
      (void)ud;

      if (!base || !sel || !scalar || parent || sel_parent != base) {
            vpi_printf("FAILED: static variable handles\n");
            return 0;
      }

      if (!vpi_get(vpiConstantSelect, base) ||
          !vpi_get(vpiConstantSelect, sel) ||
          sel_parent != base ||
          !vpi_get(vpiConstantSelect, scalar)) {
            vpi_printf("FAILED: base=%d sel=%d sel_parent=%d scalar=%d\n",
                       vpi_get(vpiConstantSelect, base),
                       vpi_get(vpiConstantSelect, sel),
                       sel_parent == base,
                       vpi_get(vpiConstantSelect, scalar));
            return 0;
      }
      vpi_printf("PASSED\n");
      return 0;
}

static void reg(void)
{
      s_vpi_systf_data data;
      memset(&data, 0, sizeof data);
      data.type = vpiSysTask;
      data.tfname = "$probe1280";
      data.calltf = probe;
      vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = {reg, 0};
