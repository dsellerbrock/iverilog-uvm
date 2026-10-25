#include <vpi_user.h>
#include <string.h>
static PLI_INT32 calltf(PLI_BYTE8 *data)
{
    (void)data;
    vpiHandle call = vpi_handle(vpiSysTfCall, 0);
    vpiHandle iter = vpi_iterate(vpiArgument, call);
    vpiHandle obj = vpi_scan(iter);
    s_vpi_value val = { .format = vpiIntVal };
    s_vpi_time t = { .type = vpiScaledRealTime };
    vpiHandle h;
    int value, flag;
    h = vpi_scan(iter);
    vpi_get_value(h, &val);
    value = val.value.integer;
    h = vpi_scan(iter);
    vpi_get_value(h, &val);
    t.real = val.value.integer;
    h = vpi_scan(iter);
    vpi_get_value(h, &val);
    flag = val.value.integer;
    val.value.integer = value;
    vpi_put_value(obj, &val, &t, flag);
    return 0;
}

static void reg(void)
{
    s_vpi_systf_data d;

    memset(&d, 0, sizeof d);
    d.type = vpiSysTask;
    d.tfname = "$sched";
    d.calltf = calltf;
    vpi_register_systf(&d);
}
void (*vlog_startup_routines[])(void) = { reg, 0 };
