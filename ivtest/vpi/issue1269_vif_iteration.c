#include <string.h>
#include <vpi_user.h>

#ifndef vpiVirtualInterfaceVar
#define vpiVirtualInterfaceVar 728
#endif
#ifndef vpiArrayVar
#define vpiArrayVar vpiRegArray
#endif

static int has_name(const char *const *names, unsigned count, const char *name)
{
    unsigned idx;
    for (idx = 0; idx < count; ++idx)
        if (strcmp(names[idx], name) == 0)
            return 1;
    return 0;
}

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    static const char *const expected_vifs[] = {
        "issue1269_vif_iteration.vi",
        "issue1269_vif_iteration.arr[0]",
        "issue1269_vif_iteration.arr[1]"
    };
    vpiHandle top, iter, item;
    unsigned vif_count = 0, variable_count = 0;
    int found_array = 0, found_vi = 0, found_vi_variable = 0;
    (void)data;

    top = vpi_handle_by_name((PLI_BYTE8*)"issue1269_vif_iteration", 0);
    iter = top ? vpi_iterate(vpiVirtualInterfaceVar, top) : 0;
    while (iter && (item = vpi_scan(iter))) {
        const char *name = vpi_get_str(vpiFullName, item);
        if (!name || !has_name(expected_vifs, 3, name)
            || vpi_get(vpiType, item) != vpiVirtualInterfaceVar) {
            vpi_printf("FAIL unexpected VIF handle %s type=%d\n",
                       name ? name : "?", vpi_get(vpiType, item));
            vpi_control(vpiFinish, 1);
            return 0;
        }
        ++vif_count;
        if (strcmp(name, "issue1269_vif_iteration.vi") == 0)
            found_vi = 1;
    }
    if (vif_count != 3 || !found_vi) {
        vpi_printf("FAIL VIF count=%u\n", vif_count);
        vpi_control(vpiFinish, 1);
        return 0;
    }

    iter = top ? vpi_iterate(vpiVariables, top) : 0;
    while (iter && (item = vpi_scan(iter))) {
        const char *name = vpi_get_str(vpiFullName, item);
        int type = vpi_get(vpiType, item);
        if (name && strcmp(name, "issue1269_vif_iteration.arr") == 0) {
            if (type != vpiArrayVar) {
                vpi_printf("FAIL array type=%d\n", type);
                vpi_control(vpiFinish, 1);
                return 0;
            }
            found_array = 1;
        }
        if (name && strcmp(name, "issue1269_vif_iteration.vi") == 0) {
            if (type != vpiVirtualInterfaceVar) {
                vpi_printf("FAIL scalar VIF variable type=%d\n", type);
                vpi_control(vpiFinish, 1);
                return 0;
            }
            found_vi_variable = 1;
        }
        ++variable_count;
    }
    if (!found_array || !found_vi_variable || variable_count != 2) {
        vpi_printf("FAIL variable count=%u array=%d scalar=%d\n",
                   variable_count, found_array, found_vi_variable);
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
    data.tfname = "$probe_vif_iteration";
    data.calltf = probe;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
