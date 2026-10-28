#include <vpi_user.h>

#if vpiAlwaysType != 624
#error "vpiAlwaysType has the wrong value"
#endif
#if vpiAlwaysComb != 2
#error "vpiAlwaysComb has the wrong value"
#endif
#if vpiAlwaysFF != 3
#error "vpiAlwaysFF has the wrong value"
#endif
#if vpiAlwaysLatch != 4
#error "vpiAlwaysLatch has the wrong value"
#endif

static PLI_INT32 check_constants(PLI_BYTE8 *data)
{
    (void)data;
    vpi_printf("VPI ALWAYS TYPE CONSTANTS PASSED\nPASSED\n");
    return 0;
}

static void register_check(void)
{
    s_vpi_systf_data data;
    data.type = vpiSysTask;
    data.tfname = "$check_vpi_always_type_constants";
    data.calltf = check_constants;
    data.compiletf = 0;
    data.sizetf = 0;
    data.user_data = 0;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_check, 0 };
