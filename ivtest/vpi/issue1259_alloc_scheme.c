#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <string.h>

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    vpiHandle handle;
    int got;
    (void)data;

    handle = vpi_handle_by_name((PLI_BYTE8*)"issue1259_alloc_scheme.x", 0);
    if (!handle) {
        vpi_printf("FAIL missing static variable handle\n");
        vpi_control(vpiFinish, 1);
        return 0;
    }

    got = vpi_get(vpiAllocScheme, handle);
    if (got != vpiOtherScheme) {
        vpi_printf("FAIL vpiAllocScheme got=%d want=%d\n",
                   got, vpiOtherScheme);
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
    data.tfname = "$probe_alloc_scheme";
    data.calltf = probe;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
