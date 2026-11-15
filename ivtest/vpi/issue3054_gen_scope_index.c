#include <vpi_user.h>
#include <string.h>

static int check(const char *name, int has_index, int expected)
{
    vpiHandle scope = vpi_handle_by_name((char *)name, 0);
    vpiHandle index = scope ? vpi_handle(vpiIndex, scope) : 0;
    s_vpi_value value;
    if (!scope || vpi_get(vpiType, scope) != vpiGenScope ||
        !!index != has_index) {
        vpi_printf("FAIL: scope/index for %s\n", name);
        return 1;
    }
    if (index) {
        value.format = vpiIntVal;
        vpi_get_value(index, &value);
        if (value.value.integer != expected || index != vpi_handle(vpiIndex, scope)) {
            vpi_printf("FAIL: index for %s is %d, expected %d\n",
                       name, value.value.integer, expected);
            return 1;
        }
    }
    return 0;
}

static PLI_INT32 check_calltf(PLI_BYTE8 *unused)
{
    int errors = 0;
    (void)unused;
    errors += check("top.g[-2]", 1, -2);
    errors += check("top.g[0]", 1, 0);
    errors += check("top.g[2]", 1, 2);
    errors += check("top.g[-2].inner[4]", 1, 4);
    errors += check("top.scalar", 0, 0);
    errors += check("top.bracket[7]", 0, 0);
    if (!errors) vpi_printf("PASSED\n");
    return 0;
}

static void register_check(void)
{
    s_vpi_systf_data task;
    memset(&task, 0, sizeof task);
    task.type = vpiSysTask;
    task.tfname = "$check_gen_index";
    task.calltf = check_calltf;
    vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = { register_check, 0 };
