#include <vpi_user.h>

#ifndef vpiDoWhile
#error "vpiDoWhile is missing from vpi_user.h"
#endif
#ifndef vpiLoopVars
#error "vpiLoopVars is missing from vpi_user.h"
#endif
#ifndef vpiNullOp
#error "vpiNullOp is missing from vpi_user.h"
#endif
#if vpiDoWhile != 670
#error "vpiDoWhile has the wrong value"
#endif
#if vpiLoopVars != 737
#error "vpiLoopVars has the wrong value"
#endif
#if vpiNullOp != 36
#error "vpiNullOp has the wrong value"
#endif

static PLI_INT32 check_constants(PLI_BYTE8 *data)
{
    (void)data;
    vpi_printf("VPI LOOP ARRAY API CONSTANTS PASSED\nPASSED\n");
    return 0;
}

static void register_check(void)
{
    s_vpi_systf_data data;
    data.type = vpiSysTask;
    data.tfname = "$check_vpi_loop_array_api_constants";
    data.calltf = check_constants;
    data.compiletf = 0;
    data.sizetf = 0;
    data.user_data = 0;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_check, 0 };
