#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>
#ifndef vpiArrayMember
#define vpiArrayMember 607
#endif
#ifndef vpiPackedArrayMember
#define vpiPackedArrayMember 655
#endif

static int check_property(const char *name, int property, int expected)
{
    vpiHandle handle = vpi_handle_by_name((PLI_BYTE8 *)name, 0);
    int actual = handle ? vpi_get(property, handle) : -2;
    if (actual != expected) {
        vpi_printf("FAIL %s property=%d got=%d expected=%d\n", name,
                   property, actual, expected);
        return 0;
    }
    return 1;
}

static PLI_INT32 probe_vpi_array_member(PLI_BYTE8 *data)
{
    int ok = 1;
    (void)data;

    ok &= check_property("top.arr[3]", vpiArrayMember, 1);
    ok &= check_property("top.arr", vpiArrayMember, 0);
    ok &= check_property("top.var_arr[3]", vpiArrayMember, 1);
    ok &= check_property("top.var_arr", vpiArrayMember, 0);
    ok &= check_property("top.mda[1]", vpiPackedArrayMember, 1);
    ok &= check_property("top.mda", vpiPackedArrayMember, 0);
    ok &= check_property("top.packed_net", vpiPackedArrayMember, 1);
    ok &= check_property("top.enum_net", vpiPackedArrayMember, 1);

    if (ok)
        vpi_printf("PASSED\n");
    else
        vpi_control(vpiFinish, 1);
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$probe_vpi_array_member";
    data.calltf = probe_vpi_array_member;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
