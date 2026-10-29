#include <string.h>
#include <vpi_user.h>

#if !defined(vpiCase) || !defined(vpiCaseItem) || !defined(vpiCaseType) \
    || !defined(vpiCaseX) || !defined(vpiCaseZ) \
    || !defined(vpiAnyPattern) || !defined(vpiTaggedPattern) \
    || !defined(vpiStructPattern)
#error "VPI case and pattern constants are missing"
#endif

#if vpiCase != 5 || vpiCaseItem != 6 || vpiCaseType != 42 \
    || vpiCaseX != 2 || vpiCaseZ != 3 \
    || vpiAnyPattern != 667 || vpiTaggedPattern != 668 \
    || vpiStructPattern != 669
#error "VPI case and pattern constants have incorrect values"
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
    data.tfname = "$probe_case_pattern_constants";
    data.calltf = probe;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
