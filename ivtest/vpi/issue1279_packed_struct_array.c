#include <string.h>
#include <stdio.h>
#include <vpi_user.h>

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
#ifndef vpiPacked
#define vpiPacked 630
#endif
#ifndef vpiPackedArrayMember
#define vpiPackedArrayMember 655
#endif
#ifndef vpiElement
#define vpiElement 743
#endif

static int failures;

static void check_object(vpiHandle object, int type, int size,
                         int packed_array_member, const char *name)
{
    int got_type = object ? vpi_get(vpiType, object) : -1;
    int got_size = object ? vpi_get(vpiSize, object) : -1;
    int got_vector = object ? vpi_get(vpiVector, object) : -1;
    int got_packed = object ? vpi_get(vpiPacked, object) : -1;
    int got_member = object ? vpi_get(vpiPackedArrayMember, object) : -1;

    if (!object || got_type != type || got_size != size || !got_vector ||
        !got_packed || got_member != packed_array_member) {
        vpi_printf("FAIL %s type=%d size=%d vector=%d packed=%d member=%d\n",
                   name, got_type, got_size, got_vector, got_packed,
                   got_member);
        failures++;
    }
}

static void check_struct_elements(vpiHandle array, vpiHandle root,
                                  const char *name)
{
    vpiHandle iterator = array ? vpi_iterate(vpiElement, array) : 0;
    vpiHandle element;
    int count = 0;

    while (iterator && (element = vpi_scan(iterator))) {
        char label[96];
        const char *full_name = vpi_get_str(vpiFullName, element);
        snprintf(label, sizeof label, "%s element %d", name, count);
        check_object(element, vpiStructVar, 3, 1, label);
        if (!full_name || vpi_handle(vpiParent, element) != root) {
            vpi_printf("FAIL %s has wrong name or parent\n", label);
            failures++;
        }
        count++;
    }
    if (count != 2) {
        vpi_printf("FAIL %s returned %d elements expected 2\n", name,
                   count);
        failures++;
    }
}

static void check_array(const char *name, int size, int nested)
{
    vpiHandle root = vpi_handle_by_name((PLI_BYTE8 *)name, 0);
    vpiHandle iterator, element;
    int count = 0;

    check_object(root, vpiPackedArrayVar, size, 0, name);
    iterator = root ? vpi_iterate(vpiElement, root) : 0;
    while (iterator && (element = vpi_scan(iterator))) {
        char label[96];
        const char *full_name = vpi_get_str(vpiFullName, element);
        snprintf(label, sizeof label, "%s dimension element %d", name,
                 count);
        if (!full_name || vpi_handle(vpiParent, element) != root) {
            vpi_printf("FAIL %s has wrong name or parent\n", label);
            failures++;
        }
        if (nested) {
            check_object(element, vpiPackedArrayVar, 6, 1, label);
            check_struct_elements(element, root, label);
        } else {
            check_object(element, vpiStructVar, 3, 1, label);
        }
        count++;
    }
    if (count != 2) {
        vpi_printf("FAIL %s returned %d first-dimension elements expected 2\n",
                   name, count);
        failures++;
    }
}

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    vpiHandle root, element;
    (void)data;
    check_array("top.p", 6, 0);
    check_array("top.md", 12, 1);

    root = vpi_handle_by_name((PLI_BYTE8 *)"top.p", 0);
    element = vpi_handle_by_name((PLI_BYTE8 *)"top.p[1]", 0);
    check_object(element, vpiStructVar, 3, 1, "top.p[1]");
    if (!root || !element || vpi_handle(vpiParent, element) != root) {
        vpi_printf("FAIL top.p[1] has wrong parent\n");
        failures++;
    }

    if (failures) {
        vpi_printf("ISSUE1279_PACKED_STRUCT_ARRAY_FAIL failures=%d\n",
                   failures);
        vpi_control(vpiFinish, 1);
    } else {
        vpi_printf("ISSUE1279_PACKED_STRUCT_ARRAY_PASS\n");
        vpi_printf("PASSED\n");
    }
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$probe_issue1279_packed_struct_array";
    data.calltf = probe;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
