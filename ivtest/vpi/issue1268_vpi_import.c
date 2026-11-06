#include <sv_vpi_user.h>
#include <string.h>

static PLI_INT32 probe_import(PLI_BYTE8 *data)
{
    vpiHandle top, iter, imported, expected;
    int count = 0;
    int used_found = 0;
    s_vpi_value value;
    (void)data;

    top = vpi_handle_by_name((PLI_BYTE8*)"top", 0);
    iter = top ? vpi_iterate(vpiImport, top) : 0;
    expected = vpi_handle_by_name((PLI_BYTE8*)"pkg::used", 0);
    while (iter && (imported = vpi_scan(iter))) {
        const char *name = vpi_get_str(vpiName, imported);
        count++;
        if (name && strcmp(name, "used") == 0
            && expected && vpi_compare_objects(imported, expected)) {
            value.format = vpiIntVal;
            vpi_get_value(imported, &value);
            used_found = value.value.integer == 17;
        }
    }

    if (count != 1 || !used_found) {
        vpi_printf("ISSUE1268 FAIL count=%d used=%d\n", count, used_found);
        vpi_control(vpiFinish, 1);
        return 0;
    }

    vpi_printf("ISSUE1268 IMPORT used=17 COUNT=1\n");
    vpi_printf("PASSED\n");
    return 0;
}

static void register_import_probe(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$probe_import";
    data.calltf = probe_import;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_import_probe, 0 };
