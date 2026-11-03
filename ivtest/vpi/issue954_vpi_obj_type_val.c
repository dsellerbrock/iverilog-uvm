#include <stdio.h>
#include <string.h>
#include <vpi_user.h>

static int passed = 1;

static vpiHandle lookup(const char *name)
{
    vpiHandle handle = vpi_handle_by_name((PLI_BYTE8 *)name, 0);
    if (!handle) {
        vpi_printf("ISSUE954_FAIL missing %s\n", name);
        passed = 0;
    }
    return handle;
}

static PLI_INT32 check_obj_type_val(PLI_BYTE8 *data)
{
    vpiHandle handle;
    s_vpi_value value;
    s_vpi_time time_value;

    (void)data;

    handle = lookup("top.ii");
    if (handle) {
        memset(&value, 0, sizeof(value));
        value.format = vpiObjTypeVal;
        vpi_get_value(handle, &value);
        if (value.format == vpiIntVal && value.value.integer == -5) {
            vpi_printf("ISSUE954_INTEGER=vpiIntVal:-5\n");
        } else {
            vpi_printf("ISSUE954_FAIL integer format=%d\n", value.format);
            passed = 0;
        }
    }

    handle = lookup("top.tt");
    if (handle) {
        memset(&value, 0, sizeof(value));
        memset(&time_value, 0, sizeof(time_value));
        value.format = vpiObjTypeVal;
        value.value.time = &time_value;
        vpi_get_value(handle, &value);
        if (value.format == vpiTimeVal && value.value.time &&
            value.value.time->type == vpiSimTime &&
            value.value.time->high == 1 && value.value.time->low == 2) {
            vpi_printf("ISSUE954_TIME=vpiTimeVal:vpiSimTime:00000001:00000002\n");
        } else if (value.format == vpiTimeVal && value.value.time) {
            vpi_printf("ISSUE954_FAIL time type=%d high=%u low=%u\n",
                       value.value.time->type, value.value.time->high,
                       value.value.time->low);
            passed = 0;
        } else {
            vpi_printf("ISSUE954_FAIL time format=%d\n", value.format);
            passed = 0;
        }
    }

    handle = lookup("top.vec");
    if (handle) {
        memset(&value, 0, sizeof(value));
        value.format = vpiObjTypeVal;
        vpi_get_value(handle, &value);
        if (value.format == vpiVectorVal && value.value.vector &&
            value.value.vector[0].aval == 2 &&
            value.value.vector[0].bval == 0 &&
            value.value.vector[1].aval == 1 &&
            value.value.vector[1].bval == 0) {
            vpi_printf("ISSUE954_VECTOR=vpiVectorVal:00000001:00000002\n");
        } else {
            vpi_printf("ISSUE954_FAIL vector format=%d\n", value.format);
            passed = 0;
        }
    }

    handle = lookup("top.rr");
    if (handle) {
        memset(&value, 0, sizeof(value));
        value.format = vpiObjTypeVal;
        vpi_get_value(handle, &value);
        if (value.format == vpiRealVal && value.value.real == 1.25) {
            vpi_printf("ISSUE954_REAL=vpiRealVal:1.25\n");
        } else {
            vpi_printf("ISSUE954_FAIL real format=%d\n", value.format);
            passed = 0;
        }
    }

    handle = lookup("top.ss");
    if (handle) {
        memset(&value, 0, sizeof(value));
        value.format = vpiObjTypeVal;
        vpi_get_value(handle, &value);
        if (value.format == vpiScalarVal && value.value.scalar == vpi1) {
            vpi_printf("ISSUE954_SCALAR=vpiScalarVal:1\n");
        } else {
            vpi_printf("ISSUE954_FAIL scalar format=%d\n", value.format);
            passed = 0;
        }
    }

    if (passed) vpi_printf("ISSUE954_PASSED\nPASSED\n");
    return 0;
}

static void register_check_obj_type_val(void)
{
    s_vpi_systf_data tf;
    memset(&tf, 0, sizeof(tf));
    tf.type = vpiSysTask;
    tf.tfname = "$issue954_check_obj_type_val";
    tf.calltf = check_obj_type_val;
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_check_obj_type_val, 0 };
