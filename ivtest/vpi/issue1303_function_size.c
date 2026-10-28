#include <vpi_user.h>

static PLI_INT32 probe(p_cb_data cb)
{
    vpiHandle function;
    (void)cb;

    function = vpi_handle_by_name((PLI_BYTE8*)"top.f", 0);
    if (!function || vpi_get(vpiSize, function) != 32 ||
        vpi_get(vpiFuncType, function) != vpiSizedSignedFunc) {
        vpi_printf("ISSUE1303_FUNCTION_SIZE_FAIL function=%d size=%d type=%d\n",
                   function != 0,
                   function ? vpi_get(vpiSize, function) : -1,
                   function ? vpi_get(vpiFuncType, function) : -1);
        vpi_control(vpiFinish, 1);
        return 0;
    }

    vpi_printf("ISSUE1303_FUNCTION_SIZE_PASSED\nPASSED\n");
    return 0;
}

static void startup(void)
{
    s_cb_data cb = {0};
    cb.reason = cbStartOfSimulation;
    cb.cb_rtn = probe;
    vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = { startup, 0 };
