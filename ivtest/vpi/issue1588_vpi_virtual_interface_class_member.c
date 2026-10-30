#include <sv_vpi_user.h>

static PLI_INT32 probe_calltf(PLI_BYTE8 *user_data)
{
      vpiHandle handle = vpi_handle_by_name("top.obj.vif", NULL);
      int type = handle ? vpi_get(vpiType, handle) : vpiUndefined;
      (void)user_data;
      if (handle && type == vpiVirtualInterfaceVar)
            vpi_printf("PASSED\n");
      else
            vpi_printf("FAILED handle=%d type=%d\n", handle != NULL, type);
      return 0;
}

static void startup(void)
{
      s_vpi_systf_data task = {0};
      task.type = vpiSysTask;
      task.tfname = "$probe_virtual_interface_member";
      task.calltf = probe_calltf;
      vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = { startup, 0 };
