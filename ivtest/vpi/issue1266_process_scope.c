#include <string.h>
#include <vpi_user.h>
#ifndef vpiProcess
#define vpiProcess 99
#endif

static PLI_INT32 probe(PLI_BYTE8 *ud)
{
    vpiHandle top, iter, process;
    int count = 0;
    (void)ud;

    top = vpi_handle_by_name((PLI_BYTE8*)"issue1266_vpi_process_scope", 0);
    iter = top ? vpi_iterate(vpiProcess, top) : 0;
    while (iter && (process = vpi_scan(iter))) {
        const char *name = vpi_get_str(vpiFullName, process);
        if (vpi_get(vpiType, process) != vpiProcess) {
            vpi_printf("FAIL unexpected process handle type %d\n",
                       vpi_get(vpiType, process));
            vpi_control(vpiFinish, 1);
            return 0;
        }
        if (!name || strcmp(name, "issue1266_vpi_process_scope") != 0) {
            vpi_printf("FAIL unexpected process full name %s\n",
                       name ? name : "(null)");
            vpi_control(vpiFinish, 1);
            return 0;
        }
        count++;
    }

    if (count != 2) {
        vpi_printf("FAIL expected 2 processes, got %d\n", count);
        vpi_control(vpiFinish, 1);
        return 0;
    }

    vpi_printf("PROCESS_COUNT=%d\nPASSED\n", count);
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$probe_process_scope";
    data.calltf = probe;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
