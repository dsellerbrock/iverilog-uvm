#include <vpi_user.h>

#ifndef vpiForever
#error "vpiForever is missing from vpi_user.h"
#endif
#if vpiForever != 17
#error "vpiForever has the wrong value"
#endif

static PLI_INT32 check_vpi_forever(PLI_BYTE8 *data)
{
    (void)data;
    vpi_printf("VPI FOREVER CONSTANT PASSED\nPASSED\n");
    return 0;
}

static void register_check(void)
{
    s_vpi_systf_data data;
    data.type = vpiSysTask;
    data.tfname = "$check_vpi_forever";
    data.calltf = check_vpi_forever;
    data.compiletf = 0;
    data.sizetf = 0;
    data.user_data = 0;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_check, 0 };
