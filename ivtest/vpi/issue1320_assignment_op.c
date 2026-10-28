#include <vpi_user.h>
#include <string.h>

#if !defined(vpiOpType)
#error "vpiOpType is missing"
#elif vpiOpType != 39
#error "vpiOpType has the wrong value"
#endif

#if !defined(vpiAssignmentOp)
#error "vpiAssignmentOp is missing"
#elif vpiAssignmentOp != 82
#error "vpiAssignmentOp has the wrong value"
#endif

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    (void)data;
    vpi_printf("PASSED\n");
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$probe_assignment_op";
    data.calltf = probe;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
