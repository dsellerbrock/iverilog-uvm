#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

static PLI_INT32 probe_program_index(PLI_BYTE8 *data)
{
    vpiHandle call, top, iter, program;
    int found = 0;
    (void)data;

    call = vpi_handle(vpiSysTfCall, 0);
    top = call ? vpi_handle(vpiScope, call) : 0;
    iter = top ? vpi_iterate(vpiProgram, top) : 0;
    while (iter && (program = vpi_scan(iter))) {
        const char *name = vpi_get_str(vpiFullName, program);
        vpiHandle index = vpi_handle(vpiIndex, program);
        int expected;

        if (name && strcmp(name, "issue1263_vpi_program_index.prog[0]") == 0)
            expected = 0;
        else if (name && strcmp(name, "issue1263_vpi_program_index.prog[1]") == 0)
            expected = 1;
        else if (name && strcmp(name, "issue1263_vpi_program_index.scalar") == 0) {
            if (index || vpi_get(vpiIndex, program) != vpiUndefined) {
                vpi_printf("FAIL scalar program exposed an array index\n");
                vpi_control(vpiFinish, 1);
                return 0;
            }
            found++;
            continue;
        } else {
            vpi_printf("FAIL unexpected program %s\n", name ? name : "?");
            vpi_control(vpiFinish, 1);
            return 0;
        }

        if (!index || vpi_get(vpiIndex, program) != expected) {
            vpi_printf("FAIL %s handle=%s get=%d\n", name,
                       index ? "present" : "NULL", vpi_get(vpiIndex, program));
            vpi_control(vpiFinish, 1);
            return 0;
        }

        {
            s_vpi_value value;
            value.format = vpiIntVal;
            vpi_get_value(index, &value);
            if (value.value.integer != expected) {
                vpi_printf("FAIL %s transition value=%d\n", name,
                           value.value.integer);
                vpi_control(vpiFinish, 1);
                return 0;
            }
        }
        found++;
    }

    if (found != 3) {
        vpi_printf("FAIL found %d program instances\n", found);
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
    data.tfname = "$probe_program_index";
    data.calltf = probe_program_index;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
