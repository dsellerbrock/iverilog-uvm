#include <vpi_user.h>

static PLI_INT32 answer_calltf(PLI_BYTE8 *data)
{
    vpiHandle call;
    s_vpi_value set = {0}, got = {0};
    (void)data;

    call = vpi_handle(vpiSysTfCall, 0);
    set.format = vpiIntVal;
    set.value.integer = 42;
    vpi_put_value(call, &set, 0, vpiNoDelay);

    got.format = vpiIntVal;
    vpi_get_value(call, &got);
    vpi_printf("SYSFUNC_VPI_VALUE=%d\n", got.value.integer);
    return 0;
}

static void register_answer(void)
{
    s_vpi_systf_data tf = {0};
    tf.type = vpiSysFunc;
    tf.sysfunctype = vpiSysFuncInt;
    tf.tfname = "$answer";
    tf.calltf = answer_calltf;
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {register_answer, 0};
