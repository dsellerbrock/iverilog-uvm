#include <vpi_user.h>

_Static_assert(vpiDisableFork == 673, "vpiDisableFork value");

static void register_probe(void) { }
void (*vlog_startup_routines[])(void) = { register_probe, 0 };
