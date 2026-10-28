#include <string.h>
#include <sv_vpi_user.h>

#ifndef vpiVirtualInterfaceVar
#define vpiVirtualInterfaceVar 728
#endif

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    vpiHandle top, iter, item;
    int scalar = 0, elem0 = 0, elem1 = 0, vif_count = 0;
    int scalar_var = 0, array_decl = 0, variables = 0;
    (void)data;

    top = vpi_handle_by_name((PLI_BYTE8*)"issue1269_vpi_virtual_interface_iter", 0);
    iter = top ? vpi_iterate(vpiVirtualInterfaceVar, top) : 0;
    while (iter && (item = vpi_scan(iter))) {
        const char *name = vpi_get_str(vpiFullName, item);
        if (!name || vpi_get(vpiType, item) != vpiVirtualInterfaceVar) {
            vpi_printf("FAIL invalid virtual-interface handle %s type=%d\n",
                       name ? name : "?", vpi_get(vpiType, item));
            vpi_control(vpiFinish, 1);
            return 0;
        }
        if (strcmp(name, "issue1269_vpi_virtual_interface_iter.vi") == 0)
            scalar++;
        else if (strcmp(name, "issue1269_vpi_virtual_interface_iter.arr[0]") == 0)
            elem0++;
        else if (strcmp(name, "issue1269_vpi_virtual_interface_iter.arr[1]") == 0)
            elem1++;
        else {
            vpi_printf("FAIL unexpected virtual-interface variable %s\n", name);
            vpi_control(vpiFinish, 1);
            return 0;
        }
        vif_count++;
    }

    iter = top ? vpi_iterate(vpiVariables, top) : 0;
    while (iter && (item = vpi_scan(iter))) {
        const char *name = vpi_get_str(vpiFullName, item);
        variables++;
        if (name && strcmp(name, "issue1269_vpi_virtual_interface_iter.vi") == 0) {
            if (vpi_get(vpiType, item) != vpiVirtualInterfaceVar) {
                vpi_printf("FAIL scalar variable type %d\n", vpi_get(vpiType, item));
                vpi_control(vpiFinish, 1);
                return 0;
            }
            scalar_var++;
        } else if (name && strcmp(name, "issue1269_vpi_virtual_interface_iter.arr") == 0) {
            if (vpi_get(vpiType, item) != vpiArrayVar) {
                vpi_printf("FAIL array declaration type %d\n", vpi_get(vpiType, item));
                vpi_control(vpiFinish, 1);
                return 0;
            }
            array_decl++;
        }
    }

    if (scalar != 1 || elem0 != 1 || elem1 != 1 || vif_count != 3
        || scalar_var != 1 || array_decl != 1) {
        vpi_printf("FAIL vif=%d scalar=%d elem0=%d elem1=%d scalar-var=%d array=%d vars=%d\n",
                   vif_count, scalar, elem0, elem1, scalar_var, array_decl, variables);
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
    data.tfname = "$probe_vif_iter";
    data.calltf = probe;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
