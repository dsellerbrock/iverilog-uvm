#include <string.h>
#include "vpi_user.h"

static int check(const char *name, int pure, int context, int qualifier,
                 const char *identifier)
{
    vpiHandle handle = vpi_handle_by_name((PLI_BYTE8 *)name, 0);
    int got_pure = handle ? vpi_get(vpiDPIPure, handle) : vpiUndefined;
    int got_context = handle ? vpi_get(vpiDPIContext, handle) : vpiUndefined;
    int got_qualifier = handle ? vpi_get(vpiDPICStr, handle) : vpiUndefined;
    char *got_identifier = handle ? vpi_get_str(vpiDPICIdentifier, handle) : 0;

    if (!handle || got_pure != pure || got_context != context ||
        got_qualifier != qualifier || !got_identifier ||
        strcmp(got_identifier, identifier) != 0) {
        vpi_printf("ISSUE1302_DPI_TF_PROPERTIES_FAIL %s present=%d pure=%d "
                   "context=%d qualifier=%d identifier=%s\n",
                   name, handle != 0, got_pure, got_context, got_qualifier,
                   got_identifier ? got_identifier : "<null>");
        return 0;
    }
    return 1;
}

static PLI_INT32 probe(p_cb_data cb)
{
    (void)cb;
    if (!check("top.p", 1, 0, vpiDPIC, "p") ||
        !check("top.c", 0, 1, vpiDPIC, "c") ||
        !check("top.alias_fn", 0, 0, vpiDPIC, "c_alias") ||
        !check("top.legacy_fn", 1, 0, vpiDPI, "c_legacy") ||
        !check("top.c_task", 0, 1, vpiDPIC, "c_task") ||
        !check("top.alias_task", 0, 0, vpiDPIC, "task_alias") ||
        !check("top.legacy_task", 0, 1, vpiDPI, "c_legacy_task") ||
        !check("top.e", 0, 0, vpiDPIC, "e") ||
        !check("top.legacy_export", 0, 0, vpiDPI, "c_legacy_export") ||
        !check("top.e_task", 0, 0, vpiDPIC, "e_task") ||
        !check("top.task_export", 0, 0, vpiDPIC, "c_task_export") ||
        !check("top.legacy_task_export", 0, 0, vpiDPI,
               "c_legacy_task_export")) {
        vpi_control(vpiFinish, 1);
        return 0;
    }

    vpi_printf("ISSUE1302_DPI_TF_PROPERTIES_PASSED\n");
    vpi_printf("PASSED\n");
    return 0;
}

static void startup(void)
{
    s_cb_data cb;
    memset(&cb, 0, sizeof cb);
    cb.reason = cbStartOfSimulation;
    cb.cb_rtn = probe;
    vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = { startup, 0 };
