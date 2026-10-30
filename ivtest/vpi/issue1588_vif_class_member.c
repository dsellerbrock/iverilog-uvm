#include <string.h>
#include <vpi_user.h>

#ifndef vpiVirtualInterfaceVar
#define vpiVirtualInterfaceVar 728
#endif

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    vpiHandle handle;
    int type;
    (void)data;

    handle = vpi_handle_by_name((PLI_BYTE8*)"top.obj.vif", 0);
    type = handle ? vpi_get(vpiType, handle) : -1;
    if (handle && type == vpiVirtualInterfaceVar) {
        vpi_printf("PASSED\nvpiVirtualInterfaceVar\n");
        return 0;
    }

    vpi_printf("FAIL handle=%d type=%d\n", handle != 0, type);
    vpi_control(vpiFinish, 1);
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$probe_vif_class_member";
    data.calltf = probe;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
