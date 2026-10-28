#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <string.h>

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    vpiHandle top, iter, scope;
    int found = 0, scalar_found = 0;
    (void)data;
    top = vpi_handle_by_name((PLI_BYTE8*)"issue1262_interface_index", 0);
    iter = top ? vpi_iterate(vpiInterface, top) : 0;
    while (iter && (scope = vpi_scan(iter))) {
        const char *name = vpi_get_str(vpiName, scope);
        int index;
        if (name && strcmp(name, "scalar") == 0) {
            scalar_found = 1;
            if (vpi_handle(vpiIndex, scope) || vpi_get(vpiIndex, scope) != -1)
                goto fail;
            continue;
        }
        if (!name || strncmp(name, "arr[", 4) != 0)
            goto fail;
        index = name[4] - '0';
        if (index < 0 || index > 1 || name[5] != ']'
                || vpi_get(vpiIndex, scope) != index)
            goto fail;
        vpiHandle index_handle = vpi_handle(vpiIndex, scope);
        s_vpi_value value;
        if (!index_handle || vpi_get(vpiType, index_handle) != vpiConstant)
            goto fail;
        value.format = vpiIntVal;
        vpi_get_value(index_handle, &value);
        if (value.value.integer != index)
            goto fail;
        found++;
    }
    if (found == 2 && scalar_found)
        vpi_printf("PASSED\n");
    else
        goto fail;
    return 0;

fail:
    vpi_printf("FAILED interface index query\n");
    vpi_control(vpiFinish, 1);
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data task;
    memset(&task, 0, sizeof task);
    task.type = vpiSysTask;
    task.tfname = "$probe_interface_index";
    task.calltf = probe;
    vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
