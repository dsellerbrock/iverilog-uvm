#include <string.h>
#include <vpi_user.h>

static int errors;
static void check(const char *path, int expected)
{
    vpiHandle obj = vpi_handle_by_name((PLI_BYTE8 *)path, 0);
    s_vpi_value value;
    if (!obj) {
        vpi_printf("FAIL: missing %s\n", path);
        ++errors;
        return;
    }
    value.format = vpiIntVal;
    vpi_get_value(obj, &value);
    if (vpi_get(vpiSize, obj) != 8 || value.value.integer != expected) {
        vpi_printf("FAIL: %s size=%d value=%x\n", path,
                   vpi_get(vpiSize, obj), value.value.integer);
        ++errors;
    }
}
static void missing(const char *path)
{
    if (vpi_handle_by_name((PLI_BYTE8 *)path, 0)) {
        vpi_printf("FAIL: unexpectedly resolved %s\n", path);
        ++errors;
    }
}
static PLI_INT32 probe(PLI_BYTE8 *unused)
{
    vpiHandle obj;
    s_vpi_value value;
    (void)unused;
    check("tb.mem[2]", 0x67);
    check("tb.matrix[2][1]", 0x12);
    check("tb.matrix[2][2]", 0x34);
    check("tb.matrix[3][1]", 0x56);
    check("tb.matrix[3][2]", 0x67);
    check("tb.cube[0][-1][4]", 0x81);
    check("tb.cube[1][0][5]", 0x9a);
    missing("tb.matrix[3]");
    missing("tb.matrix[1][2]");
    missing("tb.matrix[3][3]");
    missing("tb.matrix[999999999999999999999999][2]");
    obj = vpi_handle_by_name((PLI_BYTE8 *)"tb.matrix[2][1]", 0);
    if (obj) {
        value.format = vpiIntVal;
        value.value.integer = 0xb5;
        vpi_put_value(obj, &value, 0, vpiNoDelay);
    }
    if (!errors) vpi_printf("lookup PASSED\n");
    return 0;
}
static void register_probe(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$issue3716_probe";
    data.calltf = probe;
    vpi_register_systf(&data);
}
void (*vlog_startup_routines[])(void) = { register_probe, 0 };
