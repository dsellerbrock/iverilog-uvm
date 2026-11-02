#include <vpi_user.h>

static PLI_INT32 signed_sizetf(PLI_BYTE8 *data)
{
    (void)data;
    return 7;
}

static PLI_INT32 signed_calltf(PLI_BYTE8 *data)
{
    vpiHandle call = vpi_handle(vpiSysTfCall, 0);
    s_vpi_value value = {0};
    s_vpi_vecval result = {0x55, 0};
    (void)data;

    value.format = vpiVectorVal;
    value.value.vector = &result;
    vpi_put_value(call, &value, 0, vpiNoDelay);
    vpi_printf("VPI_SIGNED_SIZE=%d\n", vpi_get(vpiSize, call));
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
