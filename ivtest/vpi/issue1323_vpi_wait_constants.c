#include <vpi_user.h>

_Static_assert(vpiWait == 69, "vpiWait value");
_Static_assert(vpiElseStmt == 73, "vpiElseStmt value");
_Static_assert(vpiOrderedWait == 671, "vpiOrderedWait value");
_Static_assert(vpiWaitFork == 672, "vpiWaitFork value");

static void register_probe(void) { }
void (*vlog_startup_routines[])(void) = { register_probe, 0 };

