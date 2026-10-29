#include <vpi_user.h>

#if vpiImplicitDecl != 26
#error vpiImplicitDecl must have the IEEE 1800 value 26
#endif

static void register_check(void)
{
}

void (*vlog_startup_routines[])(void) = {register_check, 0};
