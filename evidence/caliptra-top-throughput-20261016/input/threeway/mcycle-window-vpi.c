#include <errno.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "vpi_user.h"

static vpiHandle mcycle;
static uint32_t window_start, window_end, observed_start, observed_end;
static struct timespec start_time;
static int started, finished;

static void read_cycle(uint32_t *cycle)
{
    s_vpi_value value = {0};
    value.format = vpiIntVal;
    vpi_get_value(mcycle, &value);
    *cycle = (uint32_t)value.value.integer;
}

static int read_limit(const char *name, uint32_t *limit)
{
    const char *text = getenv(name);
    char *end = NULL;
    unsigned long long value;
    if (!text || !*text)
        return 0;
    errno = 0;
    value = strtoull(text, &end, 10);
    if (errno || end == text || *end || value > UINT32_MAX)
        return 0;
    *limit = (uint32_t)value;
    return 1;
}

static PLI_INT32 on_mcycle(p_cb_data cb)
{
    struct timespec now;
    uint32_t cycle;
    (void)cb;
    read_cycle(&cycle);
    if (!started && cycle >= window_start) {
        if (clock_gettime(CLOCK_MONOTONIC, &start_time)) {
            vpi_printf("MCYCLE_WINDOW_ERROR clock_gettime start\n");
            vpi_control(vpiFinish, 0);
            return 0;
        }
        observed_start = cycle;
        started = 1;
    }
    if (started && cycle >= window_end) {
        uint64_t elapsed_ns, start_ns, end_ns;
        uint32_t cycles;
        if (clock_gettime(CLOCK_MONOTONIC, &now)) {
            vpi_printf("MCYCLE_WINDOW_ERROR clock_gettime end\n");
            vpi_control(vpiFinish, 0);
            return 0;
        }
        observed_end = cycle;
        cycles = observed_end - observed_start;
        start_ns = (uint64_t)start_time.tv_sec * UINT64_C(1000000000)
            + (uint64_t)start_time.tv_nsec;
        end_ns = (uint64_t)now.tv_sec * UINT64_C(1000000000)
            + (uint64_t)now.tv_nsec;
        elapsed_ns = end_ns - start_ns;
        vpi_printf("MCYCLE_WINDOW start=%" PRIu32 " end=%" PRIu32
                   " cycles=%" PRIu32 " elapsed_ns=%" PRIu64 "\n",
                   observed_start, observed_end, cycles, elapsed_ns);
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
        vpi_printf("MCYCLE_WINDOW_INCOMPLETE start_seen=%d\n", started);
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
        vpi_printf("MCYCLE_WINDOW_ERROR bind_or_limits\n");
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
