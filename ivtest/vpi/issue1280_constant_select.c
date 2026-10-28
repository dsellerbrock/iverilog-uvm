#include <string.h>
#include <vpi_user.h>

static PLI_INT32 probe(PLI_BYTE8 *ud)
{
      vpiHandle scalar = vpi_handle_by_name((PLI_BYTE8*)"top.scalar", 0);
      vpiHandle array = vpi_handle_by_name((PLI_BYTE8*)"top.a", 0);
      vpiHandle select = vpi_handle_by_name((PLI_BYTE8*)"top.a[2]", 0);
      vpiHandle parent = select ? vpi_handle(vpiParent, select) : 0;
      (void)ud;

      if (scalar && array && select && parent == array &&
	  vpi_get(vpiConstantSelect, scalar) == 1 &&
	  vpi_get(vpiConstantSelect, array) == 1 &&
	  vpi_get(vpiConstantSelect, select) == 1) {
	    vpi_printf("PASSED\n");
	    return 0;
      }

      vpi_printf("FAIL: scalar=%d array=%d select=%d parent_matches=%d\n",
	 scalar ? vpi_get(vpiConstantSelect, scalar) : -1,
	 array ? vpi_get(vpiConstantSelect, array) : -1,
	 select ? vpi_get(vpiConstantSelect, select) : -1,
	 parent == array);
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$probe_constant_select";
      tf.calltf = probe;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {register_probe, 0};
