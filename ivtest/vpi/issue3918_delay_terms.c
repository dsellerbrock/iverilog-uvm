#include <string.h>
#include <vpi_user.h>

static const struct sample {
    unsigned time;
    const char *scalar_in, *scalar_out, *scalar_net;
    const char *vector_in, *vector_out;
} samples[] = {
    {11, "0", "1", "1", "10", "01"},
    {14, "0", "1", "1", "10", "11"},
    {16, "0", "0", "1", "10", "10"},
    {20, "0", "0", "0", "zx", "zx"},
};

static unsigned next_sample;

static int fail(const char *object, const char *reason)
{
    vpi_printf("FAIL %s: %s\n", object, reason);
    vpip_set_return_value(1);
    vpi_control(vpiFinish, 0);
    return 0;
}

static int same_handle(vpiHandle a, vpiHandle b)
{
    return a && b && vpi_compare_objects(a, b);
}

static vpiHandle find_driver(vpiHandle net, int type, unsigned *count)
{
    vpiHandle it = vpi_iterate(vpiDriver, net);
    vpiHandle driver, found = 0;
    *count = 0;
    while (it && (driver = vpi_scan(it))) {
        if (vpi_get(vpiType, driver) == type) {
            found = driver;
            ++*count;
        }
    }
    return found;
}

static int expect_value(vpiHandle obj, const char *name, const char *expected)
{
    s_vpi_value value = {0};
    s_vpi_time now = {0};
    value.format = vpiBinStrVal;
    vpi_get_value(obj, &value);
    if (value.value.str && strcmp(value.value.str, expected) == 0)
        return 1;
    now.type = vpiSimTime;
    vpi_get_time(0, &now);
    vpi_printf("At t=%u expected %s, got %s\n", now.low, expected,
               value.value.str ? value.value.str : "<no value>");
    return fail(name, "wrong four-state value");
}

static int check_path(const char *name, const char *input, const char *output,
                      const char *net_value)
{
    vpiHandle module = vpi_handle_by_name(name, 0);
    vpiHandle net = module ? vpi_handle_by_name("y", module) : 0;
    vpiHandle driver, device, in, out;
    unsigned count;

    if (!net || vpi_get(vpiType, net) != vpiNet)
        return fail(name, "missing output net");
    driver = find_driver(net, vpiDelayTerm, &count);
    if (!driver)
        return fail(name, "no vpiDelayTerm in output net's vpiDriver iterator");
    if (count != 1)
        return fail(name, "expected one output terminal per destination stage");
    if (!same_handle(driver, find_driver(net, vpiDelayTerm, &count)))
        return fail(name, "driver handle changed on a second iteration");

    device = vpi_handle(vpiDelayDevice, driver);
    if (!device || vpi_get(vpiType, device) != vpiDelayDevice ||
        vpi_get(vpiDelayType, device) != vpiModPathDelay ||
        !same_handle(module, vpi_handle(vpiModule, device)))
        return fail(name, "wrong delay device type or owning module");
    in = vpi_handle(vpiInTerm, device);
    out = vpi_handle(vpiOutTerm, device);
    if (!same_handle(driver, out) || !in || same_handle(in, out) ||
        !same_handle(in, vpi_handle(vpiInTerm, device)) ||
        vpi_get(vpiType, in) != vpiDelayTerm ||
        vpi_get(vpiDelayType, in) != vpiModPathDelay ||
        vpi_get(vpiDelayType, out) != vpiModPathDelay ||
        !same_handle(device, vpi_handle(vpiDelayDevice, in)) ||
        !same_handle(device, vpi_handle(vpiDelayDevice, out)))
        return fail(name, "wrong delay terminal types or relations");

    return expect_value(in, "input delay terminal", input) &&
           expect_value(out, "output delay terminal", output) &&
           expect_value(net, name, net_value);
}

static PLI_INT32 read_only(p_cb_data cb)
{
    const struct sample *sample = &samples[next_sample];
    s_vpi_time now = {0};
    vpiHandle control;
    unsigned count;
    (void)cb;

    now.type = vpiSimTime;
    vpi_get_time(0, &now);
    if (now.high || now.low != sample->time)
        return fail("read-only callback", "unexpected simulation time");
    if (!check_path("top.scalar_path", sample->scalar_in, sample->scalar_out,
                    sample->scalar_net) ||
        !check_path("top.vector_path", sample->vector_in, sample->vector_out,
                    sample->vector_out))
        return 0;

    control = vpi_handle_by_name("top.scalar_path.q", 0);
    if (!control || find_driver(control, vpiDelayTerm, &count) ||
        !find_driver(control, vpiContAssign, &count))
        return fail("ordinary assign #5", "expected an assignment driver without a delay device");
    if (!expect_value(control, "ordinary assign #5", sample->scalar_out))
        return 0;

    if (++next_sample == sizeof samples / sizeof samples[0])
        vpi_printf("issue3918 PASSED\n");
    return 0;
}

static PLI_INT32 sample_call(PLI_BYTE8 *data)
{
    s_vpi_time time = {0};
    s_cb_data cb = {0};
    (void)data;
    if (next_sample >= sizeof samples / sizeof samples[0])
        return fail("read-only callback", "unexpected extra sample");
    time.type = vpiSimTime;
    cb.reason = cbReadOnlySynch;
    cb.cb_rtn = read_only;
    cb.time = &time;
    if (!vpi_register_cb(&cb))
        return fail("read-only callback", "registration failed");
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data tf = {0};
    tf.type = vpiSysTask;
    tf.tfname = "$issue3918_sample";
    tf.calltf = sample_call;
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {register_probe, 0};
