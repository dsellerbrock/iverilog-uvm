#include <vpi_user.h>

#ifndef vpiForIncStmt
#error "vpiForIncStmt is missing from vpi_user.h"
#endif
#ifndef vpiForInitStmt
#error "vpiForInitStmt is missing from vpi_user.h"
#endif
#ifndef vpiLocalVarDecls
#error "vpiLocalVarDecls is missing from vpi_user.h"
#endif

_Static_assert(vpiForIncStmt == 74, "vpiForIncStmt value");
_Static_assert(vpiForInitStmt == 75, "vpiForInitStmt value");
_Static_assert(vpiLocalVarDecls == 609, "vpiLocalVarDecls value");

static void register_check(void) { }

void (*vlog_startup_routines[])(void) = { register_check, 0 };
