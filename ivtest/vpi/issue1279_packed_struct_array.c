#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

#ifndef vpiStructVar
#define vpiStructVar 618
#endif
#ifndef vpiPackedArrayVar
#define vpiPackedArrayVar 623
#endif
#ifndef vpiElement
#define vpiElement 743
#endif
#ifndef vpiPackedArrayMember
#define vpiPackedArrayMember 655
#endif
#ifndef vpiPacked
#define vpiPacked 630
#endif

static int failed;

static void require(int condition, const char *message)
{
    if (!condition) {
        failed = 1;
        vpi_printf("FAIL %s\n", message);
    }
}

static unsigned check_elements(vpiHandle array, int child_type,
                               int child_size, unsigned expected_count)
{
    unsigned count = 0;
    vpiHandle iter = array ? vpi_iterate(vpiElement, array) : 0;
    vpiHandle item;

    require(iter != 0, "vpiElement iterator missing");
    while (iter && (item = vpi_scan(iter))) {
        ++count;
        require(vpi_get(vpiType, item) == child_type,
                "unexpected vpiElement type");
        require(vpi_get(vpiSize, item) == child_size,
                "unexpected vpiElement size");
        require(vpi_get(vpiPacked, item) == 1,
                "vpiElement is not packed");
        require(vpi_get(vpiPackedArrayMember, item) == 1,
                "vpiElement is not a packed-array member");
    }
    require(count == expected_count, "unexpected vpiElement count");
    return count;
}

static void check_p(void)
{
    vpiHandle array = vpi_handle_by_name((PLI_BYTE8 *)"top.p", 0);
    vpiHandle direct;

    require(array != 0, "top.p lookup failed");
    if (!array) return;
    require(vpi_get(vpiType, array) == vpiPackedArrayVar,
            "top.p is not vpiPackedArrayVar");
    require(vpi_get(vpiSize, array) == 6, "top.p size is not 6");
    require(vpi_get(vpiVector, array) == 1, "top.p is not a vector");
    require(vpi_get(vpiPacked, array) == 1, "top.p is not packed");
    check_elements(array, vpiStructVar, 3, 2);

    direct = vpi_handle_by_name((PLI_BYTE8 *)"top.p[1]", 0);
    require(direct != 0, "top.p[1] lookup failed");
    if (direct) {
        require(vpi_get(vpiType, direct) == vpiStructVar,
                "top.p[1] is not vpiStructVar");
        require(vpi_get(vpiSize, direct) == 3,
                "top.p[1] size is not 3");
    }
}

static void check_q(void)
{
    vpiHandle array = vpi_handle_by_name((PLI_BYTE8 *)"top.q", 0);
    vpiHandle iter, row;
    unsigned rows = 0;

    require(array != 0, "top.q lookup failed");
    if (!array) return;
    require(vpi_get(vpiType, array) == vpiPackedArrayVar,
            "top.q is not vpiPackedArrayVar");
    require(vpi_get(vpiSize, array) == 12, "top.q size is not 12");
    require(vpi_get(vpiVector, array) == 1, "top.q is not a vector");
    require(vpi_get(vpiPacked, array) == 1, "top.q is not packed");

    iter = vpi_iterate(vpiElement, array);
    require(iter != 0, "top.q vpiElement iterator missing");
    while (iter && (row = vpi_scan(iter))) {
        ++rows;
        require(vpi_get(vpiType, row) == vpiPackedArrayVar,
                "top.q element is not vpiPackedArrayVar");
        require(vpi_get(vpiSize, row) == 6,
                "top.q element size is not 6");
        require(vpi_get(vpiPacked, row) == 1,
                "top.q element is not packed");
        require(vpi_get(vpiPackedArrayMember, row) == 1,
                "top.q element is not a packed-array member");
        check_elements(row, vpiStructVar, 3, 2);
    }
    require(rows == 2, "top.q vpiElement count is not 2");
}

static PLI_INT32 probe(PLI_BYTE8 *user_data)
{
    (void)user_data;
    check_p();
    check_q();
    vpi_printf("%s issue1279\n", failed ? "FAIL" : "PASS");
    if (!failed) vpi_printf("PASSED\n");
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data tf;
    memset(&tf, 0, sizeof tf);
    tf.type = vpiSysTask;
    tf.tfname = "$probe";
    tf.calltf = probe;
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
