#include <string.h>
#include <vpi_user.h>

#ifndef vpiParamAssign
#define vpiParamAssign 40
#endif
#ifndef vpiLhs
#define vpiLhs 77
#endif
#ifndef vpiRhs
#define vpiRhs 82
#endif
#ifndef vpiConnByName
#define vpiConnByName 21
#endif

static int check_assign(const char *scope_name, int by_name,
                        int rhs_size, int rhs_value, int lhs_value)
{
    vpiHandle scope = vpi_handle_by_name((PLI_BYTE8 *)scope_name, 0);
    vpiHandle iter = scope ? vpi_iterate(vpiParamAssign, scope) : 0;
    vpiHandle assign;
    int count = 0;

    while (iter && (assign = vpi_scan(iter))) {
        vpiHandle lhs = vpi_handle(vpiLhs, assign);
        vpiHandle rhs = vpi_handle(vpiRhs, assign);
        s_vpi_value value;
        const char *lhs_name = lhs ? vpi_get_str(vpiName, lhs) : 0;

        count += 1;
        if (count != 1 || vpi_get(vpiType, assign) != vpiParamAssign ||
            vpi_get(vpiConnByName, assign) != by_name ||
            !lhs || vpi_get(vpiType, lhs) != vpiParameter ||
            !lhs_name || strcmp(lhs_name, "P") != 0 || !rhs ||
            vpi_get(vpiType, rhs) != vpiConstant ||
            vpi_get(vpiSize, rhs) != rhs_size) {
            vpi_printf("FAIL %s assignment relationships\n", scope_name);
            return 0;
        }

        value.format = vpiIntVal;
        vpi_get_value(rhs, &value);
        if (value.value.integer != rhs_value) {
            vpi_printf("FAIL %s RHS value %d, expected %d\n",
                       scope_name, value.value.integer, rhs_value);
            return 0;
        }

        vpi_get_value(lhs, &value);
        if (value.value.integer != lhs_value) {
            vpi_printf("FAIL %s LHS value %d, expected %d\n",
                       scope_name, value.value.integer, lhs_value);
            return 0;
        }
    }

    if (count != 1) {
        vpi_printf("FAIL %s found %d parameter assignments\n",
                   scope_name, count);
        return 0;
    }
    return 1;
}

static int check_no_assign(const char *scope_name)
{
    vpiHandle scope = vpi_handle_by_name((PLI_BYTE8 *)scope_name, 0);
    vpiHandle iter = scope ? vpi_iterate(vpiParamAssign, scope) : 0;
    if (iter && vpi_scan(iter)) {
        vpi_printf("FAIL %s unexpectedly has a parameter assignment\n",
                   scope_name);
        return 0;
    }
    return 1;
}

static PLI_INT32 probe(p_cb_data cb)
{
    (void)cb;
    if (!check_no_assign("top") ||
        !check_assign("top.u", 1, 32, 8, 8) ||
        !check_assign("top.v", 0, 32, 8, 8) ||
        !check_assign("top.n", 1, 8, 47, 15)) {
        vpi_control(vpiFinish, 1);
        return 0;
    }

    vpi_printf("PASSED\n");
    return 0;
}

static void startup(void)
{
    s_cb_data cb;
    memset(&cb, 0, sizeof cb);
    cb.reason = cbStartOfSimulation;
    cb.cb_rtn = probe;
    vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = { startup, 0 };
