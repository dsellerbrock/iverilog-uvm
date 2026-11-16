#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

static int check(const char *path, const char *expected)
{
    vpiHandle var = vpi_handle_by_name((PLI_BYTE8 *)path, 0);
    vpiHandle type = var ? vpi_handle(vpiTypespec, var) : 0;
    const char *name = type ? vpi_get_str(vpiName, type) : 0;
    if (!var || vpi_get(vpiType, var) != vpiClassVar || !type ||
        vpi_get(vpiType, type) != vpiClassTypespec ||
        !name || strcmp(name, expected)) {
        vpi_printf("FAIL %s: typespec=%d name=%s\n", path,
                   type ? vpi_get(vpiType, type) : -1, name ? name : "<null>");
        return 0;
    }
    return 1;
}

static PLI_INT32 probe(p_cb_data cb)
{
    int ok;
    (void)cb;
    ok = check("top.empty", "Base");
    ok &= check("top.obj", "Base");
    ok &= check("top.derived", "Derived");
    if (ok) vpi_printf("PASSED\n");
    return 0;
}

static void startup(void)
{
    static s_vpi_time time = {vpiSimTime, 0, 1, 0};
    s_cb_data cb;
    memset(&cb, 0, sizeof cb);
    cb.reason = cbAfterDelay;
    cb.cb_rtn = probe;
    cb.time = &time;
    vpi_register_cb(&cb);
}
void (*vlog_startup_routines[])(void) = {startup, 0};
