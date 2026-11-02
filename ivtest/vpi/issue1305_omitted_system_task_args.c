#include <stdio.h>
#include <string.h>
#include <vpi_user.h>

static PLI_INT32 probe_calltf(PLI_BYTE8 *user_data)
{
    (void)user_data;
    static const int expected_type[] = {
        vpiConstant, vpiConstant, vpiOperation, vpiConstant, vpiOperation
    };
    static const int expected_subtype[] = {
        -1, vpiStringConst, vpiNullOp, vpiNullConst, vpiNullOp
    };
    vpiHandle call = vpi_handle(vpiSysTfCall, NULL);
    vpiHandle iter = vpi_iterate(vpiArgument, call);
    vpiHandle arg;
    int index = 0;
    int failed = 0;

    while (iter && (arg = vpi_scan(iter))) {
        int type = vpi_get(vpiType, arg);
        int subtype = type == vpiOperation ? vpi_get(vpiOpType, arg)
                    : type == vpiConstant ? vpi_get(vpiConstType, arg) : -1;
        printf("ARG %d type=%d subtype=%d\n", index, type, subtype);
        if (index >= (int)(sizeof expected_type / sizeof expected_type[0])
            || type != expected_type[index]
            || (expected_subtype[index] >= 0
                && subtype != expected_subtype[index]))
            failed = 1;
        index++;
    }

    if (index != (int)(sizeof expected_type / sizeof expected_type[0]))
        failed = 1;
    printf("ARG_COUNT=%d\n", index);
    if (failed)
        fprintf(stderr, "FAIL: system-task argument VPI representation\n");
    else
        puts("PASSED");
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$issue1305_probe";
    data.calltf = probe_calltf;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
