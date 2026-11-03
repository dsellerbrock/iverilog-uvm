#include <stdio.h>
#include <string.h>
#include <vpi_user.h>

#ifdef vpiIODecl
#undef vpiIODecl
#endif
#define vpiIODecl 28
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

static int passed = 1;

static void fail(const char *message)
{
    vpi_printf("ISSUE1271_FAIL %s\n", message);
    passed = 0;
}

static int check_io_list(const char *scope_name,
                         const char *const *names,
                         const int *directions, int expected_count)
{
    vpiHandle scope = vpi_handle_by_name((PLI_BYTE8 *)scope_name, 0);
    vpiHandle iter, io;
    int count = 0;

    if (!scope) {
        fail("missing task/function scope");
        return 0;
    }
    iter = vpi_iterate(vpiIODecl, scope);
    while (iter && (io = vpi_scan(iter))) {
        const char *name = vpi_get_str(vpiName, io);
        int type = vpi_get(vpiType, io);
        if (type != vpiIODecl)
            fail("I/O declaration has a nonstandard vpiType");
        if (count >= expected_count) {
            fail("too many I/O declarations");
        } else {
            if (!name || strcmp(name, names[count]) != 0)
                fail("I/O declaration order/name mismatch");
            int direction = vpi_get(vpiDirection, io);
            if (direction != directions[count])
                fail("I/O declaration direction mismatch");
        }
        count += 1;
    }
    if (count != expected_count) fail("I/O declaration count mismatch");
    return count;
}

static PLI_INT32 probe(PLI_BYTE8 *user_data)
{
    static const char *const direction_names[] = {
        "in_arg", "out_arg", "io_arg"
    };
    static const int direction_values[] = { vpiInput, vpiOutput, vpiInout };
    static const char *const function_names[] = { "function_arg" };
    static const int function_directions[] = { vpiInput };
    vpiHandle task, iter, io, expr, actual, by_name;
    const char *full_name;
    (void)user_data;

    check_io_list("top.directions", direction_names, direction_values, 3);
    check_io_list("top.by_function", function_names, function_directions, 1);

    task = vpi_handle_by_name((PLI_BYTE8 *)"top.by_vif", 0);
    iter = task ? vpi_iterate(vpiIODecl, task) : 0;
    io = iter ? vpi_scan(iter) : 0;
    if (!io || (iter && vpi_scan(iter))) {
        fail("virtual-interface formal count mismatch");
    } else {
        expr = vpi_handle(vpiExpr, io);
        if (vpi_get(vpiDirection, io) != vpiUndefined)
            fail("virtual-interface direction is defined");
        if (!expr || vpi_get(vpiType, expr) != vpiVirtualInterfaceVar)
            fail("virtual-interface expression type mismatch");
    }

    task = vpi_handle_by_name((PLI_BYTE8 *)"top.by_ref", 0);
    iter = task ? vpi_iterate(vpiIODecl, task) : 0;
    io = iter ? vpi_scan(iter) : 0;
    if (!io || (iter && vpi_scan(iter))) {
        fail("ref formal count mismatch");
    } else {
        expr = vpi_handle(vpiExpr, io);
        if (vpi_get(vpiDirection, io) != vpiRef)
            fail("ref direction mismatch");
        if (!expr || vpi_get(vpiType, expr) != vpiRefObj)
            fail("ref expression is not vpiRefObj");
        actual = expr ? vpi_handle(vpiActual, expr) : 0;
        full_name = actual ? vpi_get_str(vpiFullName, actual) : 0;
        if (!full_name || strcmp(full_name, "top.actual") != 0)
            fail("active ref vpiActual mismatch");
        by_name = vpi_handle_by_name((PLI_BYTE8 *)"top.by_ref.x", 0);
        if (!by_name || vpi_get(vpiType, by_name) != vpiRefObj)
            fail("hierarchical ref lookup is not vpiRefObj");
        actual = by_name ? vpi_handle(vpiActual, by_name) : 0;
        full_name = actual ? vpi_get_str(vpiFullName, actual) : 0;
        if (!full_name || strcmp(full_name, "top.actual") != 0)
            fail("hierarchical ref vpiActual mismatch");
    }

    if (passed) vpi_printf("ISSUE1271_PASSED\nPASSED\n");
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data tf;
    memset(&tf, 0, sizeof tf);
    tf.type = vpiSysTask;
    tf.tfname = "$issue1271_probe";
    tf.calltf = probe;
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
