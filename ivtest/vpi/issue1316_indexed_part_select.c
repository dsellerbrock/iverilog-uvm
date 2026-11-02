#include <string.h>
#include <vpi_user.h>

#if !defined(vpiIndexedPartSelect) || !defined(vpiBaseExpr) || \
    !defined(vpiWidthExpr)
#define ISSUE1316_VPI_CONSTANTS_MISSING 1
#ifndef vpiIndexedPartSelect
#define vpiIndexedPartSelect 130
#endif
#ifndef vpiBaseExpr
#define vpiBaseExpr 131
#endif
#ifndef vpiWidthExpr
#define vpiWidthExpr 132
#endif
#endif

static unsigned calls;
static int failed;

static int get_int_value(vpiHandle obj, int *result)
{
    s_vpi_value value;
    if (!obj)
        return 0;
    value.format = vpiIntVal;
    vpi_get_value(obj, &value);
    *result = value.value.integer;
    return 1;
}

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    vpiHandle call = vpi_handle(vpiSysTfCall, 0);
    vpiHandle iter = call ? vpi_iterate(vpiArgument, call) : 0;
    vpiHandle arg = iter ? vpi_scan(iter) : 0;
    vpiHandle base = arg ? vpi_handle(vpiBaseExpr, arg) : 0;
    vpiHandle width = arg ? vpi_handle(vpiWidthExpr, arg) : 0;
    vpiHandle parent = arg ? vpi_handle(vpiParent, arg) : 0;
    s_vpi_value value;
    const char *name;
    int base_value, width_value, selected_value;
    (void)data;

    if (calls == 0) {
#ifdef ISSUE1316_VPI_CONSTANTS_MISSING
        failed = 1;
#endif
        name = base ? vpi_get_str(vpiName, base) : 0;
        if (!arg || vpi_get(vpiType, arg) != vpiIndexedPartSelect ||
            !name || strcmp(name, "base") != 0 ||
            vpi_get(vpiType, base) != vpiIntegerVar ||
            !get_int_value(base, &base_value) || base_value != 4 ||
            !width || vpi_get(vpiType, width) != vpiConstant ||
            !get_int_value(width, &width_value) || width_value != 4 ||
            !parent || vpi_get(vpiType, parent) != vpiReg ||
            !vpi_get_str(vpiName, parent) ||
            strcmp(vpi_get_str(vpiName, parent), "data") != 0) {
            failed = 1;
        }
        value.format = vpiIntVal;
        if (arg)
            vpi_get_value(arg, &value);
        selected_value = arg ? value.value.integer : -1;
        if (selected_value != 5)
            failed = 1;
    } else if (calls == 1) {
        if (!arg || vpi_get(vpiType, arg) != vpiPartSelect || base || width)
            failed = 1;
        value.format = vpiIntVal;
        if (arg)
            vpi_get_value(arg, &value);
        selected_value = arg ? value.value.integer : -1;
        if (selected_value != 5)
            failed = 1;
    } else {
        failed = 1;
    }

    calls += 1;
    if (failed) {
        vpi_printf("ISSUE1316_INDEXED_PART_SELECT_FAILED\n");
        vpi_control(vpiFinish, 1);
    } else if (calls == 2) {
        vpi_printf("ISSUE1316_INDEXED_PART_SELECT_PASSED\nPASSED\n");
    }
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data tf;
    memset(&tf, 0, sizeof tf);
    tf.type = vpiSysTask;
    tf.tfname = "$selectprobe";
    tf.calltf = probe;
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
