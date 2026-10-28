#include <vpi_user.h>

#ifndef vpiBlocking
#error "vpiBlocking is missing from the public VPI header"
#endif

#if vpiBlocking != 41
#error "vpiBlocking has the wrong standard value"
#endif

void (*vlog_startup_routines[])(void) = { 0 };
