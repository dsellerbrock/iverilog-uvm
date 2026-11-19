#include <string.h>
#include <vpi_user.h>

static vpiHandle exact, z_case, x_case, real_comparison, operation, real_operation;
static unsigned reads;
static int failed;

static void fail(const char *message)
{
    failed = 1;
    vpi_printf("FAIL issue3874 %s\n", message);
}

static vpiHandle find_case(vpiHandle parent, unsigned *skip)
{
    vpiHandle iter, stmt;
    if (!parent) return 0;
    if (vpi_get(vpiType, parent) == vpiCase) {
        if (*skip == 0) return parent;
        --*skip;
    }
    iter = vpi_iterate(vpiStmt, parent);
    while (iter && (stmt = vpi_scan(iter))) {
        vpiHandle found = find_case(stmt, skip);
        if (found) {
            vpi_free_object(iter);
            return found;
        }
    }
    return 0;
}

static vpiHandle task_case(const char *name, unsigned index)
{
    vpiHandle task = vpi_handle_by_name(name, 0);
    return task ? find_case(vpi_handle(vpiStmt, task), &index) : 0;
}

static vpiHandle selector(const char *task)
{
    vpiHandle stmt = task_case(task, 0);
    return stmt ? vpi_handle(vpiCondition, stmt) : 0;
}

static int same_object(vpiHandle a, vpiHandle b)
{
    return a && b && vpi_compare_objects(a, b);
}

static int bits_equal(vpiHandle object, const char *bits)
{
    s_vpi_value value;
    if (!object) return 0;
    value.format = vpiBinStrVal;
    vpi_get_value(object, &value);
    return value.format == vpiBinStrVal && value.value.str
        && strcmp(value.value.str, bits) == 0;
}

static int add_operands_are(vpiHandle expr, vpiHandle a, vpiHandle b)
{
    vpiHandle iter, left, right;
    int match;
    if (!expr || vpi_get(vpiType, expr) != vpiOperation
        || vpi_get(vpiOpType, expr) != vpiAddOp)
        return 0;
    iter = vpi_iterate(vpiOperand, expr);
    left = iter ? vpi_scan(iter) : 0;
    right = left ? vpi_scan(iter) : 0;
    match = same_object(left, a) && same_object(right, b);
    if (right && vpi_scan(iter)) {
        vpi_free_object(iter);
        return 0;
    }
    return match;
}

static PLI_INT32 inspect(p_cb_data cb)
{
    vpiHandle x = vpi_handle_by_name("top.x", 0);
    vpiHandle y = vpi_handle_by_name("top.y", 0);
    vpiHandle wildcard = vpi_handle_by_name("top.wildcard_value", 0);
    vpiHandle nested = vpi_handle_by_name("top.operation_case.nested", 0);
    vpiHandle offset = vpi_handle_by_name("top.offset", 0);
    vpiHandle literal, cast;
    unsigned idx;
    (void)cb;

    exact = selector("top.exact_case");
    if (!same_object(exact, x) || vpi_get(vpiSize, exact) != 2)
        fail("case selector must be the original two-bit variable");
    if (!same_object(selector("top.pruned_case"), x))
        fail("comparison pruning must preserve the selector handle");

    z_case = selector("top.z_case");
    x_case = selector("top.x_case");
    if (!same_object(z_case, wildcard) || !same_object(x_case, wildcard))
        fail("casez and casex must expose the original four-state variable");

    real_comparison = selector("top.real_comparison");
    if (!same_object(real_comparison, x))
        fail("real comparison must expose the original integral selector");

    operation = selector("top.operation_case");
    if (!add_operands_are(operation, x, y)
        || vpi_get(vpiSize, operation) != 8
        || !nested || vpi_handle(vpiScope, operation) != nested)
        fail("expected an eight-bit addition in the selector's lexical scope");

    real_operation = selector("top.real_operation");
    if (!add_operands_are(real_operation, x, offset))
        fail("real addition must expose its original operands");

    literal = selector("top.explicit_true");
    if (!literal || vpi_get(vpiType, literal) != vpiConstant
        || !bits_equal(literal, "1"))
        fail("explicit constant-true selector must be visible");

    cast = task_case("top.cast_selector", 0);
    if (!cast || same_object(vpi_handle(vpiCondition, cast), x))
        fail("a cast selector cannot be represented by its input variable");

    for (idx = 0; idx < 5; ++idx) {
        vpiHandle stmt = task_case("top.lowered_cases", idx);
        if (!stmt || vpi_handle(vpiCondition, stmt))
            fail("lowered case has a missing statement or a synthetic selector");
    }
    return 0;
}

static PLI_INT32 read_selectors(ICARUS_VPI_CONST PLI_BYTE8 *user)
{
    vpiHandle iter = vpi_iterate(vpiArgument, vpi_handle(vpiSysTfCall, 0));
    s_vpi_value value;
    int step;
    (void)user;
    value.format = vpiIntVal;
    vpi_get_value(vpi_scan(iter), &value);
    vpi_free_object(iter);
    step = value.value.integer;
    ++reads;

    if (step == 2) {
        if (!bits_equal(x_case, "x1")) fail("casex selector must retain X");
    } else {
        if (!bits_equal(exact, step ? "11" : "01")
            || !bits_equal(real_comparison, step ? "11" : "01"))
            fail("case selectors must follow changes to the variable");
        if (!bits_equal(z_case, step ? "z1" : "z0")
            || !bits_equal(x_case, step ? "z1" : "z0"))
            fail("wildcard selectors must retain Z");
        if (!bits_equal(operation, step ? "00000101" : "00000011"))
            fail("addition must evaluate at the case context width");
        if (real_operation) {
            value.format = vpiRealVal;
            vpi_get_value(real_operation, &value);
            if (value.format != vpiRealVal || value.value.real != (step ? 3.5 : 1.5))
                fail("real addition must evaluate as a real");
        }
    }
    return 0;
}

static PLI_INT32 finish_check(ICARUS_VPI_CONST PLI_BYTE8 *user)
{
    (void)user;
    if (reads != 3) fail("expected three reads of the selectors");
    if (!failed) vpi_printf("issue3874 PASSED\n");
    return 0;
}

static void register_probe(void)
{
    static int registered;
    s_cb_data cb = {0};
    s_vpi_systf_data tf = {0};
    /* JSON ivtest can load the module already embedded by iverilog. */
    if (registered) return;
    registered = 1;

    cb.reason = cbStartOfSimulation;
    cb.cb_rtn = inspect;
    vpi_register_cb(&cb);
    tf.type = vpiSysTask;
    tf.tfname = "$issue3874_read";
    tf.calltf = read_selectors;
    vpi_register_systf(&tf);
    tf.tfname = "$issue3874_finish";
    tf.calltf = finish_check;
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
