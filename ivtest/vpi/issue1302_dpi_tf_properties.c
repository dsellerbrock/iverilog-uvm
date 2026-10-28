#include <string.h>
#include <vpi_user.h>

static int check(const char *path, int pure, int context, int cstr,
                 const char *identifier)
{
    vpiHandle handle = vpi_handle_by_name((PLI_BYTE8 *)path, 0);
    int got_pure = handle ? vpi_get(vpiDPIPure, handle) : vpiUndefined;
    int got_context = handle ? vpi_get(vpiDPIContext, handle) : vpiUndefined;
    int got_cstr = handle ? vpi_get(vpiDPICStr, handle) : vpiUndefined;
    const char *got_identifier = handle
        ? vpi_get_str(vpiDPICIdentifier, handle) : 0;

    if (!handle || got_pure != pure || got_context != context
        || got_cstr != cstr || !got_identifier
        || strcmp(got_identifier, identifier) != 0) {
        vpi_printf("FAIL %s pure=%d context=%d cstr=%d identifier=%s\n",
                   path, got_pure, got_context, got_cstr,
                   got_identifier ? got_identifier : "<null>");
        return 0;
    }
    return 1;
}

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    (void)data;
    if (!check("top.p", 1, 0, vpiDPIC, "p")
        || !check("top.c_sv", 0, 1, vpiDPIC, "c")
        || !check("top.imported_task", 0, 1, vpiDPIC, "c_task")
        || !check("top.legacy_dpi", 0, 0, vpiDPI, "legacy_dpi")
        || !check("top.e", 0, 0, vpiDPIC, "e_c")
        || !check("top.exported_task", 0, 0, vpiDPIC, "e_task_c")) {
        vpi_control(vpiFinish, 1);
        return 0;
    }
    vpi_printf("PASSED\n");
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$probe_dpi_tf_properties";
    data.calltf = probe;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
