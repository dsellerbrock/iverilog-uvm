#include <vpi_user.h>

#ifndef vpiIf
#error "vpiIf is missing from vpi_user.h"
#endif
#ifndef vpiIfElse
#error "vpiIfElse is missing from vpi_user.h"
#endif
#ifndef vpiQualifier
#error "vpiQualifier is missing from vpi_user.h"
#endif
#ifndef vpiUniqueQualifier
#error "vpiUniqueQualifier is missing from vpi_user.h"
#endif
#ifndef vpiPriorityQualifier
#error "vpiPriorityQualifier is missing from vpi_user.h"
#endif
#if vpiIf != 22
#error "vpiIf has the wrong value"
#endif
#if vpiIfElse != 23
#error "vpiIfElse has the wrong value"
#endif
#if vpiQualifier != 650
#error "vpiQualifier has the wrong value"
#endif
#if vpiUniqueQualifier != 1
#error "vpiUniqueQualifier has the wrong value"
#endif
#if vpiPriorityQualifier != 2
#error "vpiPriorityQualifier has the wrong value"
#endif

static PLI_INT32 check_constants(PLI_BYTE8 *data)
{
    (void)data;
    vpi_printf("VPI IF QUALIFIER CONSTANTS PASSED\nPASSED\n");
    return 0;
}

static void register_check(void)
{
    s_vpi_systf_data data;
    data.type = vpiSysTask;
    data.tfname = "$check_vpi_if_qualifier_constants";
    data.calltf = check_constants;
    data.compiletf = 0;
    data.sizetf = 0;
    data.user_data = 0;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_check, 0 };
