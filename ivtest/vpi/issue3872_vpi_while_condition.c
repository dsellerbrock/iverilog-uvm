#include <string.h>
#include <vpi_user.h>

static vpiHandle conditions[2];
static vpiHandle operands[2];
static unsigned compile_count, call_count, check_count;
static int failed;

static void fail(const char *message)
{
    vpi_printf("FAIL issue3872 %s\n", message);
    failed = 1;
}

static vpiHandle find_stmt(vpiHandle parent, int type, unsigned *skip)
{
    vpiHandle iter = vpi_iterate(vpiStmt, parent);
    vpiHandle stmt, match;
    while (iter && (stmt = vpi_scan(iter))) {
        if (vpi_get(vpiType, stmt) == type) {
            if (!*skip) {
                vpi_free_object(iter);
                return stmt;
            }
            --*skip;
        }
        match = find_stmt(stmt, type, skip);
        if (match) {
            vpi_free_object(iter);
            return match;
        }
    }
    return 0;
}

static vpiHandle nth_stmt(vpiHandle parent, int type, unsigned index)
{
    return find_stmt(parent, type, &index);
}

static int describe_condition(unsigned index, vpiHandle stmt, vpiHandle scope,
                              const char *variable, int bound)
{
    vpiHandle condition = stmt ? vpi_handle(vpiCondition, stmt) : 0;
    vpiHandle iter, left, right;
    const char *name;
    s_vpi_value value;

    if (!condition || vpi_get(vpiType, condition) != vpiOperation
        || vpi_get(vpiOpType, condition) != vpiLtOp
        || vpi_handle(vpiScope, condition) != scope)
        return 0;

    iter = vpi_iterate(vpiOperand, condition);
    if (!iter) return 0;
    left = vpi_scan(iter);
    if (!left) return 0;
    right = vpi_scan(iter);
    if (!right) return 0;
    if (vpi_scan(iter)) {
        vpi_free_object(iter);
        return 0;
    }

    name = vpi_get_str(vpiName, left);
    if (!name || strcmp(name, variable) != 0
        || vpi_handle(vpiScope, left) != scope
        || vpi_get(vpiType, right) != vpiConstant)
        return 0;
    value.format = vpiIntVal;
    vpi_get_value(right, &value);
    if (value.value.integer != bound) return 0;

    conditions[index] = condition;
    operands[index] = left;
    return 1;
}

static PLI_INT32 before_task(p_cb_data cb)
{
    vpiHandle task = vpi_handle_by_name("top.reported", 0);
    vpiHandle root = task ? vpi_handle(vpiStmt, task) : 0;
    vpiHandle named = vpi_handle_by_name("top.reported.named_block", 0);
    vpiHandle block, assignment, pred_loop;
    (void)cb;

    if (!root || !describe_condition(0, nth_stmt(root, vpiWhile, 0), task, "i", 3)) {
        fail("expected vpiCondition to be vpiLtOp with operands i and 3 before task call");
        return 0;
    }

    block = nth_stmt(root, vpiNamedBegin, 0);
    if (!named || !block
        || !describe_condition(1, nth_stmt(block, vpiWhile, 0), named, "j", 2))
        fail("expected the named-block condition in its lexical scope");

    assignment = nth_stmt(root, vpiAssignment, 0);
    if (!assignment || vpi_handle(vpiCondition, assignment))
        fail("expected a null vpiCondition on an assignment");

    pred_loop = nth_stmt(root, vpiWhile, 2);
    if (!pred_loop) {
        fail("expected a while with a system-function predicate");
    } else {
        (void)vpi_handle(vpiCondition, pred_loop);
        if (compile_count != 1 || call_count != 0)
            fail("predicate compiletf or calltf count before execution");
    }
    return 0;
}

static PLI_INT32 check_value(ICARUS_VPI_CONST PLI_BYTE8 *user)
{
    static const int expected[] = { vpi1, vpi0, vpiX, vpi1, vpi0 };
    vpiHandle iter = vpi_iterate(vpiArgument, vpi_handle(vpiSysTfCall, 0));
    vpiHandle step_arg = vpi_scan(iter);
    vpiHandle actual_operand = vpi_scan(iter);
    s_vpi_value value;
    unsigned step, index;
    (void)user;

    vpi_free_object(iter);
    value.format = vpiIntVal;
    vpi_get_value(step_arg, &value);
    step = value.value.integer;
    index = step >= 3;
    if (step != check_count || step >= sizeof expected / sizeof expected[0]
        || !conditions[index] || actual_operand != operands[index]) {
        fail("unexpected step or automatic operand handle");
        return 0;
    }

    value.format = vpiScalarVal;
    vpi_get_value(conditions[index], &value);
    if (value.format != vpiScalarVal || value.value.scalar != expected[step])
        fail("wrong condition value during the automatic call");
    ++check_count;
    return 0;
}

static PLI_INT32 compile_predicate(ICARUS_VPI_CONST PLI_BYTE8 *user)
{
    (void)user;
    ++compile_count;
    return 0;
}

static PLI_INT32 call_predicate(ICARUS_VPI_CONST PLI_BYTE8 *user)
{
    s_vpi_value value;
    (void)user;
    value.format = vpiIntVal;
    value.value.integer = ++call_count <= 2;
    vpi_put_value(vpi_handle(vpiSysTfCall, 0), &value, 0, vpiNoDelay);
    return 0;
}

static PLI_INT32 finish_check(ICARUS_VPI_CONST PLI_BYTE8 *user)
{
    (void)user;
    if (check_count != 5 || compile_count != 1 || call_count != 3) {
        vpi_printf("FAIL issue3872 value checks=%u compiletf=%u calltf=%u\n",
                   check_count, compile_count, call_count);
        failed = 1;
    }
    if (!failed) vpi_printf("issue3872 PASSED\n");
    return 0;
}

static void register_probe(void)
{
    static int registered;
    s_cb_data cb = { 0 };
    s_vpi_systf_data tf = { 0 };

    /* JSON ivtest also loads the module that iverilog embeds. */
    if (registered) return;
    registered = 1;

    cb.reason = cbStartOfSimulation;
    cb.cb_rtn = before_task;
    vpi_register_cb(&cb);

    tf.type = vpiSysTask;
    tf.tfname = "$issue3872_check";
    tf.calltf = check_value;
    vpi_register_systf(&tf);
    tf.tfname = "$issue3872_finish";
    tf.calltf = finish_check;
    vpi_register_systf(&tf);

    tf.type = vpiSysFunc;
    tf.sysfunctype = vpiIntFunc;
    tf.tfname = "$issue3872_predicate";
    tf.compiletf = compile_predicate;
    tf.calltf = call_predicate;
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
