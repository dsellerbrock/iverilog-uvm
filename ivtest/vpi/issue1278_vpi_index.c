#include <string.h>
#include <vpi_user.h>

static int failures;

static int check_index(vpiHandle handle, int expected, const char *what)
{
    s_vpi_value value = {vpiIntVal, {0}};
    if (!handle) {
        vpi_printf("FAIL %s has no index handle\n", what);
        failures++;
        return 0;
    }
    vpi_get_value(handle, &value);
    if (value.value.integer != expected) {
        vpi_printf("FAIL %s index %d expected %d\n", what,
                   value.value.integer, expected);
        failures++;
        return 0;
    }
    return 1;
}

static void check_indices(const char *name, const int *expected, int count)
{
    vpiHandle object = vpi_handle_by_name((PLI_BYTE8 *)name, 0);
    vpiHandle iterator = object ? vpi_iterate(vpiIndex, object) : 0;
    vpiHandle index;
    int found = 0;
    while (iterator && (index = vpi_scan(iterator))) {
        if (found >= count) {
            vpi_printf("FAIL %s returned extra index\n", name);
            failures++;
            continue;
        }
        check_index(index, expected[found], name);
        found++;
    }
    if (found != count) {
        vpi_printf("FAIL %s returned %d indices expected %d\n",
                   name, found, count);
        failures++;
    }
}

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    static const int unpacked_indices[] = {1, 3};
    static const int packed_indices[] = {2, 1};
    vpiHandle bit, index;
    (void)data;

    bit = vpi_handle_by_name((PLI_BYTE8 *)"top.arr[3][1]", 0);
    index = bit ? vpi_handle(vpiIndex, bit) : 0;
    check_index(index, 1, "top.arr[3][1]");
    check_indices("top.arr[3][1]", unpacked_indices, 2);

    bit = vpi_handle_by_name((PLI_BYTE8 *)"top.mda[1][2]", 0);
    index = bit ? vpi_handle(vpiIndex, bit) : 0;
    check_index(index, 2, "top.mda[1][2]");
    check_indices("top.mda[1][2]", packed_indices, 2);

    bit = vpi_handle_by_name((PLI_BYTE8 *)"top.var_arr[3]", 0);
    index = bit ? vpi_handle(vpiIndex, bit) : 0;
    check_index(index, 3, "top.var_arr[3]");

    bit = vpi_handle_by_name((PLI_BYTE8 *)"top.var_mda[1][2]", 0);
    index = bit ? vpi_handle(vpiIndex, bit) : 0;
    check_index(index, 2, "top.var_mda[1][2]");
    check_indices("top.var_mda[1][2]", packed_indices, 2);

    if (failures) {
        vpi_printf("ISSUE1278_VPI_INDEX_FAIL failures=%d\n", failures);
        vpi_control(vpiFinish, 1);
    } else {
        vpi_printf("ISSUE1278_VPI_INDEX_PASS\n");
        vpi_printf("PASSED\n");
    }
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$probe_vpi_index";
    data.calltf = probe;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = {register_probe, 0};
