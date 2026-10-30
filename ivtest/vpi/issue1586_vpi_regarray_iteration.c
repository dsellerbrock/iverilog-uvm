#include <string.h>
#include <vpi_user.h>

static PLI_INT32 probe_regarray_iteration(PLI_BYTE8 *data)
{
    static const char *const expected[] = { "ia", "ta", "ra" };
    unsigned count = 0, found = 0;
    vpiHandle top, iter, item;
    (void)data;

    top = vpi_handle_by_name((PLI_BYTE8*)"top", 0);
    iter = top ? vpi_iterate(vpiRegArray, top) : 0;
    while (iter && (item = vpi_scan(iter))) {
        const char *name = vpi_get_str(vpiName, item);
        unsigned idx;
        int match = 0;
        ++count;
        for (idx = 0; idx < sizeof expected / sizeof expected[0]; ++idx) {
            if (name && strcmp(name, expected[idx]) == 0) {
                match = 1;
                found |= 1u << idx;
                break;
            }
        }
        if (!match) {
            vpi_printf("FAIL unexpected vpiRegArray item %s\n",
                       name ? name : "?");
            vpi_control(vpiFinish, 1);
            return 0;
        }
    }

    if (count != 3 || found != 7) {
        vpi_printf("FAIL vpiRegArray iteration count=%u mask=%u expected=3/7\n",
                   count, found);
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
    data.tfname = "$probe_regarray_iteration";
    data.calltf = probe_regarray_iteration;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
