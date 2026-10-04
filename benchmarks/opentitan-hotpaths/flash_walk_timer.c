#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

#include "vpi_user.h"

static struct timespec phase_start;

static PLI_INT32 timer_start_calltf(PLI_BYTE8 *user_data)
{
    (void)user_data;
    clock_gettime(CLOCK_MONOTONIC, &phase_start);
    return 0;
}

static PLI_INT32 timer_report_calltf(PLI_BYTE8 *user_data)
{
    struct timespec now;
    const char *label = (const char *)user_data;
    clock_gettime(CLOCK_MONOTONIC, &now);
    const int64_t elapsed_ns =
        (int64_t)(now.tv_sec - phase_start.tv_sec) * INT64_C(1000000000)
        + (int64_t)now.tv_nsec - (int64_t)phase_start.tv_nsec;
    vpi_printf("PHASE %s elapsed_ns=%lld\n", label,
               (long long)elapsed_ns);
    phase_start = now;
    return 0;
}

static void register_task(const char *name, PLI_INT32 (*calltf)(PLI_BYTE8 *),
                          const char *label)
{
    s_vpi_systf_data task;
    memset(&task, 0, sizeof(task));
    task.type = vpiSysTask;
    task.tfname = (PLI_BYTE8 *)name;
    task.calltf = calltf;
    task.user_data = (PLI_BYTE8 *)label;
    vpi_register_systf(&task);
}

static void flash_walk_timer_register(void)
{
    register_task("$flash_timer_start", timer_start_calltf, NULL);
    register_task("$flash_timer_population_done", timer_report_calltf,
                  "populate");
    register_task("$flash_timer_walk_done", timer_report_calltf, "walk");
}

void (*vlog_startup_routines[])(void) = {
    flash_walk_timer_register,
    0
};
