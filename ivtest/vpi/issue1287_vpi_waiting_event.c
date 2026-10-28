#include <string.h>
#include <vpi_user.h>
#ifndef vpiWaitingProcesses
#define vpiWaitingProcesses 734
#endif
#ifndef vpiProcess
#define vpiProcess 99
#endif

static PLI_INT32 probe(p_cb_data cb)
{
    vpiHandle event, iter, process;
    int count = 0;
    (void)cb;

    event = vpi_handle_by_name((PLI_BYTE8*)"top.ev", 0);
    iter = event ? vpi_iterate(vpiWaitingProcesses, event) : 0;
    while (iter && (process = vpi_scan(iter))) {
        if (vpi_get(vpiType, process) != vpiProcess) {
            vpi_printf("FAIL unexpected waiting handle type %d\n",
                       vpi_get(vpiType, process));
            vpi_control(vpiFinish, 1);
            return 0;
        }
        count++;
    }

    if (count != 1) {
        vpi_printf("FAIL expected 1 waiting process, got %d\n", count);
        vpi_control(vpiFinish, 1);
        return 0;
    }
    vpi_printf("WAITING=%d\nPASSED\n", count);
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
