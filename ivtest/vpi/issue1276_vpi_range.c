#include <string.h>
#include <vpi_user.h>
#ifndef vpiRange
#define vpiRange 115
#endif

static int check_ranges(const char *name, int expected_count,
                        const int *bounds)
{
    vpiHandle object = vpi_handle_by_name((PLI_BYTE8 *)name, 0);
    vpiHandle iterator = object ? vpi_iterate(vpiRange, object) : 0;
    vpiHandle range;
    int count = 0;

    while (iterator && (range = vpi_scan(iterator))) {
        vpiHandle left_expr = vpi_handle(vpiLeftRange, range);
        vpiHandle right_expr = vpi_handle(vpiRightRange, range);
        s_vpi_value left_value, right_value;
        if (!left_expr || !right_expr ||
            vpi_get(vpiType, range) != vpiRange) {
            vpi_printf("FAIL %s unexpected range object\n", name);
            return 0;
        }
        left_value.format = right_value.format = vpiIntVal;
        vpi_get_value(left_expr, &left_value);
        vpi_get_value(right_expr, &right_value);
        if (left_value.value.integer != bounds[count * 2] ||
            right_value.value.integer != bounds[count * 2 + 1]) {
            vpi_printf("FAIL %s range %d:%d, expected %d:%d\n", name,
                       left_value.value.integer, right_value.value.integer,
                       bounds[count * 2], bounds[count * 2 + 1]);
            return 0;
        }
        count += 1;
    }
    if (count != expected_count) {
        vpi_printf("FAIL %s found %d ranges, expected %d\n",
                   name, count, expected_count);
        return 0;
    }
    return 1;
}

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    static const int packed_bounds[] = {3, 0};
    static const int array_bounds[] = {3, 2};
    static const int multidim_array_bounds[] = {4, 3, 2, 1};
    static const int element_bounds[] = {1, 0};
    static const int multidim_bounds[] = {3, 0, 2, 1};
    (void)data;
    if (!check_ranges("top.vec", 1, packed_bounds) ||
        !check_ranges("top.arr", 1, array_bounds) ||
        !check_ranges("top.arr[3]", 1, element_bounds) ||
        !check_ranges("top.var_vec", 1, packed_bounds) ||
        !check_ranges("top.var_arr", 1, array_bounds) ||
        !check_ranges("top.arr_multi", 2, multidim_array_bounds) ||
        !check_ranges("top.var_arr_multi", 2, multidim_array_bounds) ||
        !check_ranges("top.packed_vec", 2, multidim_bounds) ||
        !check_ranges("top.packed_var", 2, multidim_bounds)) {
        vpi_control(vpiFinish, 1);
        return 0;
    }
    vpi_printf("PASSED\n");
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$probe_vpi_range";
    data.calltf = probe;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
