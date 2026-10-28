#include "vpi_user.h"

_Static_assert(__builtin_types_compatible_p(
                   __typeof__(&vpi_get_cb_info),
                   void (*)(vpiHandle, p_cb_data)),
               "vpi_get_cb_info has the wrong declaration");

static void register_vpi_test(void)
{
}

void (*vlog_startup_routines[])(void) = {
      register_vpi_test,
      0
};
