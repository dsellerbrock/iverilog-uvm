#include <string.h>
#include <vpi_user.h>
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
#ifndef vpiPackedArrayVar
#define vpiPackedArrayVar 623
#endif
#ifndef vpiElement
#define vpiElement 743
#endif

static int failures;

static void check_int(const char *what, int actual, int expected)
{
    if (actual != expected) {
        vpi_printf("FAIL %s got=%d expected=%d\n", what, actual, expected);
        failures++;
    }
}

static void check_name(vpiHandle handle, const char *expected)
{
    const char *actual = handle ? vpi_get_str(vpiFullName, handle) : NULL;
    if (!actual || strcmp(actual, expected) != 0) {
        vpi_printf("FAIL name got=%s expected=%s\n",
                   actual ? actual : "<null>", expected);
        failures++;
    }
}

static vpiHandle check_struct(vpiHandle handle, const char *name,
                              vpiHandle packed_parent)
{
    check_name(handle, name);
    if (!handle) return NULL;
    check_int("struct type", vpi_get(vpiType, handle), vpiStructVar);
    check_int("struct size", vpi_get(vpiSize, handle), 3);
    check_int("struct vector", vpi_get(vpiVector, handle), 1);
    check_int("struct packed", vpi_get(vpiPacked, handle), 1);
    check_int("struct packed-array member",
              vpi_get(vpiPackedArrayMember, handle), 1);
    if (vpi_handle(vpiParent, handle) != packed_parent) {
        vpi_printf("FAIL %s parent is not the containing packed array\n", name);
        failures++;
    }
    return handle;
}

static int check_elements(vpiHandle array, const char *name,
                          const char *first, const char *second,
                          int element_type, int element_size,
                          vpiHandle expected_parent)
{
    vpiHandle iter = vpi_iterate(vpiElement, array);
    vpiHandle item;
    const char *expected[2] = { first, second };
    int count = 0;

    while (iter && (item = vpi_scan(iter))) {
        if (count >= 2) {
            vpi_printf("FAIL %s has extra element\n", name);
            failures++;
            continue;
        }
        check_name(item, expected[count]);
        check_int("element type", vpi_get(vpiType, item), element_type);
        check_int("element size", vpi_get(vpiSize, item), element_size);
        check_int("element vector", vpi_get(vpiVector, item), 1);
        check_int("element packed", vpi_get(vpiPacked, item), 1);
        check_int("element packed-array member",
                  vpi_get(vpiPackedArrayMember, item), 1);
        if (vpi_handle(vpiParent, item) != expected_parent) {
            vpi_printf("FAIL %s element parent differs from iterator owner\n", name);
            failures++;
        }
        count++;
    }
    check_int(name, count, 2);
    return count;
}

static PLI_INT32 probe_issue1279(PLI_BYTE8 *data)
{
    vpiHandle p = vpi_handle_by_name((PLI_BYTE8 *)"top.p", NULL);
    vpiHandle q = vpi_handle_by_name((PLI_BYTE8 *)"top.q", NULL);
    vpiHandle iter, row;
    (void)data;

    check_int("p type", p ? vpi_get(vpiType, p) : -1, vpiPackedArrayVar);
    check_int("p size", p ? vpi_get(vpiSize, p) : -1, 6);
    check_int("p vector", p ? vpi_get(vpiVector, p) : -1, 1);
    check_int("p packed", p ? vpi_get(vpiPacked, p) : -1, 1);
    check_elements(p, "p elements", "top.p[1]", "top.p[0]",
                   vpiStructVar, 3, p);
    check_struct(vpi_handle_by_name((PLI_BYTE8 *)"top.p[1]", NULL),
                 "top.p[1]", p);

    check_int("q type", q ? vpi_get(vpiType, q) : -1, vpiPackedArrayVar);
    check_int("q size", q ? vpi_get(vpiSize, q) : -1, 12);
    check_int("q vector", q ? vpi_get(vpiVector, q) : -1, 1);
    check_int("q packed", q ? vpi_get(vpiPacked, q) : -1, 1);
    iter = q ? vpi_iterate(vpiElement, q) : NULL;
    if (!iter) {
        vpi_printf("FAIL q has no first-dimension elements\n");
        failures++;
    } else {
        const char *expected_rows[2] = { "top.q[1]", "top.q[0]" };
        int count = 0;
        while ((row = vpi_scan(iter))) {
            if (count >= 2) {
                vpi_printf("FAIL q has extra first-dimension element\n");
                failures++;
                continue;
            }
            check_name(row, expected_rows[count]);
            check_int("q row type", vpi_get(vpiType, row), vpiPackedArrayVar);
            check_int("q row size", vpi_get(vpiSize, row), 6);
            check_int("q row vector", vpi_get(vpiVector, row), 1);
            check_int("q row packed", vpi_get(vpiPacked, row), 1);
            if (vpi_handle(vpiParent, row) != q) {
                vpi_printf("FAIL q row parent is not top.q\n");
                failures++;
            }
            if (count == 0)
                check_elements(row, "q row elements", "top.q[1][2]",
                               "top.q[1][1]", vpiStructVar, 3, q);
            count++;
        }
        check_int("q first-dimension count", count, 2);
    }
    check_struct(vpi_handle_by_name((PLI_BYTE8 *)"top.q[1][2]", NULL),
                 "top.q[1][2]", q);

    if (failures == 0)
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
    data.tfname = "$probe_issue1279";
    data.calltf = probe_issue1279;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
