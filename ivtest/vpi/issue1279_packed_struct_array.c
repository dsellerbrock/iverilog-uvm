#include <string.h>
#include <vpi_user.h>

#ifndef vpiPackedArrayVar
#define vpiPackedArrayVar 623
#endif
#ifndef vpiStructVar
#define vpiStructVar 618
#endif
#ifndef vpiElement
#define vpiElement 743
#endif
#ifndef vpiPacked
#define vpiPacked 630
#endif
#ifndef vpiPackedArrayMember
#define vpiPackedArrayMember 655
#endif

static int check_array(vpiHandle array, vpiHandle parent, int size, int element_type,
                       int element_size, const char *name)
{
    vpiHandle iter, element;
    int count = 0;
    if (!array || vpi_get(vpiType, array) != vpiPackedArrayVar
        || vpi_get(vpiSize, array) != size
        || vpi_get(vpiVector, array) != 1
        || vpi_get(vpiPacked, array) != 1) {
        vpi_printf("array %s handle=%p type=%d size=%d vector=%d packed=%d\n",
                   name, array, array ? vpi_get(vpiType, array) : -1,
                   array ? vpi_get(vpiSize, array) : -1,
                   array ? vpi_get(vpiVector, array) : -1,
                   array ? vpi_get(vpiPacked, array) : -1);
        return 0;
    }
    iter = vpi_iterate(vpiElement, array);
    while (iter && (element = vpi_scan(iter))) {
        const char *full_name = vpi_get_str(vpiFullName, element);
        if (vpi_get(vpiType, element) != element_type
            || vpi_get(vpiSize, element) != element_size
            || vpi_get(vpiScalar, element) != 0
            || vpi_get(vpiVector, element) != 1
            || vpi_get(vpiPacked, element) != 1
            || vpi_get(vpiPackedArrayMember, element) != 1
            || vpi_handle(vpiParent, element) != parent
            || !full_name || strncmp(full_name, name, strlen(name)) != 0)
            { vpi_printf("element %s handle=%p type=%d size=%d parent=%p array=%p\n",
                         full_name ? full_name : "?", element,
                         vpi_get(vpiType, element), vpi_get(vpiSize, element),
                         vpi_handle(vpiParent, element), array); return 0; }
        count++;
    }
    return count == 2;
}

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    vpiHandle p, q, r, p_element, iter, q_element;
    int q_elements = 0;
    (void)data;
    p = vpi_handle_by_name((PLI_BYTE8*)"top.p", 0);
    if (!check_array(p, p, 6, vpiStructVar, 3, "top.p[")) goto fail;
    p_element = vpi_handle_by_name((PLI_BYTE8*)"top.p[1]", 0);
    if (!p_element || vpi_get(vpiType, p_element) != vpiStructVar
        || vpi_get(vpiSize, p_element) != 3
        || vpi_get(vpiPacked, p_element) != 1
        || vpi_get(vpiVector, p_element) != 1) goto fail;

    q = vpi_handle_by_name((PLI_BYTE8*)"top.q", 0);
    if (!q || vpi_get(vpiType, q) != vpiPackedArrayVar
        || vpi_get(vpiSize, q) != 12 || vpi_get(vpiPacked, q) != 1
        || vpi_get(vpiVector, q) != 1) goto fail;
    iter = vpi_iterate(vpiElement, q);
    while (iter && (q_element = vpi_scan(iter))) {
        if (vpi_get(vpiType, q_element) != vpiPackedArrayVar
            || vpi_get(vpiSize, q_element) != 6
            || vpi_handle(vpiParent, q_element) != q
            || !check_array(q_element, q, 6, vpiStructVar, 3, "top.q["))
            goto fail;
        q_elements++;
    }
    if (q_elements != 2) goto fail;
    r = vpi_handle_by_name((PLI_BYTE8*)"top.r", 0);
    if (!check_array(r, r, 2, vpiStructVar, 1, "top.r[")) goto fail;
    vpi_printf("PASSED\n");
    return 0;

fail:
    vpi_printf("FAIL packed struct array VPI model\n");
    vpi_control(vpiFinish, 1);
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$probe_packed_struct_array";
    data.calltf = probe;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
