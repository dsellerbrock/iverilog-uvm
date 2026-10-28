#include <string.h>
#include <vpi_user.h>
#include "sv_vpi_user.h"

#define vpiReturn 666

static PLI_INT32 probe(p_cb_data cb)
{
    vpiHandle function, result;
    (void)cb;

    function = vpi_handle_by_name((PLI_BYTE8*)"top.f", 0);
    result = function ? vpi_handle(vpiReturn, function) : 0;
    if (!function || !result || vpi_get(vpiType, result) != vpiBitVar ||
        strcmp(vpi_get_str(vpiName, result), "f") != 0 ||
        vpi_get(vpiSize, result) != 32 || !vpi_get(vpiSigned, result)) {
        vpi_printf("ISSUE1301_FUNCTION_RETURN_FAIL function=%d return=%d type=%d size=%d signed=%d name=%s\n",
                   function != 0, result != 0,
                   result ? vpi_get(vpiType, result) : -1,
                   result ? vpi_get(vpiSize, result) : -1,
                   result ? vpi_get(vpiSigned, result) : -1,
                   result ? vpi_get_str(vpiName, result) : "<null>");
        vpi_control(vpiFinish, 1);
        return 0;
    }

    vpi_printf("ISSUE1301_FUNCTION_RETURN_PASSED\n");
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
