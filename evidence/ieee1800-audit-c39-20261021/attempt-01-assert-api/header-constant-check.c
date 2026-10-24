#include <sv_vpi_user.h>
#ifndef vpiAssertionDisable
#error "IEEE Annex M vpiAssertionDisable is absent from sv_vpi_user.h"
#endif
#if vpiAssertion != 744
#error "IEEE Annex M vpiAssertion is 744"
#endif
#if vpiModport != 606
#error "IEEE Annex M vpiModport is 606"
#endif
#ifndef cbAssertionSysLock
#error "IEEE Annex M cbAssertionSysLock is missing from sv_vpi_user.h"
#endif
