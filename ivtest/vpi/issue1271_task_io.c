#include <string.h>
#include <stdio.h>
#include <vpi_user.h>

#ifndef vpiIODecl
#define vpiIODecl 28
#endif
#ifndef vpiRefObj
#define vpiRefObj 608
#endif
#ifndef vpiActual
#define vpiActual 700
#endif
#ifndef vpiVirtualInterfaceVar
#define vpiVirtualInterfaceVar 728
#endif
#ifndef vpiRef
#define vpiRef 6
#endif

static int fail(const char *message)
{
    vpi_printf("FAIL %s\n", message);
    vpi_control(vpiFinish, 1);
    return 0;
}

static int check_formals(const char *scope_name, const char *const *names,
                         const int *directions, unsigned expected_count,
                         int expected_expr_type)
{
    vpiHandle scope, iter, item, expr;
    unsigned count = 0;

    scope = vpi_handle_by_name((PLI_BYTE8 *)scope_name, 0);
    if (!scope)
        return fail("task lookup");
    iter = vpi_iterate(vpiIODecl, scope);
    if (!iter)
        return fail("empty task I/O iterator");

    while ((item = vpi_scan(iter)) != 0) {
        const char *name = vpi_get_str(vpiName, item);
        const char *full_name;
        char expected_full_name[256];
        if (count >= expected_count || !name || strcmp(name, names[count]) != 0)
            return fail("formal order/name");
        snprintf(expected_full_name, sizeof expected_full_name, "%s.%s",
                 scope_name, names[count]);
        full_name = vpi_get_str(vpiFullName, item);
        if (!full_name || strcmp(full_name, expected_full_name) != 0)
            return fail("formal full name");
        if (vpi_get(vpiType, item) != vpiIODecl)
            return fail("I/O declaration type");
        if (vpi_get(vpiDirection, item) != directions[count])
            return fail("formal direction");
        expr = vpi_handle(vpiExpr, item);
        if (!expr)
            return fail("missing formal expression");
        if (expected_expr_type != -1
            && vpi_get(vpiType, expr) != expected_expr_type)
            return fail("formal expression type");
        ++count;
    }
    if (count != expected_count)
        return fail("formal count");
    return 1;
}

static PLI_INT32 check_declarations(PLI_BYTE8 *userdata)
{
    static const char *const names[] = { "a", "b", "c" };
    static const int directions[] = { vpiInput, vpiOutput, vpiInout };
    static const char *const function_names[] = { "arg" };
    static const int function_directions[] = { vpiInput };
    static const char *const ref_names[] = { "x" };
    static const int ref_directions[] = { vpiRef };
    static const char *const vif_names[] = { "vi" };
    static const int vif_directions[] = { vpiUndefined };
    vpiHandle scope, iter, item, expr;
    (void)userdata;

    if (!check_formals("issue1271_task_io.by_value", names, directions,
                       3, -1))
        return 0;
    if (!check_formals("issue1271_task_io.by_function", function_names,
                       function_directions, 1, -1))
        return 0;
    if (!check_formals("issue1271_task_io.by_ref", ref_names,
                       ref_directions, 1, vpiRefObj))
        return 0;
    if (!check_formals("issue1271_task_io.by_vif", vif_names,
                       vif_directions, 1, vpiVirtualInterfaceVar))
        return 0;

    scope = vpi_handle_by_name((PLI_BYTE8 *)"issue1271_task_io.by_ref", 0);
    iter = scope ? vpi_iterate(vpiIODecl, scope) : 0;
    item = iter ? vpi_scan(iter) : 0;
    expr = item ? vpi_handle(vpiExpr, item) : 0;
    if (!expr || vpi_handle(vpiActual, expr) != 0)
        return fail("inactive ref actual");

    vpi_printf("ISSUE1271 DECLS PASS\n");
    return 0;
}

static PLI_INT32 check_active_ref(PLI_BYTE8 *userdata)
{
    vpiHandle refobj, actual;
    s_vpi_value value;
    (void)userdata;

    refobj = vpi_handle_by_name((PLI_BYTE8 *)"issue1271_task_io.by_ref.x", 0);
    if (!refobj)
        return fail("active formal lookup missing");
    if (vpi_get(vpiType, refobj) != vpiRefObj) {
        vpi_printf("ACTIVE REF TYPE=%d\n", vpi_get(vpiType, refobj));
        return fail("active formal is not vpiRefObj");
    }
    actual = vpi_handle(vpiActual, refobj);
    if (!actual || strcmp(vpi_get_str(vpiFullName, actual),
                           "issue1271_task_io.actual") != 0)
        return fail("active ref actual binding");
    value.format = vpiIntVal;
    vpi_get_value(actual, &value);
    if (value.value.integer != 5)
        return fail("active ref actual value");

    vpi_printf("ISSUE1271 ACTIVE REF PASS\n");
    return 0;
}

static void register_tasks(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$probe_task_decls";
    data.calltf = check_declarations;
    vpi_register_systf(&data);

    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$probe_task_ref";
    data.calltf = check_active_ref;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
