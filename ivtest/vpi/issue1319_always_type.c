#include <vpi_user.h>

#if vpiAlwaysType != 624
#error "vpiAlwaysType must be 624"
#endif
#if vpiAlwaysComb != 2
#error "vpiAlwaysComb must be 2"
#endif
#if vpiAlwaysFF != 3
#error "vpiAlwaysFF must be 3"
#endif
#if vpiAlwaysLatch != 4
#error "vpiAlwaysLatch must be 4"
#endif

void (*vlog_startup_routines[])(void) = {0};
