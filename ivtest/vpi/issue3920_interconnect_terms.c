#include <string.h>
#include <vpi_user.h>

static struct branch {
    const char *source_scope, *net, *load_scope, *sibling_scope;
    vpiHandle path, in, out, device;
} branches[] = {
    {"top.source", "top.y", "top.delayed", "top.sibling", 0, 0, 0, 0},
    {"top.sampled", "top.sampled.y", "top.sampled.delayed", "top.sampled.sibling",
     0, 0, 0, 0},
};

static const struct sample {
    unsigned time;
    const char *direct_in, *direct_out, *sampled_in, *sampled_out;
} samples[] = {
    { 4000, "0", "0", "01", "01"}, /* Warm the connection index. */
    { 5000, "0", "0", "01", "01"}, /* Annotate an already live connection. */
    {10000, "1", "0", "10", "01"},
    {11000, "1", "0", "10", "01"}, /* Reannotate while the edge is pending. */
    {12999, "1", "0", "10", "01"},
    {13000, "1", "1", "10", "10"},
    {20000, "0", "1", "zx", "10"},
    {23000, "0", "0", "zx", "zx"},
};
static unsigned next_sample;

static int fail(const char *object, const char *reason)
{
    vpi_printf("FAIL %s: %s\n", object, reason);
    vpip_set_return_value(1);
    vpi_control(vpiFinish, 0);
    return 0;
}

static int same(vpiHandle lhs, vpiHandle rhs)
{
    return lhs && rhs && vpi_compare_objects(lhs, rhs);
}

static vpiHandle named_port(vpiHandle scope, const char *name)
{
    vpiHandle it = vpi_iterate(vpiPort, scope), port, result = 0;
    while (it && (port = vpi_scan(it)))
        if (!strcmp(vpi_get_str(vpiName, port), name))
            result = port;
    return result;
}

static int is_load(vpiHandle item, vpiHandle port, vpiHandle observed)
{
    return same(item, port) || (vpi_get(vpiType, item) == vpiContAssign &&
                                same(vpi_handle(vpiLhs, item), observed));
}

static vpiHandle delay_term(int rel, vpiHandle net, unsigned *count)
{
    vpiHandle it = vpi_iterate(rel, net), item, result = 0;
    *count = 0;
    while (it && (item = vpi_scan(it)))
        if (vpi_get(vpiType, item) == vpiDelayTerm) {
            ++*count;
            result = item;
        }
    return result;
}

static int expect_value(vpiHandle obj, const char *name, const char *expected)
{
    s_vpi_value val = {0};
    val.format = vpiBinStrVal;
    vpi_get_value(obj, &val);
    if (val.value.str && !strcmp(val.value.str, expected))
        return 1;
    vpi_printf("At %u ps expected %s, got %s\n", samples[next_sample].time,
               expected, val.value.str ? val.value.str : "<no value>");
    return fail(name, "wrong value");
}

