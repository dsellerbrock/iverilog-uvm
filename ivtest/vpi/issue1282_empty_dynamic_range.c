#include <string.h>
#include <vpi_user.h>

static PLI_INT32 probe_empty_dynamic_range(PLI_BYTE8 *data)
{
    vpiHandle empty, nonempty;
    (void)data;

    empty = vpi_handle_by_name((PLI_BYTE8*)"top.empty_dyn", 0);
    nonempty = vpi_handle_by_name((PLI_BYTE8*)"top.nonempty_dyn", 0);
    if (!empty || !nonempty) {
        vpi_printf("FAIL array lookup\n");
        vpi_control(vpiFinish, 1);
        return 0;
    }
    if (vpi_get(vpiSize, empty) != 0 ||
        vpi_handle(vpiLeftRange, empty) ||
        vpi_handle(vpiRightRange, empty)) {
        vpi_printf("FAIL empty dynamic range\n");
        vpi_control(vpiFinish, 1);
        return 0;
    }
    if (!vpi_handle(vpiLeftRange, nonempty) ||
        !vpi_handle(vpiRightRange, nonempty) ||
        vpi_get(vpiLeftRange, nonempty) != 0 ||
        vpi_get(vpiRightRange, nonempty) != 2) {
        vpi_printf("FAIL nonempty range\n");
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
    data.tfname = "$probe_empty_dynamic_range";
    data.calltf = probe_empty_dynamic_range;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
