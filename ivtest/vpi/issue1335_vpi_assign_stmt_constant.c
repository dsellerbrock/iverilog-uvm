#include <vpi_user.h>

_Static_assert(vpiAssignStmt == 2, "vpiAssignStmt value");

static void register_probe(void) { }
void (*vlog_startup_routines[])(void) = { register_probe, 0 };
