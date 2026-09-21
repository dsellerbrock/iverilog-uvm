#include <vpi_user.h>
#include <stdio.h>
#include <string.h>

static PLI_INT32 check_calltf(PLI_BYTE8 *name)
{
    vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
    vpiHandle argv = vpi_iterate(vpiArgument, callh);
    vpiHandle arg;
    s_vpi_value value;
    int expected = -1;
    int found = 0;
    int count = -1;
    (void)name;

    if (argv && (arg = vpi_scan(argv))) {
        value.format = vpiIntVal;
        vpi_get_value(arg, &value);
        expected = value.value.integer;
        vpi_free_object(argv);
    }

    vpiHandle modules = vpi_iterate(vpiModule, 0);
    vpiHandle module = modules ? vpi_scan(modules) : 0;
    if (modules) vpi_free_object(modules);
    if (module) {
        vpiHandle regs = vpi_iterate(vpiReg, module);
        vpiHandle reg;
        while (regs && (reg = vpi_scan(regs))) {
            const char *reg_name = vpi_get_str(vpiName, reg);
            if (!reg_name || !strstr(reg_name, "_cnt0")) continue;
            value.format = vpiIntVal;
            vpi_get_value(reg, &value);
            count = value.value.integer;
            found += 1;
        }
    }

    if (found != 1 || count != expected) {
        vpi_printf("FAIL: long cover count found=%d count=%d expected=%d\n",
                   found, count, expected);
        vpi_control(vpiFinish, 1);
    } else {
        vpi_printf("PASS: long cover count=%d\n", count);
    }
    return 0;
}

static void register_tasks(void)
{
    s_vpi_systf_data tf;
    memset(&tf, 0, sizeof tf);
    tf.type = vpiSysTask;
    tf.tfname = "$check_long_cover";
    tf.calltf = check_calltf;
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
