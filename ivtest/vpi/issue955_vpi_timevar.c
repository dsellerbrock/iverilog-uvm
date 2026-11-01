#include <string.h>
#include <vpi_user.h>

static PLI_INT32 check_types(p_cb_data data)
{
    vpiHandle time_var = vpi_handle_by_name((PLI_BYTE8*)"top.tt", 0);
    vpiHandle integer_var = vpi_handle_by_name((PLI_BYTE8*)"top.ii", 0);
    vpiHandle reg_var = vpi_handle_by_name((PLI_BYTE8*)"top.rr", 0);
    int time_type = time_var ? vpi_get(vpiType, time_var) : -1;
    int integer_type = integer_var ? vpi_get(vpiType, integer_var) : -1;
    int reg_type = reg_var ? vpi_get(vpiType, reg_var) : -1;
    (void)data;

    if (time_type != vpiTimeVar || integer_type != vpiIntegerVar ||
        reg_type != vpiReg) {
        vpi_printf("FAIL time=%d integer=%d reg=%d\n", time_type,
                   integer_type, reg_type);
        vpi_control(vpiFinish, 1);
        return 0;
    }

    vpi_printf("PASSED\n");
    vpi_control(vpiFinish, 0);
    return 0;
}

static void register_probe(void)
{
    s_cb_data cb;
    memset(&cb, 0, sizeof cb);
    cb.reason = cbStartOfSimulation;
    cb.cb_rtn = check_types;
    vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
