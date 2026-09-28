#include "vpi_user.h"
#include <stdio.h>

static PLI_INT32 changed(p_cb_data cb)
{
    static int count;
    s_vpi_value value = {.format = vpiBinStrVal};
    vpi_get_value(cb->obj, &value);
    printf("cb %d %s\n", ++count, value.value.str);
    return 0;
}

static PLI_INT32 watch_call(char *unused)
{
    vpiHandle args = vpi_iterate(vpiArgument, vpi_handle(vpiSysTfCall, 0));
    vpiHandle signal = vpi_scan(args);
    s_cb_data cb = {.reason = cbValueChange, .cb_rtn = changed, .obj = signal};
    vpi_register_cb(&cb);
    return 0;
}

static void register_watch(void)
{
    s_vpi_systf_data tf = {.type = vpiSysTask, .tfname = "$watch_nba",
                         .calltf = watch_call};
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {register_watch, 0};
