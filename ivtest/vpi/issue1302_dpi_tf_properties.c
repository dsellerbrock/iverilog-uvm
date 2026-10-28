#include <vpi_user.h>
#include <string.h>

static int check(const char *name, int pure, int context, int qualifier,
                 const char *identifier)
{
    vpiHandle h = vpi_handle_by_name((PLI_BYTE8 *)name, 0);
    const char *got_identifier = h ? vpi_get_str(vpiDPICIdentifier, h) : 0;
    if (!h || vpi_get(vpiDPIPure, h) != pure
        || vpi_get(vpiDPIContext, h) != context
        || vpi_get(vpiDPICStr, h) != qualifier
        || !got_identifier || strcmp(got_identifier, identifier) != 0) {
        vpi_printf("FAIL %s present=%d pure=%d context=%d qualifier=%d identifier=%s\n",
                   name, h != 0, h ? vpi_get(vpiDPIPure, h) : -1,
                   h ? vpi_get(vpiDPIContext, h) : -1,
                   h ? vpi_get(vpiDPICStr, h) : -1,
                   got_identifier ? got_identifier : "<null>");
        return 0;
    }
    return 1;
}

static PLI_INT32 probe(p_cb_data cb)
{
    (void)cb;
    if (!check("top.p", 1, 0, vpiDPIC, "p_c")
        || !check("top.c", 0, 1, vpiDPIC, "c_c")
        || !check("top.d", 0, 0, vpiDPI, "d")
        || !check("top.e", 0, 0, vpiDPIC, "e")) {
        vpi_control(vpiFinish, 1);
        return 0;
    }
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
