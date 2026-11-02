#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

#ifndef vpiNamedEventArray
#define vpiNamedEventArray 129
#endif

static int fail(const char *what)
{
    vpi_printf("FAIL %s\n", what);
    vpi_control(vpiFinish, 1);
    return 0;
}

static int int_value(vpiHandle handle)
{
    s_vpi_value value;
    value.format = vpiIntVal;
    vpi_get_value(handle, &value);
    return value.value.integer;
}

static PLI_INT32 probe(p_cb_data cb)
{
    (void)cb;
    vpiHandle array = vpi_handle_by_name((PLI_BYTE8 *)"top.evs", 0);
    vpiHandle member = vpi_handle_by_name((PLI_BYTE8 *)"top.evs[2]", 0);
    vpiHandle indexed = array ? vpi_handle_by_index(array, 2) : 0;
    vpiHandle ranges = array ? vpi_iterate(vpiRange, array) : 0;
    vpiHandle range = ranges ? vpi_scan(ranges) : 0;
    vpiHandle left = range ? vpi_handle(vpiLeftRange, range) : 0;
    vpiHandle right = range ? vpi_handle(vpiRightRange, range) : 0;
    vpiHandle indices = member ? vpi_iterate(vpiIndex, member) : 0;
    vpiHandle index = indices ? vpi_scan(indices) : 0;

    if (!array || vpi_get(vpiType, array) != vpiNamedEventArray)
        return fail("array type");
    if (!member || !indexed || indexed != member ||
        vpi_get(vpiType, member) != vpiNamedEvent)
        return fail("member access");
    if (vpi_get(vpiArrayMember, member) != 1)
        return fail("member property");
    if (!left || !right || int_value(left) != 3 || int_value(right) != 1)
        return fail("declared range");
    if (!index || int_value(index) != 2)
        return fail("member index");
    if (vpi_handle_by_index(array, 4) != 0)
        return fail("out of range index");

    vpi_printf("PASSED\n");
    return 0;
}

static void startup(void)
{
    static s_vpi_time time = { vpiSimTime, 0, 1, 0 };
    s_cb_data cb;
    memset(&cb, 0, sizeof cb);
    cb.reason = cbAfterDelay;
    cb.time = &time;
    cb.cb_rtn = probe;
    vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = { startup, 0 };
