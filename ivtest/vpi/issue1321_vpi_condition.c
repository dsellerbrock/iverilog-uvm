#include <vpi_user.h>

static void check_condition_code(void)
{
    if (vpiCondition == 71)
        vpi_printf("PASSED\n");
    else
        vpi_printf("FAIL vpiCondition=%d\n", vpiCondition);
}

void (*vlog_startup_routines[])(void) = { check_condition_code, 0 };
