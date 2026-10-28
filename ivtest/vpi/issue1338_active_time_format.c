#include <string.h>
#include <vpi_user.h>

#if !defined(vpiActiveTimeFormat) || vpiActiveTimeFormat != 119
#error "vpiActiveTimeFormat has an incorrect value"
#endif

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    (void)data;
    vpi_printf("ACTIVE TIME FORMAT CONSTANT PASSED\nPASSED\n");
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$probe_active_time_format";
    data.calltf = probe;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
