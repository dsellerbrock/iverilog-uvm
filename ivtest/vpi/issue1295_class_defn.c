#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

static PLI_INT32 check_class_defn(p_cb_data data)
{
    vpiHandle typespec = vpi_handle_by_name((PLI_BYTE8*)"top.C", 0);
    vpiHandle defn = typespec ? vpi_handle(vpiClassDefn, typespec) : 0;
    const char *name = defn ? vpi_get_str(vpiName, defn) : 0;
    (void)data;

    if (!typespec || vpi_get(vpiType, typespec) != vpiClassTypespec ||
        !defn || vpi_get(vpiType, defn) != vpiClassDefn ||
        !name || strcmp(name, "C") != 0) {
        vpi_printf("FAIL class defn: defn=%d name=%s\n",
                   defn ? vpi_get(vpiType, defn) : -1,
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
    s_cb_data cb;
    memset(&cb, 0, sizeof cb);
    cb.reason = cbStartOfSimulation;
    cb.cb_rtn = check_class_defn;
    vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
