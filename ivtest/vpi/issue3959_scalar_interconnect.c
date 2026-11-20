#include <string.h>
#include "vpi_user.h"

/* Annex M.2 object code. Use the numeric value so this probe also builds
   against the older header when checking the regression on the baseline. */
enum { interconnect_net = 533 };
static int failed;
static unsigned bit_changes, real_changes;

static void check(int ok, const char *what)
{
    if (!ok) {
        vpi_printf("Failed: %s\n", what);
        failed = 1;
    }
}

static vpiHandle check_net(const char *name, int type, const char *type_name,
                           int net_type, int size)
{
    vpiHandle net = vpi_handle_by_name(name, NULL);
    check(net != NULL, name);
    if (net) {
        int actual_type = vpi_get(vpiType, net);
        int actual_net_type = vpi_get(vpiNetType, net);
        const char *actual_name = vpi_get_str(vpiType, net);
        if (actual_type != type || actual_net_type != net_type ||
            !actual_name || strcmp(actual_name, type_name) != 0 ||
            vpi_get(vpiSize, net) != size) {
            vpi_printf("%s: type=%d (%s), net type=%d, size=%d\n",
                       name, actual_type, actual_name ? actual_name : "(null)",
                       actual_net_type, vpi_get(vpiSize, net));
            failed = 1;
        }
    }
    return net;
}

static void check_integral(vpiHandle net, int expected, const char *name)
{
    s_vpi_value value = {.format = vpiIntVal};
    if (!net) return;
    vpi_get_value(net, &value);
    check(value.value.integer == expected, name);
}

static void check_real(vpiHandle net, double expected)
{
    s_vpi_value value = {.format = vpiRealVal};
    if (!net) return;
    vpi_get_value(net, &value);
    check(value.value.real == expected, "real interconnect value");
}

static PLI_INT32 changed(p_cb_data cb)
{
    check(vpi_get(vpiType, cb->obj) == interconnect_net, "callback object type");
    if (cb->value->format == vpiScalarVal) {
        ++bit_changes;
        check(cb->value->value.scalar == vpi1, "integral callback value");
    } else {
        ++real_changes;
        check(cb->value->format == vpiRealVal && cb->value->value.real == -2.5,
              "real callback value");
    }
    return 0;
}

static void watch(vpiHandle net, int format)
{
    s_vpi_value value = {.format = format};
    s_vpi_time time = {.type = vpiSuppressTime};
    s_cb_data cb = {.reason = cbValueChange, .cb_rtn = changed,
                    .obj = net, .time = &time, .value = &value};
    if (net) check(vpi_register_cb(&cb) != NULL, "register value callback");
}

static unsigned count_interconnects(vpiHandle scope, int relation)
{
    unsigned count = 0;
    vpiHandle iter = vpi_iterate(relation, scope);
    vpiHandle net;
    while (iter && (net = vpi_scan(iter)))
        if (vpi_get(vpiType, net) == interconnect_net) ++count;
    return count;
}

static PLI_INT32 probe(PLI_BYTE8 *user_data)
{
    s_vpi_value phase = {.format = vpiIntVal};
    vpiHandle args = vpi_iterate(vpiArgument, vpi_handle(vpiSysTfCall, NULL));
    vpi_get_value(vpi_scan(args), &phase);
    vpi_free_object(args);
    (void)user_data;

    vpiHandle bit = check_net("top.bit_link", interconnect_net,
                             "vpiInterconnectNet", vpiInterconnect, 1);
    vpiHandle vec = check_net("top.vec_link", interconnect_net,
                             "vpiInterconnectNet", vpiInterconnect, 3);
    vpiHandle real = check_net("top.real_link", interconnect_net,
                              "vpiInterconnectNet", vpiInterconnect, 1);
    vpiHandle wire = check_net("top.src.bit_out", vpiNet, "vpiNet", vpiWire, 1);
    check_integral(bit, phase.value.integer, "one-bit interconnect value");
    check_integral(vec, 5, "vector-backed interconnect value");
    check_integral(wire, phase.value.integer, "concrete wire value");
    check_real(real, phase.value.integer ? -2.5 : 1.25);

    if (phase.value.integer == 0) {
        vpiHandle scope = vpi_handle_by_name("top", NULL);
        check(count_interconnects(scope, interconnect_net) == 3,
              "interconnect iterator");
        check(count_interconnects(scope, vpiNet) == 3, "net iterator");
        check(count_interconnects(scope, vpiVariables) == 0, "variable iterator");
        watch(bit, vpiScalarVal);
        watch(real, vpiRealVal);
    } else {
        check(bit_changes == 1, "integral callback count");
        check(real_changes == 1, "real callback count");
        if (failed) vpip_set_return_value(1);
        else vpi_printf("PASSED\n");
    }
    return 0;
}

static void setup(void)
{
    s_vpi_systf_data tf = {.type = vpiSysTask, .tfname = "$probe_interconnect",
                          .calltf = probe};
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {setup, NULL};
