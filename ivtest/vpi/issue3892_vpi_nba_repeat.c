#include <string.h>
#include <vpi_user.h>

static vpiHandle reported_repeat, reported_event, reported_count;
static unsigned compile_count, call_count, checks;
static int failed;

static PLI_INT32 fail(const char *message)
{
    vpi_printf("FAIL issue3892 %s\n", message);
    failed = 1;
    return 0;
}

static int read_assignments(vpiHandle task, vpiHandle *assigns, unsigned count)
{
    unsigned i;
    vpiHandle root = task ? vpi_handle(vpiStmt, task) : 0;
    vpiHandle iter = root ? vpi_iterate(vpiStmt, root) : 0;
    if (!iter) return 0;
    for (i = 0; i < count; i++) {
        assigns[i] = vpi_scan(iter);
        if (!assigns[i]) return 0;
        if (vpi_get(vpiType, assigns[i]) != vpiAssignment
            || vpi_iterate(vpiStmt, assigns[i])) {
            vpi_free_object(iter);
            return 0;
        }
    }
    if (!vpi_scan(iter)) return 1;
    vpi_free_object(iter);
    return 0;
}

static int location(vpiHandle obj, int line)
{
    const char *file = vpi_get_str(vpiFile, obj);
    return file && strstr(file, "issue3892_vpi_nba_repeat.sv")
        && vpi_get(vpiLineNo, obj) == line;
}

static vpiHandle repeat_control(vpiHandle assign)
{
    vpiHandle repeat = vpi_handle(vpiRepeatControl, assign);
    vpiHandle event = repeat ? vpi_handle(vpiEventControl, repeat) : 0;
    if (!repeat || vpi_get(vpiType, repeat) != vpiRepeatControl
        || !event || vpi_get(vpiType, event) != vpiEventControl
        || vpi_handle(vpiStmt, event) || vpi_iterate(vpiStmt, event)
        || vpi_iterate(vpiStmt, repeat))
        return 0;
    return repeat;
}

static int integer_value(vpiHandle handle, int expected)
{
    s_vpi_value value;
    if (!handle) return 0;
    value.format = vpiIntVal;
    vpi_get_value(handle, &value);
    return value.format == vpiIntVal && value.value.integer == expected;
}

static int constant_type(vpiHandle count, int width, int is_signed)
{
    return count && vpi_get(vpiType, count) == vpiConstant
        && vpi_get(vpiSize, count) == width
        && vpi_get(vpiSigned, count) == is_signed;
}

