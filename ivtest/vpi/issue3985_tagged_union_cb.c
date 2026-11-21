#include <vpi_user.h>

static vpiHandle watch;

static PLI_INT32 changed(p_cb_data cb)
{
    vpi_printf("callback at %u\n", (unsigned)cb->time->low);
    return 0;
}

static PLI_INT32 start(ICARUS_VPI_CONST PLI_BYTE8 *unused)
{
    s_vpi_time time = {.type = vpiSimTime};
    s_vpi_value value = {.format = vpiSuppressVal};
    s_cb_data cb = {.reason = cbValueChange, .cb_rtn = changed,
                    .obj = vpi_handle_by_name("top.value", 0),
                    .time = &time, .value = &value};
    (void)unused;

    if (cb.obj)
        watch = vpi_register_cb(&cb);
    if (!watch)
        vpi_printf("callback registration failed\n");
    return 0;
}

static PLI_INT32 stop(ICARUS_VPI_CONST PLI_BYTE8 *unused)
{
    (void)unused;
    if (watch && vpi_remove_cb(watch))
        vpi_printf("callback removed\n");
    else
        vpi_printf("callback removal failed\n");
    watch = 0;
    return 0;
}

static void register_tasks(void)
{
    s_vpi_systf_data task = {.type = vpiSysTask, .tfname = "$watch_tagged_union",
                            .calltf = start};
    vpi_register_systf(&task);
    task.tfname = "$unwatch_tagged_union";
    task.calltf = stop;
    vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = {register_tasks, 0};
