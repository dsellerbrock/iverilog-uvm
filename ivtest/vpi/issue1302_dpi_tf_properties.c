#include <string.h>
#include <vpi_user.h>

static int check(const char *path, int pure, int context, const char *c_name)
{
    vpiHandle handle = vpi_handle_by_name((PLI_BYTE8 *)path, 0);
    int got_pure = handle ? vpi_get(vpiDPIPure, handle) : vpiUndefined;
    int got_context = handle ? vpi_get(vpiDPIContext, handle) : vpiUndefined;
    int got_cstr = handle ? vpi_get(vpiDPICStr, handle) : vpiUndefined;
    const char *got_name = handle ? vpi_get_str(vpiDPICIdentifier, handle) : 0;
    if (!handle || got_pure != pure || got_context != context
        || got_cstr != vpiDPIC || !got_name || strcmp(got_name, c_name)) {
        vpi_printf("FAIL %s pure=%d context=%d cstr=%d identifier=%s\n",
                   path, got_pure, got_context, got_cstr,
                   got_name ? got_name : "<null>");
        return 0;
    }
    return 1;
}

static PLI_INT32 probe(p_cb_data data)
{
    (void)data;
    if (!check("top.dpi_pure", 1, 0, "dpi_pure")
        || !check("top.dpi_context", 0, 1, "dpi_context_c")
        || !check("top.dpi_task", 0, 1, "dpi_task_c")
        || !check("top.dpi_export", 0, 0, "dpi_export_c")
        || !check("top.dpi_export_task", 0, 0, "dpi_export_task_c")) {
        vpi_control(vpiFinish, 1);
        return 0;
    }
    vpi_printf("PASSED\n");
    return 0;
}

static void register_probe(void)
{
    s_cb_data data;
    memset(&data, 0, sizeof data);
    data.reason = cbStartOfSimulation;
    data.cb_rtn = probe;
    vpi_register_cb(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
