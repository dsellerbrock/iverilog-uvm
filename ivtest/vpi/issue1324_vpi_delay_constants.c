#include <string.h>
#include <vpi_user.h>

#if !defined(vpiDelayControl) || !defined(vpiDelay) \
    || vpiDelayControl != 11 || vpiDelay != 72
#error "VPI delay constants have incorrect values"
#endif

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    (void)data;
    vpi_printf("PASSED\n");
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$probe_delay_constants";
    data.calltf = probe;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
