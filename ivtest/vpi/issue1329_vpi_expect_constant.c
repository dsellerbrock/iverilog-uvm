#include <vpi_user.h>

#ifndef vpiExpectStmt
#error "vpiExpectStmt is missing from vpi_user.h"
#endif
_Static_assert(vpiExpectStmt == 674, "vpiExpectStmt value");

static void register_check(void) { }

void (*vlog_startup_routines[])(void) = { register_check, 0 };
