#include <string.h>
#include <vpi_user.h>
#ifndef vpiPortType
#define vpiPortType 611
#endif
static PLI_INT32 probe_port_type(PLI_BYTE8 *data)
{
    static const struct { const char *name; int type; } expected[] = {
        { "a", 44 }, { "y", 44 }, { "p", 1 }, { "q", 2 },
        { "one", 44 }, { "z", 44 }
    };
    vpiHandle scope, iter, port;
    unsigned found = 0;
    (void)data;
    scope = vpi_handle_by_name((PLI_BYTE8*)"top.u", 0);
    iter = scope ? vpi_iterate(vpiPort, scope) : 0;
    while (iter && (port = vpi_scan(iter))) {
        const char *name = vpi_get_str(vpiName, port);
        unsigned idx;
        for (idx = 0; idx < sizeof(expected) / sizeof(expected[0]); idx++) {
            if (name && strcmp(name, expected[idx].name) == 0) {
                int type = vpi_get(vpiPortType, port);
                if (type != expected[idx].type) {
                    vpi_printf("FAIL %s port type=%d expected=%d\n", name, type, expected[idx].type);
                    vpi_control(vpiFinish, 1);
                    return 0;
                }
                found++;
                break;
            }
        }
    }
    if (found != sizeof(expected) / sizeof(expected[0])) {
        vpi_printf("FAIL found %u of %u ports\n", found, (unsigned)(sizeof(expected) / sizeof(expected[0])));
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
    data.tfname = "$probe_port_type";
    data.calltf = probe_port_type;
    vpi_register_systf(&data);
}
void (*vlog_startup_routines[])(void) = { register_probe, 0 };
