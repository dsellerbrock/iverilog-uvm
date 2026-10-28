#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

static PLI_INT32 check_class_typespec(p_cb_data data)
{
    vpiHandle var = vpi_handle_by_name((PLI_BYTE8*)"top.p", 0);
    vpiHandle type = var ? vpi_handle(vpiClassTypespec, var) : 0;
    const char *name = type ? vpi_get_str(vpiName, type) : 0;
    (void)data;

    if (!type || vpi_get(vpiType, type) != vpiClassTypespec ||
        !name || strcmp(name, "Packet") != 0) {
        vpi_printf("FAIL class typespec: type=%d name=%s\n",
                   type ? vpi_get(vpiType, type) : -1,
                   name ? name : "<null>");
        vpi_control(vpiFinish, 1);
        return 0;
    }

    vpi_printf("PASSED\n");
    vpi_control(vpiFinish, 0);
    return 0;
}

static void register_probe(void)
{
    static s_vpi_time time;
    s_cb_data cb;
    memset(&time, 0, sizeof time);
    time.type = vpiSimTime;
    time.low = 1;
    memset(&cb, 0, sizeof cb);
    cb.reason = cbAfterDelay;
    cb.cb_rtn = check_class_typespec;
    cb.time = &time;
    vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
