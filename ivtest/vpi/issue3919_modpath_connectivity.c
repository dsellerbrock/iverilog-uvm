#include <string.h>
#include <vpi_user.h>

static unsigned failures;

static void fail(const char *test, const char *reason)
{
    vpi_printf("FAIL %s: %s\n", test, reason);
    ++failures;
}

static vpiHandle named(const char *name)
{
    return vpi_handle_by_name((PLI_BYTE8 *)name, 0);
}

static int same(vpiHandle a, vpiHandle b)
{
    return a && b && vpi_compare_objects(a, b);
}

static vpiHandle primitive_term(const char *inst, const char *name, int pin)
{
    vpiHandle mod = named(inst);
    vpiHandle it = mod ? vpi_iterate(vpiPrimitive, mod) : 0;
    vpiHandle prim, result = 0;
    while (it && (prim = vpi_scan(it))) {
        const char *prim_name = vpi_get_str(vpiName, prim);
        if (!prim_name || strcmp(name, prim_name)) continue;
        vpiHandle terms = vpi_iterate(vpiPrimTerm, prim), term;
        while (terms && (term = vpi_scan(terms)))
            if (vpi_get(vpiTermIndex, term) == pin) result = term;
    }
    return result;
}

static unsigned of_type(vpiHandle ref, int relation, int type,
                        vpiHandle *results, unsigned capacity)
{
    unsigned n = 0;
    vpiHandle it = ref ? vpi_iterate(relation, ref) : 0, obj;
    while (it && (obj = vpi_scan(it))) {
        if (type && vpi_get(vpiType, obj) != type) continue;
        if (n < capacity) results[n] = obj;
        ++n;
    }
    return n;
}

static void expect(const char *test, vpiHandle ref, int relation,
                   unsigned count, const vpiHandle *want)
{
    vpiHandle got[8];
    unsigned n = of_type(ref, relation, 0, got, 8);
    if (!ref || n != count) {
        vpi_printf("FAIL %s: relation %d returned %u objects, expected %u\n",
                   test, relation, n, count);
        ++failures;
        return;
    }
    for (unsigned i = 0; i < count; ++i) {
        unsigned matches = 0;
        for (unsigned j = 0; j < n; ++j)
            matches += same(want[i], got[j]) != 0;
        if (matches != 1) fail(test, "wrong or repeated connection");
    }
}

static vpiHandle input_term(vpiHandle out)
{
    vpiHandle stage = out ? vpi_handle(vpiDelayDevice, out) : 0;
    return stage ? vpi_handle(vpiInTerm, stage) : 0;
}

static unsigned output_terms(const char *net, vpiHandle *out, unsigned capacity)
{
    return of_type(named(net), vpiDriver, vpiDelayTerm, out, capacity);
}

static vpiHandle outside_assign(int selected)
{
    vpiHandle it = vpi_iterate(vpiContAssign, named("top")), ca, result = 0;
    vpiHandle net = named(selected ? "top.ranged_y" : "top.resolved_y");
    while (it && (ca = vpi_scan(it))) {
        vpiHandle lhs = vpi_handle(vpiLhs, ca);
        if (selected && lhs) lhs = vpi_handle(vpiParent, lhs);
        if (same(lhs, net)) result = ca;
    }
    return result;
}

static void check_scalar(void)
{
    vpiHandle out = 0;
    if (output_terms("top.scalar_dut.y", &out, 1) != 1) {
        fail("scalar", "expected one output terminal");
        return;
    }
    vpiHandle driver = primitive_term("top.scalar_dut", "data_driver", 0);
    vpiHandle loads[] = {
        primitive_term("top.scalar_dut", "local_consumer", 1),
        primitive_term("top", "external_consumer", 1)
    };
    /* Exact sets exclude the trigger's driver and sibling load. */
    expect("scalar pre-delay", input_term(out), vpiDriver, 1, &driver);
    expect("scalar post-delay", out, vpiLoad, 2, loads);
    expect("scalar net driver", named("top.scalar_dut.y"), vpiDriver, 1, &out);
    expect("scalar net loads", named("top.scalar_y"), vpiLoad, 2, loads);
    vpiHandle trigger = primitive_term("top", "trigger_driver", 0);
    vpiHandle sibling = primitive_term("top", "sibling_load", 1);
    expect("trigger driver", named("top.trigger"), vpiDriver, 1, &trigger);
    expect("trigger load", named("top.trigger"), vpiLoad, 1, &sibling);
}

