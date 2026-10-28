#include <vpi_user.h>

#ifndef vpiOpType
#error "vpiOpType is missing from the public VPI header"
#endif
#ifndef vpiAssignmentOp
#error "vpiAssignmentOp is missing from the public VPI header"
#endif

#if vpiOpType != 39
#error "vpiOpType has the wrong standard value"
#endif
#if vpiAssignmentOp != 82
#error "vpiAssignmentOp has the wrong standard value"
#endif

void (*vlog_startup_routines[])(void) = { 0 };
