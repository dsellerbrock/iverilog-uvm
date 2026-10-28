#include <string.h>
#include <vpi_user.h>

static int check_access(const char *path, int expected_a, int expected_b)
{
    vpiHandle handle = vpi_handle_by_name((PLI_BYTE8 *)path, 0);
    int got = handle ? vpi_get(vpiAccessType, handle) : vpiUndefined;
    if (got != expected_a && got != expected_b) {
        vpi_printf("FAIL %s access=%d\n", path, got);
        return 0;
    }
    return 1;
}

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    (void)data;
    if (!check_access("top.bus.run", vpiForkJoinAcc, vpiExternAcc)
        || !check_access("top.bus.get", vpiForkJoinAcc, vpiExternAcc)
        || !check_access("top.dpi_import_fn", vpiDPIImportAcc,
                         vpiDPIImportAcc)
        || !check_access("top.dpi_import_task", vpiDPIImportAcc,
                         vpiDPIImportAcc)
        || !check_access("top.dpi_export_fn", vpiDPIExportAcc,
                         vpiDPIExportAcc)
        || !check_access("top.dpi_export_task", vpiDPIExportAcc,
                         vpiDPIExportAcc)) {
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
    data.tfname = "$probe_access_type";
    data.calltf = probe;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
