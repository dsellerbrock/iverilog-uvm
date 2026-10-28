#include <string.h>
#include <vpi_user.h>

/* Keep the regression runnable against headers that predate these VPI IDs. */
#ifndef vpiVisibility
#define vpiVisibility 620
#define vpiPublicVis 1
#endif

static int check_visibility(const char *path)
{
    vpiHandle handle = vpi_handle_by_name((PLI_BYTE8 *)path, 0);
    int got = handle ? vpi_get(vpiVisibility, handle) : vpiUndefined;
    if (got != vpiPublicVis) {
        vpi_printf("FAIL %s visibility=%d\n", path, got);
        return 0;
    }
    return 1;
}

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    (void)data;
    if (!check_visibility("top.f") || !check_visibility("top.t")) {
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
    data.tfname = "$probe_visibility";
    data.calltf = probe;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
