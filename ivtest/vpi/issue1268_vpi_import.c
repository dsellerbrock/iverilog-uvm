#include <string.h>
#include <vpi_user.h>

#ifndef vpiImport
#define vpiImport 726
#endif

static PLI_INT32 probe(PLI_BYTE8 *ud)
{
    vpiHandle top = vpi_handle_by_name((PLI_BYTE8*)"top", 0);
    vpiHandle iter, item;
    int count = 0;
    int failed = 0;

    (void)ud;
    iter = top ? vpi_iterate(vpiImport, top) : 0;
    while (iter && (item = vpi_scan(iter))) {
        s_vpi_value value = {0};
        char *name = vpi_get_str(vpiName, item);

        count += 1;
        value.format = vpiIntVal;
        vpi_get_value(item, &value);
        if (!name || strcmp(name, "used") != 0 || value.value.integer != 17)
            failed = 1;
        vpi_printf("IMPORT %s VALUE=%d\n", name ? name : "<null>",
                   value.value.integer);
    }

    vpi_printf("IMPORT_COUNT=%d\n", count);
    if (failed || count != 1) {
        vpi_printf("FAILED: expected only imported object used\n");
        return 0;
    }

    vpi_printf("PASSED\n");
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data task = {0};
    task.type = vpiSysTask;
    task.tfname = "$probe";
    task.calltf = probe;
    vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = {register_probe, 0};
