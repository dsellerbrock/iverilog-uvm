#include <vpi_user.h>

static PLI_INT32 probe(p_cb_data cb)
{
    static const unsigned expected[][3] = {{1, 5, 20}, {5, 20, 0},
                                           {10, 20, 0}, {0, 0, 0}};
    static const unsigned sizes[] = {3, 2, 2, 0};
    static unsigned stage;
    s_vpi_time tm = {vpiSimTime, 0, 0, 0.0};
    vpiHandle iter = vpi_iterate(vpiTimeQueue, 0), handle;
    unsigned count = 0, failed = 0;
    (void)cb;
    while (iter && (handle = vpi_scan(iter))) {
        vpi_get_time(handle, &tm);
        if (count >= sizes[stage] || tm.high || tm.low != expected[stage][count])
            failed = 1;
        count++;
    }
    if (count != sizes[stage]) failed = 1;
    if (failed) vpi_printf("FAIL stage %u count %u\n", stage, count);
    else vpi_printf("PASS stage %u\n", stage);
    if (stage == 3 && !failed) vpi_printf("PASSED\n");
    stage++;
    return 0;
}

static void startup(void)
{
    static s_vpi_time times[] = {{vpiSimTime, 0, 0, 0.0},
                                 {vpiSimTime, 0, 1, 0.0},
                                 {vpiSimTime, 0, 5, 0.0},
                                 {vpiSimTime, 0, 20, 0.0}};
    s_cb_data cb = {0};
    unsigned i;
    cb.reason = cbReadOnlySynch;
    cb.cb_rtn = probe;
    for (i = 0; i < 4; i++) {
        cb.time = &times[i];
        vpi_register_cb(&cb);
    }
}
void (*vlog_startup_routines[])(void) = {startup, 0};
