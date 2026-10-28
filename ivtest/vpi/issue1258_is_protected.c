#include <vpi_user.h>
#include <string.h>

#ifndef vpiIsProtected
#define vpiIsProtected 74
#endif

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    vpiHandle handle, top;
    int value;
    (void)data;

    handle = vpi_handle_by_name((PLI_BYTE8*)"issue1258_vpi_is_protected.x", 0);
    top = vpi_handle_by_name((PLI_BYTE8*)"issue1258_vpi_is_protected", 0);
    value = handle ? vpi_get(vpiIsProtected, handle) : -1;
    if (value != 0) {
        vpi_printf("FAIL variable vpiIsProtected=%d\n", value);
        vpi_control(vpiFinish, 1);
        return 0;
    }

    value = top ? vpi_get(vpiIsProtected, top) : -1;
    if (value != 0) {
        vpi_printf("FAIL module vpiIsProtected=%d\n", value);
        vpi_control(vpiFinish, 1);
        return 0;
    }

    vpi_printf("PASSED\n");
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$probe_is_protected";
    data.calltf = probe;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
