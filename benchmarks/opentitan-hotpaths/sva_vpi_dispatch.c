#include "vpi_user.h"

#include <stdint.h>
#include <stdio.h>

static vpiHandle watched;
static uint64_t callback_count;
static uint64_t name_lookups;
static uint64_t value_gets;
static uint64_t callback_errors;

static PLI_INT32 on_value_change(p_cb_data cb)
{
    (void)cb;
    ++callback_count;
    vpiHandle signal = vpi_handle_by_name("top.signal", NULL);
    ++name_lookups;
    if (!signal) {
        ++callback_errors;
        return 0;
    }
    s_vpi_value value = { .format = vpiIntVal };
    vpi_get_value(signal, &value);
    ++value_gets;
    if ((value.value.integer != 0 && value.value.integer != 1) ||
        value.value.integer != (int)(callback_count & 1U))
        ++callback_errors;
    return 0;
}

static PLI_INT32 install_callback_calltf(PLI_BYTE8* user_data)
{
    (void)user_data;
    watched = vpi_handle_by_name("top.signal", NULL);
    if (!watched) {
        vpi_printf("FAIL cannot resolve top.signal\n");
        vpi_control(vpiFinish, 1);
        return 0;
    }
    s_cb_data cb = { .reason = cbValueChange, .cb_rtn = on_value_change,
                     .obj = watched };
    if (!vpi_register_cb(&cb)) {
        vpi_printf("FAIL cannot register cbValueChange\n");
        vpi_control(vpiFinish, 1);
    }
    return 0;
}

static PLI_INT32 report_callback_calltf(PLI_BYTE8* user_data)
{
    (void)user_data;
    vpiHandle call = vpi_handle(vpiSysTfCall, NULL);
    vpiHandle args = vpi_iterate(vpiArgument, call);
    vpiHandle arg = args ? vpi_scan(args) : NULL;
    s_vpi_value value = { .format = vpiIntVal };
    if (arg)
        vpi_get_value(arg, &value);
    const uint64_t expected = arg ? (uint64_t)value.value.integer : UINT64_MAX;
    if (callback_count != expected || name_lookups != expected ||
        value_gets != expected || callback_errors) {
        vpi_printf("FAIL callback_count=%llu expected=%llu lookups=%llu gets=%llu errors=%llu\n",
                   (unsigned long long)callback_count,
                   (unsigned long long)expected,
                   (unsigned long long)name_lookups,
                   (unsigned long long)value_gets,
                   (unsigned long long)callback_errors);
        vpi_control(vpiFinish, 1);
        return 0;
    }
    vpi_printf("PASS vpi_callbacks events=%llu per_event_name_lookups=%llu value_gets=%llu errors=0\n",
               (unsigned long long)callback_count,
               (unsigned long long)name_lookups,
               (unsigned long long)value_gets);
    return 0;
}

static void register_tasks(void)
{
    s_vpi_systf_data tf = { .type = vpiSysTask, .tfname = "$install_sva_vpi_callback",
                            .calltf = install_callback_calltf };
    vpi_register_systf(&tf);
    tf.tfname = "$report_sva_vpi_callbacks";
    tf.calltf = report_callback_calltf;
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
