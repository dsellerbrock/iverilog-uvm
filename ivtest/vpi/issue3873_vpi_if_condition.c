#include <string.h>
#include <vpi_user.h>

static int failed;

static void fail(const char *name, const char *message)
{
    vpi_printf("FAIL %s: %s\n", name, message);
    failed = 1;
}

static vpiHandle task_body(const char *name)
{
    vpiHandle task = vpi_handle_by_name(name, 0);
    return task ? vpi_handle(vpiStmt, task) : 0;
}

static vpiHandle condition(const char *name, int type)
{
    vpiHandle stmt = task_body(name);
    vpiHandle expr;
    if (!stmt || vpi_get(vpiType, stmt) != type) {
        fail(name, "wrong statement type");
        return 0;
    }
    expr = vpi_handle(vpiCondition, stmt);
    if (!expr)
        fail(name, "no vpiCondition");
    return expr;
}

static int has_bits(vpiHandle expr, int type, const char *bits)
{
    s_vpi_value value;
    if (!expr || vpi_get(vpiType, expr) != type
        || vpi_get(vpiSize, expr) != (int)strlen(bits))
        return 0;
    value.format = vpiBinStrVal;
    vpi_get_value(expr, &value);
    return value.value.str && !strcmp(value.value.str, bits);
}

static int has_real(vpiHandle expr, int type, double expected)
{
    s_vpi_value value;
    if (!expr || vpi_get(vpiType, expr) != type) return 0;
    value.format = vpiRealVal;
    vpi_get_value(expr, &value);
    return value.value.real == expected;
}

static int has_equality_operands(vpiHandle expr, vpiHandle bus)
{
    vpiHandle iter, left, right;
    if (!expr || vpi_get(vpiType, expr) != vpiOperation
        || vpi_get(vpiOpType, expr) != vpiEqOp)
        return 0;

    iter = vpi_iterate(vpiOperand, expr);
    if (!iter) return 0;
    left = vpi_scan(iter);
    if (!left) return 0;
    right = vpi_scan(iter);
    if (!right) return 0;
    if (vpi_scan(iter)) {
        vpi_free_object(iter);
        return 0;
    }
    return left == bus && has_bits(right, vpiConstant, "1001");
}

static int exposes_source_if(vpiHandle stmt)
{
    vpiHandle iter, child;
    int type = vpi_get(vpiType, stmt);
    if (type == vpiIf || type == vpiIfElse || vpi_handle(vpiCondition, stmt))
        return 1;
    iter = vpi_iterate(vpiStmt, stmt);
    while (iter && (child = vpi_scan(iter))) {
        if (exposes_source_if(child)) {
            vpi_free_object(iter);
            return 1;
        }
    }
    return 0;
}

static PLI_INT32 check(PLI_BYTE8 *data)
{
    vpiHandle bus = vpi_handle_by_name("top.bus", 0);
    vpiHandle level = vpi_handle_by_name("top.level", 0);
    vpiHandle expr, stmt;
    (void)data;

    expr = condition("top.equality", vpiIfElse);
    if (!has_equality_operands(expr, bus))
        fail("equality", "condition must be bus == 4'b1001");

    expr = condition("top.plain_if", vpiIf);
    if (expr != bus || !has_bits(expr, vpiReg, "10xz"))
        fail("plain_if", "condition must be the original four-state bus");

    expr = condition("top.folded_true", vpiIfElse);
    if (!has_bits(expr, vpiConstant, "10xz"))
        fail("folded_true", "condition lost its literal");
    expr = condition("top.folded_false", vpiIfElse);
    if (!has_bits(expr, vpiConstant, "00xz"))
        fail("folded_false", "condition lost its literal");

    expr = condition("top.empty_else", vpiIfElse);
    if (!expr || expr != bus)
        fail("empty_else", "must preserve if/else and its condition");

    expr = condition("top.real_if", vpiIf);
    if (expr != level || !has_real(expr, vpiRealVar, -2.5))
        fail("real_if", "condition must be the original real variable");
    expr = condition("top.real_literal", vpiIf);
    if (!has_real(expr, vpiConstant, -3.25)
        || vpi_get(vpiConstType, expr) != vpiRealConst)
        fail("real_literal", "condition lost its literal");

    stmt = task_body("top.immediate_assertion");
    if (!stmt || exposes_source_if(stmt))
        fail("immediate_assertion", "advertised an ordinary if");
    if (failed) {
        vpip_set_return_value(1);
        vpi_control(vpiFinish, 0);
    }
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data tf = {0};
    tf.type = vpiSysTask;
    tf.tfname = "$issue3873_check";
    tf.calltf = check;
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {register_probe, 0};
