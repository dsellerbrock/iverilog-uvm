#include <sv_vpi_user.h>

#if !defined(vpiStartLine) || !defined(vpiColumn) || \
    !defined(vpiEndLine) || !defined(vpiEndColumn)
#error "Assertion source-range property constants are missing"
#endif
_Static_assert(vpiStartLine == 661, "vpiStartLine value");
_Static_assert(vpiColumn == 662, "vpiColumn value");
_Static_assert(vpiEndLine == 663, "vpiEndLine value");
_Static_assert(vpiEndColumn == 664, "vpiEndColumn value");

static void register_check(void) { }
void (*vlog_startup_routines[])(void) = { register_check, 0 };
