#include <vpi_user.h>
#include <stdio.h>
#include <string.h>

static PLI_INT32 on_change(p_cb_data cb)
{
    s_vpi_value value;
    s_vpi_time time;
    memset(&value, 0, sizeof value);
    memset(&time, 0, sizeof time);
    value.format = vpiBinStrVal;
    time.type = vpiSimTime;
    vpi_get_value(cb->obj, &value);
    vpi_get_time(cb->obj, &time);
    vpi_printf("CB time=%u x=%s\n", time.low, value.value.str);
    return 0;
}

static PLI_INT32 on_start(p_cb_data unused)
{
    (void)unused;
    vpiHandle x = vpi_handle_by_name((PLI_BYTE8*)"tb.x", 0);
    if (!x) {
        vpi_printf("ERROR: missing tb.x\n");
        return 0;
    }
    s_cb_data cb;
    memset(&cb, 0, sizeof cb);
    cb.reason = cbValueChange;
    cb.cb_rtn = on_change;
    cb.obj = x;
    vpi_register_cb(&cb);
    return 0;
}

static void register_callbacks(void)
{
    s_cb_data cb;
    memset(&cb, 0, sizeof cb);
    cb.reason = cbStartOfSimulation;
    cb.cb_rtn = on_start;
    vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = { register_callbacks, 0 };
