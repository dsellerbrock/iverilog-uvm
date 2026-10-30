#include <string.h>
#include <vpi_user.h>

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    static const PLI_INT32 id = 1583;
    static const PLI_BYTE8 expected[] = { 0x12, 0x34, 0x56, 0x78 };
    PLI_BYTE8 actual[sizeof expected] = { 0 };

    (void)data;
    if (vpi_put_data(id, (PLI_BYTE8 *)expected, 2) != 2 ||
        vpi_put_data(id, (PLI_BYTE8 *)expected + 2, 2) != 2 ||
        vpi_get_data(id, actual, 2) != 2 ||
        vpi_get_data(id, actual + 2, 2) != 2 ||
        memcmp(actual, expected, sizeof expected) != 0 ||
        vpi_get_data(id, actual, 1) != 0 ||
        vpi_get_data(1584, actual, sizeof actual) != 0) {
        vpi_printf("vpi_get_data FAILED\n");
        vpi_control(vpiFinish, 1);
        return 0;
    }

    vpi_printf("vpi_get_data PASSED\nPASSED\n");
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data task;
    memset(&task, 0, sizeof task);
    task.type = vpiSysTask;
    task.tfname = "$probe_vpi_get_data";
    task.calltf = probe;
    vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
