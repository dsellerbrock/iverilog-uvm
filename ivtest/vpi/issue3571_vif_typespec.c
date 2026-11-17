#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

static int check(const char *path, const char *defname, int modport)
{
    vpiHandle var = vpi_handle_by_name((PLI_BYTE8 *)path, 0);
    vpiHandle type = var ? vpi_handle(vpiTypespec, var) : 0;
    const char *name = type ? vpi_get_str(vpiDefName, type) : 0;
    vpiHandle parent = type ? vpi_handle(vpiParent, type) : 0;
    if (!var || vpi_get(vpiType, var) != vpiVirtualInterfaceVar ||
        !type || vpi_get(vpiType, type) != vpiInterfaceTypespec ||
        !name || strcmp(name, defname) ||
        vpi_get(vpiIsModPort, type) != modport) {
        vpi_printf("FAIL %s typespec\n", path);
        return 1;
    }
    if (modport) {
        name = parent ? vpi_get_str(vpiDefName, parent) : 0;
        if (!parent || vpi_get(vpiType, parent) != vpiInterfaceTypespec ||
            !name || strcmp(name, "bus") || vpi_get(vpiIsModPort, parent)) {
            vpi_printf("FAIL %s parent\n", path);
            return 1;
        }
    } else if (parent) {
        vpi_printf("FAIL %s unexpected parent\n", path);
        return 1;
    }
    return 0;
}

static PLI_INT32 probe(p_cb_data cb)
{
    int errors = 0;
    (void)cb;
    errors += check("top.assigned", "bus", 0);
    errors += check("top.empty", "bus", 0);
    errors += check("top.mp", "master", 1);
    errors += check("top.elements[1]", "bus", 0);
    if (!errors) vpi_printf("PASSED\n");
    return 0;
}

static void startup(void)
{
    s_cb_data cb = {0};
    cb.reason = cbStartOfSimulation;
    cb.cb_rtn = probe;
    vpi_register_cb(&cb);
}
void (*vlog_startup_routines[])(void) = {startup, 0};
