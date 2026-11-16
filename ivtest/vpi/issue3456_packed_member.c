#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>
#ifndef vpiStructUnionMember
#define vpiStructUnionMember 615
#endif

static int failures;

static void check(vpiHandle handle, const char *name)
{
    s_vpi_error_info error;
    int value;
    if (!handle) {
        vpi_printf("FAIL missing %s\n", name);
        failures++;
        return;
    }
    value = vpi_get(vpiStructUnionMember, handle);
    if (value != 0 || vpi_chk_error(&error)) {
        vpi_printf("FAIL %s member=%d or VPI error\n", name, value);
        failures++;
    }
}

static void check_elements(vpiHandle parent, const char *name, int recurse)
{
    vpiHandle iter = parent ? vpi_iterate(vpiElement, parent) : NULL;
    vpiHandle item;
    int count = 0;
    while (iter && (item = vpi_scan(iter))) {
        check(item, name);
        if (recurse) check_elements(item, "nested element", 0);
        count++;
    }
    if (count != 2) {
        vpi_printf("FAIL %s count=%d\n", name, count);
        failures++;
    }
}

static PLI_INT32 probe(PLI_BYTE8 *unused)
{
    vpiHandle p = vpi_handle_by_name((PLI_BYTE8 *)"top.p", NULL);
    vpiHandle q = vpi_handle_by_name((PLI_BYTE8 *)"top.q", NULL);
    (void)unused;
    check(p, "p");
    check(q, "q");
    check(vpi_handle_by_name((PLI_BYTE8 *)"top.p[1]", NULL), "p[1]");
    check(vpi_handle_by_name((PLI_BYTE8 *)"top.p[0]", NULL), "p[0]");
    check(vpi_handle_by_name((PLI_BYTE8 *)"top.q[1][2]", NULL), "q[1][2]");
    check_elements(p, "p element", 0);
    check_elements(q, "q element", 1);
    if (failures) vpi_control(vpiFinish, 1);
    else vpi_printf("ISSUE3456 PASS\nPASSED\n");
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$probe_issue3456";
    data.calltf = probe;
    vpi_register_systf(&data);
}
void (*vlog_startup_routines[])(void) = { register_probe, 0 };
