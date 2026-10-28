#include <string.h>
#include <vpi_user.h>

static PLI_INT32 probe_port_widths(PLI_BYTE8 *data)
{
    static const struct {
        const char *name;
        int scalar;
        int vector;
    } expected[] = {
        { "a", 1, 0 },
        { "y", 0, 1 },
        { "one", 1, 0 },
        { "z", 0, 1 }
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
                int scalar = vpi_get(vpiScalar, port);
                int vector = vpi_get(vpiVector, port);
                if (scalar != expected[idx].scalar ||
                    vector != expected[idx].vector) {
                    vpi_printf("FAIL %s scalar=%d vector=%d\n", name,
                               scalar, vector);
                    vpi_control(vpiFinish, 1);
                    return 0;
                }
                found++;
                break;
            }
        }
    }
    if (found != sizeof(expected) / sizeof(expected[0])) {
        vpi_printf("FAIL found %u of %u packed ports\n", found,
                   (unsigned)(sizeof(expected) / sizeof(expected[0])));
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
    data.tfname = "$probe_port_widths";
    data.calltf = probe_port_widths;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
