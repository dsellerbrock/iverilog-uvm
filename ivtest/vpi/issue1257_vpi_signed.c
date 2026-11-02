#include <vpi_user.h>

static PLI_INT32 signed_sizetf(ICARUS_VPI_CONST PLI_BYTE8 *name)
{
    (void)name;
    return 7;
}

static PLI_INT32 signed_calltf(ICARUS_VPI_CONST PLI_BYTE8 *name)
{
    vpiHandle call;
    s_vpi_value value = {0};
    (void)name;

    call = vpi_handle(vpiSysTfCall, 0);
    value.format = vpiIntVal;
    value.value.integer = 0x55;
    vpi_put_value(call, &value, 0, vpiNoDelay);
    return 0;
}

static void register_signed(void)
{
    s_vpi_systf_data tf = {0};
    tf.type = vpiSysFunc;
    tf.sysfunctype = vpiSizedFunc;
    tf.tfname = "$signed";
    tf.calltf = signed_calltf;
    tf.sizetf = signed_sizetf;
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {register_signed, 0};
