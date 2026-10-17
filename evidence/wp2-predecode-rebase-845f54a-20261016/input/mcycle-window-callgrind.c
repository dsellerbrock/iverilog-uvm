#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "valgrind/callgrind.h"
#include "vpi_user.h"

static vpiHandle mcycle;
static uint32_t window_start, window_end;
static int started, finished;

static int read_limit(const char *name, uint32_t *limit)
{
    const char *text = getenv(name);
    char *end = NULL;
    unsigned long value;
    if (!text || !*text)
        return 0;
    value = strtoul(text, &end, 10);
    if (end == text || *end || value > UINT32_MAX)
        return 0;
    *limit = (uint32_t)value;
    return 1;
}

static uint32_t read_cycle(void)
{
    s_vpi_value value = {0};
    value.format = vpiIntVal;
    vpi_get_value(mcycle, &value);
    return (uint32_t)value.value.integer;
}

static PLI_INT32 on_mcycle(p_cb_data cb)
{
    uint32_t cycle;
    (void)cb;
    cycle = read_cycle();
    if (!started && cycle >= window_start) {
        CALLGRIND_ZERO_STATS;
        CALLGRIND_START_INSTRUMENTATION;
        started = 1;
    }
    if (started && cycle >= window_end) {
        CALLGRIND_STOP_INSTRUMENTATION;
        CALLGRIND_DUMP_STATS_AT("fixed mcycle window");
        vpi_printf("CALLGRIND_MCYCLE_WINDOW start=%u end=%u cycles=%u\n",
                   window_start, cycle, cycle - window_start);
        fflush(stdout);
        finished = 1;
        vpi_control(vpiFinish, 0);
    }
    return 0;
}

static PLI_INT32 on_end(p_cb_data cb)
{
    (void)cb;
    if (!finished)
        vpi_printf("CALLGRIND_MCYCLE_WINDOW_INCOMPLETE started=%d\n", started);
    return 0;
}

static PLI_INT32 start_of_simulation(p_cb_data cb)
{
    s_cb_data change = {0}, end = {0};
    (void)cb;
    mcycle = vpi_handle_by_name(
        (PLI_BYTE8 *)"caliptra_top_tb.caliptra_top_dut.rvtop.veer.dec.tlu.mcyclel",
        NULL);
    if (!mcycle || !read_limit("CALIPTRA_MCYCLE_WINDOW_START", &window_start) ||
        !read_limit("CALIPTRA_MCYCLE_WINDOW_END", &window_end) ||
        window_start >= window_end) {
        vpi_printf("CALLGRIND_MCYCLE_WINDOW_ERROR bind_or_limits\n");
        fflush(stdout);
        vpi_control(vpiFinish, 0);
        return 0;
    }
    change.reason = cbValueChange;
    change.cb_rtn = on_mcycle;
    change.obj = mcycle;
    vpi_register_cb(&change);
    end.reason = cbEndOfSimulation;
    end.cb_rtn = on_end;
    vpi_register_cb(&end);
    return 0;
}

static void register_window(void)
{
    s_cb_data cb = {0};
    cb.reason = cbStartOfSimulation;
    cb.cb_rtn = start_of_simulation;
    vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = { register_window, 0 };
