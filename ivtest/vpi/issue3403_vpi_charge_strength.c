#include <vpi_user.h>

static int check(vpiHandle net, const char *name, PLI_INT32 expected)
{
    if (net == 0) {
        vpi_printf("FAIL: missing %s\n", name);
        return 1;
    }
    PLI_INT32 actual = vpi_get(vpiChargeStrength, net);
    if (actual != expected) {
        vpi_printf("FAIL: %s charge strength %d, expected %d\n",
                   name, actual, expected);
        return 1;
    }
    return 0;
}

static PLI_INT32 check_charge_strengths(p_cb_data cb)
{
    static const struct {
        const char *name;
        PLI_INT32 strength;
    } cases[] = {
        {"top.large_cap", vpiLargeCharge},
        {"top.small_cap", vpiSmallCharge},
        {"top.medium_cap", vpiMediumCharge},
        {"top.default_cap", vpiMediumCharge},
        {"top.cap_array", vpiSmallCharge},
        {"top.packed_cap", vpiMediumCharge},
        {"top.outer_cap", vpiLargeCharge},
        {"top.u.cap", vpiSmallCharge},
        {"top.ordinary", vpiUndefined},
        {"top.v.cap", vpiSmallCharge},
    };
    int failures = 0;
    (void)cb;

    for (unsigned i = 0; i < sizeof cases / sizeof cases[0]; ++i)
        failures += check(vpi_handle_by_name(cases[i].name, 0),
                          cases[i].name, cases[i].strength);

    vpiHandle array = vpi_handle_by_name("top.cap_array", 0);
    if (array)
        failures += check(vpi_handle_by_index(array, 3), "top.cap_array[3]",
                          vpiSmallCharge);

    vpiHandle vector = vpi_handle_by_name("top.small_cap", 0);
    if (vector)
        failures += check(vpi_handle_by_index(vector, 1), "top.small_cap[1]",
                          vpiSmallCharge);

    vpiHandle packed = vpi_handle_by_name("top.packed_cap", 0);
    if (packed)
        failures += check(vpi_handle_by_index(packed, 1), "top.packed_cap[1]",
                          vpiMediumCharge);

    if (failures == 0)
        vpi_printf("PASSED\n");
    return 0;
}

static void register_check(void)
{
    s_cb_data cb = {0};
    cb.reason = cbStartOfSimulation;
    cb.cb_rtn = check_charge_strengths;
    vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = {register_check, 0};
