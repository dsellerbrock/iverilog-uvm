#include <string.h>
#include <vpi_user.h>

#ifndef vpiIsModPort
#define vpiIsModPort 669
#endif

static int failures;

static void check_vif(const char *name, int is_modport)
{
    vpiHandle vif = vpi_handle_by_name((PLI_BYTE8 *)name, 0);
    vpiHandle expr = vif ? vpi_handle(vpiExpr, vif) : 0;
    const char *expr_name = expr ? vpi_get_str(vpiFullName, expr) : 0;
    int actual_modport = vif ? vpi_get(vpiIsModPort, vif) : -1;

    if (!vif || !expr_name || strcmp(expr_name, "top.b") != 0) {
        vpi_printf("FAIL %s initializer expression=%s\n", name,
                   expr_name ? expr_name : "<null>");
        failures++;
    }
    if (actual_modport != is_modport) {
        vpi_printf("FAIL %s modport=%d expected=%d\n", name,
                   actual_modport, is_modport);
        failures++;
    }
}

static PLI_INT32 probe(p_cb_data data)
{
    (void)data;
    check_vif("top.vi", 0);
    check_vif("top.vmp", 1);
    if (failures) {
        vpi_printf("ISSUE1293_VIF_PROPERTIES_FAIL failures=%d\n", failures);
        vpi_control(vpiFinish, 1);
    } else {
        vpi_printf("ISSUE1293_VIF_PROPERTIES_PASS\nPASSED\n");
    }
    return 0;
}

static void register_probe(void)
{
    s_cb_data data;
    memset(&data, 0, sizeof data);
    data.reason = cbStartOfSimulation;
    data.cb_rtn = probe;
    vpi_register_cb(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
