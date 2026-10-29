#include <string.h>
#include <vpi_user.h>

#if !defined(vpiIteratorType) || vpiIteratorType != 57
#error "vpiIteratorType has an incorrect value"
#endif

static PLI_INT32 check_constant(PLI_BYTE8 *data)
{
    (void)data;
    vpi_printf("VPI ITERATOR TYPE CONSTANT PASSED\nPASSED\n");
    return 0;
}

static void register_check(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$check_vpi_iterator_type";
    data.calltf = check_constant;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_check, 0 };
