#include <string.h>
#include <vpi_user.h>

#ifndef vpiImport
#define vpiImport 726
#endif

static PLI_INT32 probe_import(PLI_BYTE8 *data)
{
    vpiHandle top = vpi_handle_by_name((PLI_BYTE8 *)"top", 0);
    vpiHandle iter = top ? vpi_iterate(vpiImport, top) : 0;
    vpiHandle item;
    s_vpi_value value;
    int count = 0;

    (void)data;
    while (iter && (item = vpi_scan(iter))) {
        const char *name = vpi_get_str(vpiName, item);
        if (!name || strcmp(name, "used") != 0) {
            vpi_printf("FAIL: unexpected imported object %s\n",
                       name ? name : "<unnamed>");
            vpi_control(vpiFinish, 1);
            return 0;
        }
        value.format = vpiIntVal;
        vpi_get_value(item, &value);
        if (value.value.integer != 17) {
            vpi_printf("FAIL: imported object value is %d\n",
                       value.value.integer);
            vpi_control(vpiFinish, 1);
            return 0;
        }
        ++count;
    }

    if (count != 1) {
        vpi_printf("FAIL: expected one referenced import, got %d\n", count);
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
    data.tfname = "$probe_import";
    data.calltf = probe_import;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
