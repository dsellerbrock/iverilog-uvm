#include <vpi_user.h>

#ifndef vpiPrefix
#error "vpiPrefix is missing from vpi_user.h"
#endif
#ifndef vpiHasActual
#error "vpiHasActual is missing from vpi_user.h"
#endif
#if vpiPrefix != 714
#error "vpiPrefix has the wrong value"
#endif
#if vpiHasActual != 636
#error "vpiHasActual has the wrong value"
#endif

static PLI_INT32 check_constants(PLI_BYTE8 *data)
{
    (void)data;
    vpi_printf("VPI PREFIX CONSTANTS PASSED\nPASSED\n");
    return 0;
}

static void register_check(void)
{
    s_vpi_systf_data data;
    data.type = vpiSysTask;
    data.tfname = "$check_vpi_prefix_constants";
    data.calltf = check_constants;
    data.compiletf = 0;
    data.sizetf = 0;
    data.user_data = 0;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_check, 0 };
