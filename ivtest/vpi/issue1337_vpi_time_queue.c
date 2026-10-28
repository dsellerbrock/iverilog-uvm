#include <string.h>
#include <vpi_user.h>

static PLI_INT32 probe(p_cb_data cb)
{
    vpiHandle iter, handle;
    s_vpi_time now = { vpiSimTime, 0, 0, 0.0 };
    s_vpi_time tm = { vpiSimTime, 0, 0, 0.0 };
    unsigned previous = 0;
    unsigned count = 0;
    unsigned found_expected = 0;
    unsigned expected = 5;

    (void)cb;
    vpi_get_time(0, &now);
    if (now.low == 5) expected = 10;
    iter = vpi_iterate(vpiTimeQueue, 0);
    while (iter && (handle = vpi_scan(iter))) {
        vpi_get_time(handle, &tm);
        if (tm.high != 0 || (count && tm.low <= previous)) {
            vpi_printf("FAIL unexpected time queue entry %u:%u at index %u\n",
                       tm.high, tm.low, count);
            vpi_control(vpiFinish, 1);
            return 0;
        }
        vpi_printf("TIMEQUEUE_AT%u[%u]=%u\n", now.low, count, tm.low);
        if (tm.low == expected) found_expected = 1;
        previous = tm.low;
        count++;
    }

    if (!count || !found_expected) {
        vpi_printf("FAIL expected pending time %u at time %u\n",
                   expected, now.low);
        vpi_control(vpiFinish, 1);
        return 0;
    }
    vpi_printf("TIMEQUEUE_COUNT_AT%u=%u\nPASSED\n", now.low, count);
    return 0;
}

static void startup(void)
{
    static s_vpi_time now = { vpiSimTime, 0, 0, 0.0 };
    static s_vpi_time five = { vpiSimTime, 0, 5, 0.0 };
    s_cb_data cb;
    memset(&cb, 0, sizeof cb);
    cb.reason = cbReadOnlySynch;
    cb.cb_rtn = probe;
    cb.time = &now;
    vpi_register_cb(&cb);
    cb.time = &five;
    vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = { startup, 0 };