static int check_path(struct branch *branch, const char *pre, const char *post)
{
    vpiHandle source_scope = vpi_handle_by_name(branch->source_scope, 0);
    vpiHandle load_scope = vpi_handle_by_name(branch->load_scope, 0);
    vpiHandle sibling_scope = vpi_handle_by_name(branch->sibling_scope, 0);
    vpiHandle net = vpi_handle_by_name(branch->net, 0);
    vpiHandle load = vpi_handle_by_name("a", load_scope);
    vpiHandle sibling = vpi_handle_by_name("a", sibling_scope);
    vpiHandle load_observed = vpi_handle_by_name("observed", load_scope);
    vpiHandle sibling_observed = vpi_handle_by_name("observed", sibling_scope);
    vpiHandle load_port, sibling_port, source_port, in, out, dev, it, item;
    unsigned ni, no, ns;
    int reaches_load = 0, reaches_sibling = 0;

    if (!source_scope || !load_scope || !sibling_scope || !net || !load ||
        !sibling || !load_observed || !sibling_observed)
        return fail(branch->net, "missing fixture object");
    source_port = named_port(source_scope, "y");
    load_port = named_port(load_scope, "a");
    sibling_port = named_port(sibling_scope, "a");
    if (!source_port || !load_port || !sibling_port)
        return fail(branch->net, "missing fixture port");

    in = delay_term(vpiLoad, net, &ni);
    out = delay_term(vpiDriver, load, &no);
    delay_term(vpiDriver, sibling, &ns);
    if (ni != (next_sample != 0) || no != (next_sample != 0) || ns)
        return fail(branch->net, "wrong delay terminal counts on source, load or sibling");

    it = vpi_iterate(vpiLoad, net);
    while (it && (item = vpi_scan(it))) {
        reaches_load |= is_load(item, load_port, load_observed);
        reaches_sibling |= is_load(item, sibling_port, sibling_observed);
    }
    if (reaches_load != (next_sample == 0) || !reaches_sibling)
        return fail(branch->net, "wrong branch connectivity");
    if (!expect_value(load, branch->load_scope, post) ||
        !expect_value(sibling, branch->sibling_scope, pre))
        return 0;
    if (!next_sample)
        return 1;

    dev = vpi_handle(vpiDelayDevice, in);
    if (!dev || vpi_get(vpiType, dev) != vpiDelayDevice ||
        vpi_get(vpiDelayType, dev) != vpiInterModPathDelay ||
        vpi_get(vpiDelayType, in) != vpiInterModPathDelay ||
        vpi_get(vpiDelayType, out) != vpiInterModPathDelay ||
        !same(dev, vpi_handle(vpiDelayDevice, out)) ||
        !same(load_scope, vpi_handle(vpiModule, dev)) ||
        !same(in, vpi_handle(vpiInTerm, dev)) ||
        !same(out, vpi_handle(vpiOutTerm, dev)))
        return fail(branch->net, "wrong delay device, owner or terminal relationship");

    it = vpi_iterate(vpiDriver, load);
    if (!it || !same(out, vpi_scan(it)) || vpi_scan(it))
        return fail(branch->net, "delayed formal must be driven only by the output term");

    reaches_load = 0;
    it = vpi_iterate(vpiLoad, out);
    while (it && (item = vpi_scan(it))) {
        reaches_load |= is_load(item, load_port, load_observed);
        if (is_load(item, sibling_port, sibling_observed))
            return fail(branch->net, "output terminal reaches an undelayed sibling");
    }
    if (!reaches_load)
        return fail(branch->net, "output terminal cannot reach its load");

    /* For the direct wire path, the upstream output port drives the
       source net. The sampled path's actual is a procedural variable. */
    if (vpi_get(vpiType, net) == vpiNet) {
        it = vpi_iterate(vpiDriver, in);
        if (!it || !same(source_port, vpi_scan(it)) || vpi_scan(it))
            return fail(branch->net, "wrong input terminal driver");
    }

    vpiHandle path = vpi_handle_multi(vpiInterModPath, source_port, load_port);
    if (!path || vpi_get(vpiType, path) != vpiInterModPath)
        return fail(branch->net, "missing intermodule delay access handle");
    it = vpi_iterate(vpiPort, path);
    if (!it || !same(source_port, vpi_scan(it)) || !same(load_port, vpi_scan(it)) ||
        vpi_scan(it))
        return fail(branch->net, "wrong intermodule path endpoints");
    s_vpi_time times[2] = {{0}, {0}};
    s_vpi_delay delay = {0};
    delay.da = times;
    delay.no_of_delays = 2;
    delay.time_type = vpiSimTime;
    vpi_get_delays(path, &delay);
    if (times[0].high || times[0].low != 3000 || times[1].high || times[1].low != 3000)
        return fail(branch->net, "intermodule path must retain the 3 ns ABSOLUTE delay");

    if (branch->device && (!same(dev, branch->device) || !same(in, branch->in) ||
                           !same(out, branch->out) || !same(path, branch->path)))
        return fail(branch->net, "delay stage identity changed");
    branch->device = dev;
    branch->in = in;
    branch->out = out;
    branch->path = path;

    return expect_value(in, "input terminal", pre) && expect_value(out, "output terminal", post);
}

static PLI_INT32 read_only(p_cb_data cb)
{
    const struct sample *sample = &samples[next_sample];
    s_vpi_time now = {0};
    (void)cb;
    now.type = vpiSimTime;
    vpi_get_time(0, &now);
    if (now.high || now.low != sample->time)
        return fail("probe", "wrong sample time");

    if (check_path(&branches[0], sample->direct_in, sample->direct_out) &&
        check_path(&branches[1], sample->sampled_in, sample->sampled_out) &&
        ++next_sample == sizeof samples / sizeof samples[0])
        vpi_printf("issue3920 PASSED\n");
    return 0;
}

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    s_vpi_time time = {0};
    s_cb_data cb = {0};
    (void)data;
    if (next_sample >= sizeof samples / sizeof samples[0])
        return fail("probe", "extra sample");
    time.type = vpiSimTime;
    cb.reason = cbReadOnlySynch;
    cb.cb_rtn = read_only;
    cb.time = &time;
    if (!vpi_register_cb(&cb))
        return fail("probe", "could not register read-only callback");
    return 0;
}

static void startup(void)
{
    s_vpi_systf_data tf = {0};
    tf.type = vpiSysTask;
    tf.tfname = "$issue3920_probe";
    tf.calltf = probe;
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {startup, 0};
