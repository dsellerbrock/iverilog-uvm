#define VPI_COMPATIBILITY_VERSION_1800v2023 1
#include "vpi_user.h"

#ifndef vpi_get
#error "vpi_get was not remapped for the selected VPI compatibility mode"
#endif

static void register_vpi_compatibility_test(void)
{
}

void (*vlog_startup_routines[])(void) = {
      register_vpi_compatibility_test,
      0
};
