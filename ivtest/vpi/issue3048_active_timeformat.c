#include <string.h>
#include <vpi_user.h>

static vpiHandle first, second;
static int step;

static PLI_INT32 check(PLI_BYTE8 *unused)
{
    vpiHandle h = vpi_handle(vpiActiveTimeFormat, 0);
    vpiHandle args, arg;
    s_vpi_value value;
    int ok = 1;
    (void)unused;
    ++step;
    if (step == 1) ok = h == 0;
    else if (!h || vpi_get(vpiType, h) != vpiSysTaskCall ||
             strcmp(vpi_get_str(vpiName, h), "$timeformat")) ok = 0;
    else {
        if (step == 2) first = h;
        if (step == 3) { second = h; ok = h != first; }
        if (step == 4) ok = h == first;
        if (step == 5) ok = h != first && h != second;
        args = vpi_iterate(vpiArgument, h);
        if (step == 5) ok = ok && !args;
        else if (!args) ok = 0;
        else {
            arg = vpi_scan(args);
            value.format = vpiIntVal;
            vpi_get_value(arg, &value);
            ok = ok && value.value.integer == (step == 3 ? -6 : -9);
            vpi_free_object(args);
        }
    }
    if (!ok) vpi_printf("FAIL step %d\n", step);
    if (step == 5 && ok) vpi_printf("PASS active timeformat\n");
    return 0;
}

static void start(void)
{
    s_vpi_systf_data data = {0};
    data.type = vpiSysTask;
    data.tfname = "$check_timeformat";
    data.calltf = check;
    vpi_register_systf(&data);
}
void (*vlog_startup_routines[])(void) = {start, 0};
