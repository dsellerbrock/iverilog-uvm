#include <vpi_user.h>

#if vpiRepeatControl != 52
#error "vpiRepeatControl must have the IEEE value 52"
#endif

static void startup(void)
{
    vpi_printf("ISSUE1325_VPI_REPEAT_CONTROL_PASSED\nPASSED\n");
}

void (*vlog_startup_routines[])(void) = { startup, 0 };
