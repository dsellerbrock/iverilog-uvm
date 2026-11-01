#include <string.h>
#include <vpi_user.h>

/* vpiInstance is defined by IEEE 1800 Annex K but is absent from this header. */
#ifndef vpiInstance
#define vpiInstance 745
#endif

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    vpiHandle child = vpi_handle_by_name("issue889_vpi_instance.u", 0);
    vpiHandle instance = child ? vpi_handle(vpiInstance, child) : 0;
    vpiHandle scope = child ? vpi_handle(vpiScope, child) : 0;
    vpiHandle module = child ? vpi_handle(vpiModule, child) : 0;
    const char *instance_name = instance ? vpi_get_str(vpiFullName, instance) : 0;
    const char *scope_name = scope ? vpi_get_str(vpiFullName, scope) : 0;
    const char *module_name = module ? vpi_get_str(vpiFullName, module) : 0;

    (void)data;
    if (!instance_name || strcmp(instance_name, "issue889_vpi_instance") ||
        !scope_name || strcmp(scope_name, "issue889_vpi_instance") ||
        !module_name || strcmp(module_name, "issue889_vpi_instance")) {
        vpi_printf("vpiInstance FAILED: instance=%s scope=%s module=%s\n",
                   instance_name ? instance_name : "<null>",
                   scope_name ? scope_name : "<null>",
                   module_name ? module_name : "<null>");
        vpi_control(vpiFinish, 1);
        return 0;
    }

    vpi_printf("vpiInstance PASSED\nPASSED\n");
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data task;
    memset(&task, 0, sizeof task);
    task.type = vpiSysTask;
    task.tfname = "$probe_vpi_instance";
    task.calltf = probe;
    vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
