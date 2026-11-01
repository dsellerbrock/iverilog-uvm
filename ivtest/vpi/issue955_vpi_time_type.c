#include <vpi_user.h>

static PLI_INT32 check_types(PLI_BYTE8 *data)
{
    static const char *names[] = { "TIME", "INTEGER", "REAL", "REG" };
    static const int expected[] = {
        vpiTimeVar, vpiIntegerVar, vpiRealVar, vpiReg
    };
    vpiHandle task, args, arg;
    unsigned count = 0;
    int passed = 1;

    (void)data;
    task = vpi_handle(vpiSysTfCall, 0);
    args = vpi_iterate(vpiArgument, task);
    while (args && (arg = vpi_scan(args))) {
        int actual;
        if (count >= sizeof expected / sizeof expected[0]) {
            vpi_printf("ISSUE955_FAIL too many argument handles\n");
            return 0;
        }
        actual = vpi_get(vpiType, arg);
        vpi_printf("ISSUE955_%s_TYPE=%d\n", names[count], actual);
        if (actual != expected[count]) {
            vpi_printf("ISSUE955_FAIL %s expected=%d actual=%d\n",
                       names[count], expected[count], actual);
            passed = 0;
        }
        count++;
    }

    if (count != sizeof expected / sizeof expected[0]) {
        vpi_printf("ISSUE955_FAIL expected 4 argument handles, got %u\n",
                   count);
        passed = 0;
    }
    if (passed) vpi_printf("ISSUE955_PASSED\nPASSED\n");
    return 0;
}

static void register_check_types(void)
{
    s_vpi_systf_data tf;
    tf.type = vpiSysTask;
    tf.tfname = "$issue955_check_types";
    tf.calltf = check_types;
    tf.compiletf = 0;
    tf.sizetf = 0;
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_check_types, 0 };
