#include <vpi_user.h>
#include <string.h>

static PLI_INT32 check_calltf(PLI_BYTE8 *data)
{
    (void)data;
    vpiHandle top = vpi_handle_by_name("issue1261_module_array_vpi_index", NULL);
    vpiHandle iter = vpi_iterate(vpiModule, top);
    vpiHandle module;
    int expected = 2;

    while (iter && (module = vpi_scan(iter))) {
        vpiHandle index = vpi_handle(vpiIndex, module);
        s_vpi_value value;
        const char *name = vpi_get_str(vpiFullName, module);

        if (name && !strcmp(name, "issue1261_module_array_vpi_index.plain")) {
            if (index || vpi_get(vpiIndex, module) != -1) {
                vpi_printf("FAIL: non-array module %s has an index\n", name);
                return 1;
            }
            continue;
        }

        if (!index || vpi_get(vpiIndex, module) != expected) {
            vpi_printf("FAIL: %s has module index %d and handle %p\n",
                       name, vpi_get(vpiIndex, module), (void *)index);
            return 1;
        }
        value.format = vpiIntVal;
        vpi_get_value(index, &value);
        if (value.value.integer != expected) {
            vpi_printf("FAIL: %s index handle contains %d\n",
                       name, value.value.integer);
            return 1;
        }
        expected++;
    }

    if (expected != 5) {
        vpi_printf("FAIL: found %d module-array elements\n", expected - 2);
        return 1;
    }
    vpi_printf("PASS: module-array VPI indices are 2, 3, and 4\n");
    vpi_printf("PASSED\n");
    return 0;
}

static void register_check(void)
{
    s_vpi_systf_data task;
    memset(&task, 0, sizeof task);
    task.type = vpiSysTask;
    task.tfname = "$check_module_array_indices";
    task.calltf = check_calltf;
    vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = { register_check, 0 };
