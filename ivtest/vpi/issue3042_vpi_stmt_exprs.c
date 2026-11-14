#include <string.h>
#include <vpi_user.h>

static int failures, force_callbacks;

static void fail(const char *what)
{
    vpi_printf("FAIL %s\n", what);
    failures++;
}

static int int_value(vpiHandle h)
{
    s_vpi_value v;
    v.format = vpiIntVal;
    vpi_get_value(h, &v);
    return v.value.integer;
}

/* The INDEX-th statement (from 0) directly under the body of scope NAME. */
static vpiHandle nth_stmt(const char *name, int index)
{
    vpiHandle scope = vpi_handle_by_name((PLI_BYTE8 *)name, 0);
    vpiHandle body = scope ? vpi_handle(vpiStmt, scope) : 0;
    vpiHandle it = body ? vpi_iterate(vpiStmt, body) : 0, stmt = 0;
    int at = 0;
    if (index == 0 && body && !it) return body;
    while (it && (stmt = vpi_scan(it)) != 0) {
        if (at++ == index) {
            vpi_free_object(it);
            return stmt;
        }
    }
    return 0;
}

static void check_assignments(void)
{
    vpiHandle s, l, r, it, op;
    int n;

    /* a = b + c; */
    s = nth_stmt("top.assignments", 0);
    l = s ? vpi_handle(vpiLhs, s) : 0;
    r = s ? vpi_handle(vpiRhs, s) : 0;
    if (!s || vpi_get(vpiType, s) != vpiAssignment) fail("statement 0 type");
    if (!l || strcmp(vpi_get_str(vpiName, l), "a") != 0) fail("a = b + c: lhs");
    if (!r || vpi_get(vpiType, r) != vpiOperation
        || vpi_get(vpiOpType, r) != vpiAddOp || int_value(r) != 7)
        fail("a = b + c: rhs");

    /* mem[2] = a; */
    s = nth_stmt("top.assignments", 1);
    l = s ? vpi_handle(vpiLhs, s) : 0;
    r = s ? vpi_handle(vpiRhs, s) : 0;
    if (!l || vpi_get(vpiSize, l) != 8) fail("mem[2] = a: lhs");
    if (!r || strcmp(vpi_get_str(vpiName, r), "a") != 0) fail("mem[2] = a: rhs");

    /* a[3:0] = 4'd5; */
    s = nth_stmt("top.assignments", 2);
    l = s ? vpi_handle(vpiLhs, s) : 0;
    r = s ? vpi_handle(vpiRhs, s) : 0;
    if (!l || vpi_get(vpiType, l) != vpiPartSelect || vpi_get(vpiSize, l) != 4)
        fail("a[3:0] = 4'd5: lhs");
    if (!r || vpi_get(vpiType, r) != vpiConstant || int_value(r) != 5)
        fail("a[3:0] = 4'd5: rhs");

    /* {hi, lo} = b; */
    s = nth_stmt("top.assignments", 3);
    l = s ? vpi_handle(vpiLhs, s) : 0;
    r = s ? vpi_handle(vpiRhs, s) : 0;
    n = 0;
    it = l ? vpi_iterate(vpiOperand, l) : 0;
    while (it && (op = vpi_scan(it)) != 0) n++;
    if (!l || vpi_get(vpiType, l) != vpiOperation
        || vpi_get(vpiOpType, l) != vpiConcatOp || vpi_get(vpiSize, l) != 8
        || n != 2 || int_value(l) != 0xA5)
        fail("{hi, lo} = b: lhs");
    if (!r || strcmp(vpi_get_str(vpiName, r), "b") != 0) fail("{hi, lo} = b: rhs");

    /* b <= ~c; */
    s = nth_stmt("top.assignments", 4);
    l = s ? vpi_handle(vpiLhs, s) : 0;
    r = s ? vpi_handle(vpiRhs, s) : 0;
    if (!l || strcmp(vpi_get_str(vpiName, l), "b") != 0) fail("b <= ~c: lhs");
    if (!r || vpi_get(vpiOpType, r) != vpiBitNegOp) fail("b <= ~c: rhs");

    /* force x = 1'b1; release x; */
    s = nth_stmt("top.assignments", 5);
    l = s ? vpi_handle(vpiLhs, s) : 0;
    r = s ? vpi_handle(vpiRhs, s) : 0;
    if (!s || vpi_get(vpiType, s) != vpiForce) fail("force type");
    if (!l || strcmp(vpi_get_str(vpiName, l), "x") != 0) fail("force: lhs");
    if (!r || vpi_get(vpiType, r) != vpiConstant || int_value(r) != 1)
        fail("force: rhs");
    s = nth_stmt("top.assignments", 6);
    l = s ? vpi_handle(vpiLhs, s) : 0;
    if (!s || vpi_get(vpiType, s) != vpiRelease) fail("release type");
    if (!l || strcmp(vpi_get_str(vpiName, l), "x") != 0) fail("release: lhs");

    /* The #3042 reproducer: i = 0; in an automatic task. */
    s = nth_stmt("top.check", 0);
    if (!s || vpi_get(vpiType, s) != vpiAssignment || !vpi_handle(vpiLhs, s)
        || !vpi_handle(vpiRhs, s))
        fail("automatic i = 0");

    /* return n + 1; */
    s = nth_stmt("top.next", 0);
    r = s ? vpi_handle(vpiCondition, s) : 0;
    if (!s || vpi_get(vpiType, s) != vpiReturnStmt) fail("return type");
    if (!r || vpi_get(vpiType, r) != vpiOperation
        || vpi_get(vpiOpType, r) != vpiAddOp)
        fail("return n + 1: vpiCondition");
}

/* The #3057 reproducer: the statement a cbForce callback delivers. */
static PLI_INT32 force_cb(p_cb_data data)
{
    vpiHandle s = data->obj;
    force_callbacks++;
    if (!s || vpi_get(vpiType, s) != vpiForce || !vpi_handle(vpiLhs, s)
        || !vpi_handle(vpiRhs, s))
        fail("cbForce statement");
    return 0;
}

static PLI_INT32 probe_calltf(PLI_BYTE8 *user_data)
{
    s_cb_data cb;
    (void)user_data;
    check_assignments();
    memset(&cb, 0, sizeof cb);
    cb.reason = cbForce;
    cb.cb_rtn = force_cb;
    cb.obj = vpi_handle_by_name((PLI_BYTE8 *)"top.x", 0);
    vpi_register_cb(&cb);
    return 0;
}

static PLI_INT32 done_calltf(PLI_BYTE8 *user_data)
{
    (void)user_data;
    if (force_callbacks != 1) fail("cbForce callback count");
    vpi_printf(failures ? "FAILED\n" : "PASSED\n");
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$probe_stmt_exprs";
    data.calltf = probe_calltf;
    vpi_register_systf(&data);
    data.tfname = "$probe_stmt_done";
    data.calltf = done_calltf;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