static PLI_INT32 probe(ICARUS_VPI_CONST PLI_BYTE8 *user)
{
    vpiHandle reported = vpi_handle_by_name("top.reported", 0);
    vpiHandle cases = vpi_handle_by_name("top.cases", 0);
    vpiHandle lexical = vpi_handle_by_name("top.cases.controls", 0);
    vpiHandle clocked = vpi_handle_by_name("top.clocked", 0);
    vpiHandle reported_assigns[2], assigns[10], controls[10];
    vpiHandle repeat, event, count, iter, arg;
    s_vpi_value value;
    unsigned i, j;
    int expected;
    (void)user;

    if (!read_assignments(reported, reported_assigns, 2))
        return fail("expected the two reported task assignments");
    repeat = repeat_control(reported_assigns[0]);
    if (!repeat) return fail("missing vpiRepeatControl on reported NBA");
    event = vpi_handle(vpiEventControl, repeat);
    count = vpi_handle(vpiExpr, repeat);
    if (!constant_type(count, 6, 1) || !integer_value(count, 2))
        return fail("reported count is not a signed six-bit constant 2");
    if (!location(repeat, 8) || !location(event, 10))
        return fail("reported repeat or event source location");
    if (vpi_handle(vpiScope, repeat) != reported
        || vpi_handle(vpiScope, event) != reported
        || vpi_handle(vpiRepeatControl, reported_assigns[1]))
        return fail("reported scope or spurious repeat control");
    if (checks && (!vpi_compare_objects(reported_repeat, repeat)
                   || !vpi_compare_objects(reported_event, event)
                   || !vpi_compare_objects(reported_count, count)))
        return fail("repeat, event or count identity changed");
    reported_repeat = repeat;
    reported_event = event;
    reported_count = count;

    if (!read_assignments(cases, assigns, 10))
        return fail("expected the ten cases task assignments");
    for (i = 0; i < 10; i++) {
        if (i == 4 || i == 5) {
            if (vpi_handle(vpiRepeatControl, assigns[i]))
                return fail("plain or event-only NBA has a repeat handle");
            continue;
        }
        controls[i] = repeat_control(assigns[i]);
        if (!controls[i]) return fail("missing explicit repeat");
        event = vpi_handle(vpiEventControl, controls[i]);
        if (event == reported_event || !lexical
            || vpi_handle(vpiScope, event) != lexical)
            return fail("wrong event identity or lexical scope");
        for (j = 0; j < i; j++) {
            if (j == 4 || j == 5) continue;
            if (vpi_compare_objects(controls[i], controls[j])
                || vpi_compare_objects(event, vpi_handle(vpiEventControl, controls[j])))
                return fail("different assignments share a repeat or event object");
        }
    }

    for (i = 0; i < 2; i++) {
        count = vpi_handle(vpiExpr, controls[i]);
        if (!constant_type(count, 5, i) || !integer_value(count, i))
            return fail("optimized constant count changed");
    }
    count = vpi_handle(vpiExpr, controls[2]);
    if (!constant_type(count, 6, 1)) return fail("four-state count type");
    value.format = vpiBinStrVal;
    vpi_get_value(count, &value);
    if (value.format != vpiBinStrVal || strcmp(value.value.str, "00xz00"))
        return fail("four-state count bits changed");

    iter = vpi_iterate(vpiArgument, vpi_handle(vpiSysTfCall, 0));
    if (!iter) return fail("missing probe argument");
    arg = vpi_scan(iter);
    value.format = vpiIntVal;
    vpi_get_value(arg, &value);
    expected = value.value.integer;
    vpi_free_object(iter);
    count = vpi_handle(vpiExpr, controls[3]);
    if (!count || vpi_get(vpiType, count) != vpiOperation
        || vpi_get(vpiOpType, count) != vpiAddOp
        || vpi_get(vpiSize, count) != 8 || vpi_get(vpiSigned, count) != 1
        || !integer_value(count, expected))
        return fail("live count operation type or value");
    iter = vpi_iterate(vpiOperand, count);
    if (!iter) return fail("live count has no operands");
    arg = vpi_scan(iter);
    if (!arg || arg != vpi_handle_by_name("top.count_base", 0))
        return fail("live count does not reuse the module variable handle");
    arg = vpi_scan(iter);
    if (!constant_type(arg, 8, 1) || !integer_value(arg, 1))
        return fail("live count constant operand changed");
    if (vpi_scan(iter)) {
        vpi_free_object(iter);
        return fail("live count has extra operands");
    }
    count = vpi_handle(vpiExpr, controls[7]);
    if (!count || vpi_get(vpiType, count) != vpiReg
        || vpi_handle(vpiParent, count) != vpi_handle_by_name("top.count_words", 0)
        || vpi_get(vpiSize, count) != 6 || vpi_get(vpiSigned, count) != 1
        || !integer_value(count, 7))
        return fail("fixed-array count word type or value");
    /* A cast without a VPI representation must not alias its operand. */
    count = vpi_handle(vpiExpr, controls[8]);
    if (count && (vpi_get(vpiSize, count) != 16 || vpi_get(vpiSigned, count) != 0
                  || !integer_value(count, expected - 1)))
        return fail("dynamic cast count was replaced by its operand");
    count = vpi_handle(vpiExpr, controls[9]);
    if (!constant_type(count, 8, 1) || !integer_value(count, -3))
        return fail("folded parameter cast count type or value");

    if (!clocked) return fail("missing clocking drive task");
    arg = vpi_handle(vpiStmt, clocked);
    if (!arg || vpi_get(vpiType, arg) != vpiAssignment
        || vpi_handle(vpiRepeatControl, arg))
        return fail("synthesized clocking drive repeat leaked into VPI");
    if (compile_count != 1 || call_count != 0)
        return fail("metadata duplicated or evaluated a count system call");

    ++checks;
    return 0;
}

static PLI_INT32 compile_repeat_count(ICARUS_VPI_CONST PLI_BYTE8 *user)
{
    (void)user;
    ++compile_count;
    return 0;
}

static PLI_INT32 call_repeat_count(ICARUS_VPI_CONST PLI_BYTE8 *user)
{
    s_vpi_value value;
    (void)user;
    ++call_count;
    value.format = vpiIntVal;
    value.value.integer = 2;
    vpi_put_value(vpi_handle(vpiSysTfCall, 0), &value, 0, vpiNoDelay);
    return 0;
}

static PLI_INT32 finish(ICARUS_VPI_CONST PLI_BYTE8 *user)
{
    (void)user;
    if (!failed && checks == 2) vpi_printf("issue3892 PASSED\n");
    return 0;
}

static void register_probe(void)
{
    static int registered;
    s_vpi_systf_data tf = {0};
    if (registered) return;
    registered = 1;
    tf.type = vpiSysTask;
    tf.tfname = "$issue3892_probe";
    tf.calltf = probe;
    vpi_register_systf(&tf);
    tf.tfname = "$issue3892_finish";
    tf.calltf = finish;
    vpi_register_systf(&tf);
    tf.type = vpiSysFunc;
    tf.sysfunctype = vpiIntFunc;
    tf.tfname = "$issue3892_count";
    tf.compiletf = compile_repeat_count;
    tf.calltf = call_repeat_count;
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {register_probe, 0};
