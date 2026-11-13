#include <string.h>
#include <sv_vpi_user.h>

static int failures;
static int calls;

static void check(const char *name, int expected_type, int expected_members)
{
    vpiHandle h = vpi_handle_by_name((PLI_BYTE8 *)name, 0), it;
    int type, packed, members = 0;
    if (!h) {
        vpi_printf("FAIL %s: no handle\n", name);
        failures++;
        return;
    }
    type = vpi_get(vpiType, h);
    packed = vpi_get(vpiPacked, h);
    it = vpi_iterate(vpiMember, h);
    while (it && vpi_scan(it)) members++;
    if (type != expected_type || packed != 0 || members != expected_members) {
        vpi_printf("FAIL %s: type=%d packed=%d members=%d\n",
                   name, type, packed, members);
        failures++;
    }
}

static PLI_INT32 probe(PLI_BYTE8 *ud)
{
    vpiHandle h;
    (void)ud;
    check("top.s", vpiStructVar, 2);
    check("top.u", vpiUnionVar, 2);
    h = vpi_handle_by_name((PLI_BYTE8 *)"top.c", 0);
    if (!h || vpi_get(vpiType, h) != vpiClassVar) {
        vpi_printf("FAIL top.c: not a class variable\n");
        failures++;
    }
    if (++calls == 2 && !failures)
        vpi_printf("UNPACKED STRUCT UNION VPI PASS\nPASSED\n");
    return 0;
}

static void reg(void)
{
    s_vpi_systf_data d;
    memset(&d, 0, sizeof d);
    d.type = vpiSysTask;
    d.tfname = (PLI_BYTE8 *)"$probe_issue2946";
    d.calltf = probe;
    vpi_register_systf(&d);
}

void (*vlog_startup_routines[])(void) = {reg, 0};
