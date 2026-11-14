#include <string.h>
#include <sv_vpi_user.h>

#ifndef vpiEnumVar
#define vpiEnumVar 617
#endif
#ifndef vpiStructVar
#define vpiStructVar 618
#endif
#ifndef vpiUnionVar
#define vpiUnionVar 619
#endif

static int failures;

static void check(const char *name, int type, int packed, int exp_type,
                  int exp_packed)
{
    if (type != exp_type || packed != exp_packed) {
        vpi_printf("FAIL %s: type=%d packed=%d expected=%d/%d\n", name,
                   type, packed, exp_type, exp_packed);
        failures++;
    }
    vpi_printf("%s: type=%d packed=%d\n", name, type, packed);
}

static PLI_INT32 probe(PLI_BYTE8 *ud)
{
    vpiHandle h;
    (void)ud;
    h = vpi_handle_by_name((PLI_BYTE8 *)"top.ps", 0);
    check("top.ps", vpi_get(vpiType, h), vpi_get(vpiPacked, h),
          vpiStructVar, 1);
    h = vpi_handle_by_name((PLI_BYTE8 *)"top.pu", 0);
    check("top.pu", vpi_get(vpiType, h), vpi_get(vpiPacked, h),
          vpiUnionVar, 1);
    h = vpi_handle_by_name((PLI_BYTE8 *)"top.c", 0);
    check("top.c", vpi_get(vpiType, h), vpi_get(vpiPacked, h),
          vpiEnumVar, 0);
    if (!failures) vpi_printf("PASSED\n");
    return 0;
}

static void reg(void)
{
    s_vpi_systf_data d;
    memset(&d, 0, sizeof d);
    d.type = vpiSysTask;
    d.tfname = (PLI_BYTE8 *)"$probe_issue2945";
    d.calltf = probe;
    vpi_register_systf(&d);
}

void (*vlog_startup_routines[])(void) = {reg, 0};
