#include <vpi_user.h>
#include <string.h>
#ifndef vpiJoinType
#define vpiJoinType 603
#endif
#ifndef vpiJoin
#define vpiJoin 0
#endif

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    vpiHandle top, iter, scope;
    int found = 0;
    (void)data;
    top = vpi_handle_by_name((PLI_BYTE8*)"issue1265_vpi_join_type", 0);
    iter = top ? vpi_iterate(vpiNamedFork, top) : 0;
    while (iter && (scope = vpi_scan(iter))) {
        const char *name = vpi_get_str(vpiName, scope);
        int want = name && strcmp(name, "f1") == 0 ? vpiJoin
                : name && strcmp(name, "f2") == 0 ? 2
                : name && strcmp(name, "f3") == 0 ? 1 : -1;
        if (want < 0 || vpi_get(vpiJoinType, scope) != want) {
            vpi_printf("FAIL %s %d\n", name ? name : "?",
                       vpi_get(vpiJoinType, scope));
            vpi_control(vpiFinish, 1);
            return 0;
        }
        found++;
    }
    if (found != 3) {
        vpi_printf("FAIL found %d fork scopes\n", found);
        vpi_control(vpiFinish, 1);
        return 0;
    }
    vpi_printf("PASSED\n");
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$probe_join_type";
    data.calltf = probe;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