static void check_resolved(void)
{
    vpiHandle out[3], source[2], driver[2];
    if (output_terms("top.resolved_y", out, 2) != 2 ||
        of_type(named("top.resolved_dut"), vpiContAssign, vpiContAssign, source, 2) != 2) {
        fail("resolved", "expected two delay devices and two source assignments");
        return;
    }
    vpiHandle load = primitive_term("top.resolved_dut", "resolved_consumer", 1);
    for (unsigned i = 0; i < 2; ++i) {
        vpiHandle in = input_term(out[i]);
        if (of_type(in, vpiDriver, 0, &driver[i], 1) != 1) {
            fail("resolved pre-delay", "expected the one assignment feeding this resolver input");
            return;
        }
        if (!same(driver[i], source[0]) && !same(driver[i], source[1]))
            fail("resolved pre-delay", "driver from outside this stage");
        s_vpi_value sample = {0};
        sample.format = vpiScalarVal;
        vpi_get_value(in, &sample);
        vpiHandle rhs = 0;
        if (sample.value.scalar == vpi1) rhs = named("top.resolved_dut.data_one");
        if (sample.value.scalar == vpi0) rhs = named("top.resolved_dut.data_zero");
        if (!same(vpi_handle(vpiRhs, driver[i]), rhs))
            fail("resolved pre-delay", "assignment does not match this stage's data");
        expect("resolved post-delay", out[i], vpiLoad, 1, &load);
    }
    if (same(driver[0], driver[1]))
        fail("resolved pre-delay", "both stages returned the same assignment");
    out[2] = outside_assign(0);
    expect("resolved net driver", named("top.resolved_y"), vpiDriver, 3, out);
}

static void check_ranges(void)
{
    vpiHandle out = 0, source[2];
    if (output_terms("top.ranged_dut.y", &out, 1) != 1 ||
        of_type(named("top.ranged_dut"), vpiContAssign, vpiContAssign, source, 2) != 2) {
        fail("ranged", "expected one stage driven by two disjoint slices");
        return;
    }
    expect("ranged pre-delay", input_term(out), vpiDriver, 2, source);
    vpiHandle loads[] = {
        primitive_term("top.ranged_dut", "low_consumer", 1),
        primitive_term("top.ranged_dut", "mid_consumer", 1),
        primitive_term("top.ranged_dut", "high_consumer", 1)
    };
    expect("ranged post-delay", out, vpiLoad, 3, loads);
    vpiHandle bottom[] = {out, outside_assign(1)};
    expect("bit 0 drivers", named("top.ranged_y[0]"), vpiDriver, 2, bottom);
    expect("bit 1 drivers", named("top.ranged_y[1]"), vpiDriver, 1, &out);
    expect("bit 2 drivers", named("top.ranged_y[2]"), vpiDriver, 1, &out);
    expect("bit 0 loads", named("top.ranged_y[0]"), vpiLoad, 1, loads);
    expect("bit 2 loads", named("top.ranged_y[2]"), vpiLoad, 1, loads + 2);
}

static void check_nested(void)
{
    vpiHandle inner = 0, outer = 0;
    if (output_terms("top.nested_dut.inner.y", &inner, 1) != 1 ||
        output_terms("top.nested_dut.y", &outer, 1) != 1 || same(inner, outer)) {
        fail("nested", "expected one distinct stage at each output net");
        return;
    }
    vpiHandle pre = input_term(outer);
    vpiHandle loads[] = {
        primitive_term("top.nested_dut.inner", "local_consumer", 1), pre
    };
    expect("outer pre-delay", pre, vpiDriver, 1, &inner);
    expect("inner post-delay", inner, vpiLoad, 2, loads);
    expect("net between stages", named("top.nested_dut.inner.y"), vpiLoad, 2, loads);
    expect("outer post-delay", outer, vpiLoad, 0, 0);
}

static void check_split(void)
{
    vpiHandle out = 0, ca;
    if (output_terms("top.split_y", &out, 1) != 1 ||
        of_type(named("top.split_dut"), vpiContAssign, vpiContAssign, &ca, 1) != 1) {
        fail("split lvalue", "expected one delay stage and one assignment");
        return;
    }
    expect("split pre-delay", input_term(out), vpiDriver, 1, &ca);
    expect("split delayed output", named("top.split_y"), vpiDriver, 1, &out);
    expect("split sibling output", named("top.split_sibling"), vpiDriver, 1, &ca);
}

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    (void)data;
    check_scalar();
    check_resolved();
    check_ranges();
    check_nested();
    check_split();
    if (failures) {
        vpip_set_return_value(1);
        vpi_control(vpiFinish, 0);
    } else {
        vpi_printf("issue3919 PASSED\n");
    }
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data tf = {0};
    tf.type = vpiSysTask;
    tf.tfname = "$issue3919_probe";
    tf.calltf = probe;
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {register_probe, 0};
