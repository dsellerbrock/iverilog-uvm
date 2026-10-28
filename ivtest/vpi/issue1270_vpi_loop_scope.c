#include <vpi_user.h>

static PLI_INT32 check_loop_scopes(p_cb_data cb)
{
    vpiHandle top = vpi_handle_by_name((PLI_BYTE8*)"top", 0);
    vpiHandle scopes = top ? vpi_iterate(vpiInternalScope, top) : 0;
    vpiHandle scope, vars, var;
    unsigned found_for = 0, found_foreach = 0, for_scopes = 0;
    (void)cb;

    while (scopes && (scope = vpi_scan(scopes))) {
        int scope_type = vpi_get(vpiType, scope);
        if (scope_type == vpiFor) {
            for_scopes++;
            if (vpi_get(vpiLocalVarDecls, scope) != 1)
                goto fail;
        }
        vars = vpi_iterate(vpiVariables, scope);
        while (vars && (var = vpi_scan(vars))) {
            vpiHandle target = vpi_handle(vpiScope, var);
            int target_type = target ? vpi_get(vpiType, target) : vpiUndefined;
            if (scope_type == vpiFor) {
                if (target_type != vpiFor)
                    goto fail;
                found_for++;
            } else if (scope_type == vpiForeachStmt) {
                if (target_type != vpiForeachStmt)
                    goto fail;
                found_foreach++;
            }
        }
    }
    if (found_for != 1 || found_foreach != 1 || for_scopes != 1)
        goto fail;
    vpi_printf("PASSED\n");
    return 0;
fail:
    vpi_printf("FAILED loop scopes: for=%u foreach=%u all_for=%u\n",
               found_for, found_foreach, for_scopes);
    vpi_control(vpiFinish, 1);
    return 0;
}

static void register_check(void)
{
    s_cb_data data = {0};
    data.reason = cbStartOfSimulation;
    data.cb_rtn = check_loop_scopes;
    vpi_register_cb(&data);
}

void (*vlog_startup_routines[])(void) = { register_check, 0 };
