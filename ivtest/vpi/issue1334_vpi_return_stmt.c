#include <string.h>
#include <vpi_user.h>

#if !defined(vpiReturnStmt) || vpiReturnStmt != 691
#error "vpiReturnStmt is missing or has the wrong value"
#endif

static PLI_INT32 check_return_stmt(PLI_BYTE8 *data)
{
    (void)data;
    vpi_printf("VPI RETURN STATEMENT CONSTANT PASSED\nPASSED\n");
    return 0;
}

static void register_check(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$check_vpi_return_stmt";
    data.calltf = check_return_stmt;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_check, 0 };
