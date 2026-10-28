#include "vpi_user.h"

#if vpiRepeat != 51
#error "vpiRepeat must identify repeat statements"
#endif
#if vpiWhile != 70
#error "vpiWhile must identify while statements"
#endif

static void register_loop_type_test(void)
{
}

void (*vlog_startup_routines[])(void) = {
      register_loop_type_test,
      0
};
