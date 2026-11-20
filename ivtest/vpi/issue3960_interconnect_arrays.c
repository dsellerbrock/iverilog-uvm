#include <stdio.h>
#include <string.h>
#include "sv_vpi_user.h"

/* Use the standard codes even when building against the baseline headers. */
enum { interconnect_net = 533, interconnect_array = 534 };

static int failed;

static void check(int ok, const char *name, const char *property)
{
    if (!ok) {
        vpi_printf("Failed: %s (%s)\n", name, property);
        failed = 1;
    }
}

static int integer_value(vpiHandle obj)
{
    s_vpi_value value = {.format = vpiIntVal};
    vpi_get_value(obj, &value);
    return value.value.integer;
}

static void check_range(vpiHandle obj, int left, int right, const char *name)
{
    vpiHandle l = vpi_handle(vpiLeftRange, obj);
    vpiHandle r = vpi_handle(vpiRightRange, obj);
    check(l && integer_value(l) == left, name, "left range");
    check(r && integer_value(r) == right, name, "right range");
}

static void check_properties(vpiHandle obj, int type, const char *type_name,
                             int size, const char *name)
{
    check(vpi_get(vpiType, obj) == type, name, "numeric type");
    const char *type_str = vpi_get_str(vpiType, obj);
    check(type_str && strcmp(type_str, type_name) == 0, name, "string type");
    check(vpi_get(vpiSize, obj) == size, name, "size");
}

static void check_value(vpiHandle obj, const char *bits, const char *name)
{
    s_vpi_value value = {.format = vpiBinStrVal};
    vpi_get_value(obj, &value);
    check(value.format == vpiBinStrVal && value.value.str &&
          strcmp(value.value.str, bits) == 0, name, "value");
}

struct dimension {
    int left, right, packed;
};

static const char mixed_values[] = "1001" "0110" "1010" "z01x" "1xz0" "0011";

/* Check each prefix via absolute name, one index, and the complete index
   list. The expected value is expressed in declaration order. */
static void check_tree(vpiHandle root, vpiHandle obj, const char *name,
                       const struct dimension *dims, int rank,
                       PLI_INT32 *indices, int depth, const char *bits, int offset)
{
    check(obj != NULL, name, "object exists");
    if (!obj) return;

    const char *full_name = vpi_get_str(vpiFullName, obj);
    check(full_name && strcmp(full_name, name) == 0, name, "full name");
    check(vpi_handle_by_name(name, NULL) == obj, name, "by-name identity");
    if (depth) {
        check(vpi_handle_by_multi_index(root, depth, indices) == obj, name,
              "multi-index identity");
        vpiHandle index = vpi_handle(vpiIndex, obj);
        check(index && integer_value(index) == indices[depth - 1], name, "index");
    }
    check(vpi_get(vpiNetType, obj) == vpiInterconnect, name, "net kind");

    if (depth == rank) {
        char bit[] = {bits[offset], 0};
        check_properties(obj, interconnect_net, "vpiInterconnectNet", 1, name);
        check(!vpi_get(vpiPacked, obj), name, "leaf packed flag");
        check(!vpi_handle_by_index(obj, 0), name, "leaf has no further index");
        check_value(obj, bit, name);
        vpiHandle iter = vpi_iterate(vpiIndex, obj);
        for (int i = depth; i > 0; --i) {
            vpiHandle index = iter ? vpi_scan(iter) : NULL;
            check(index && integer_value(index) == indices[i - 1], name,
                  "index traversal order");
            if (!index) {
                iter = NULL;
                break;
            }
        }
        if (iter) {
            vpiHandle extra = vpi_scan(iter);
            check(!extra, name, "index traversal length");
            if (extra) vpi_free_object(iter);
        }
        return;
    }

    struct dimension dim = dims[depth];
    int low = dim.left < dim.right ? dim.left : dim.right;
    int high = dim.left > dim.right ? dim.left : dim.right;
    int size = high - low + 1;
    check_properties(obj, interconnect_array, "vpiInterconnectArray",
                     size, name);
    check_range(obj, dim.left, dim.right, name);
    check(vpi_get(vpiPacked, obj) == dim.packed, name, "packed flag");
    check(vpi_handle(vpiTypespec, obj) == NULL, name, "null array typespec");
    s_vpi_value aggregate = {.format = vpiObjTypeVal};
    vpi_get_value(obj, &aggregate);
    check(aggregate.format == vpiSuppressVal, name, "no aggregate value");
    check(!vpi_handle_by_index(obj, low - 1) && !vpi_handle_by_index(obj, high + 1),
          name, "bounds checking");

    for (int i = low; i <= high; ++i) {
        char child_name[128];
        snprintf(child_name, sizeof child_name, "%s[%d]", name, i);
        indices[depth] = i;
        vpiHandle child = vpi_handle_by_index(obj, i);
        if (child)
            check(vpi_handle(vpiParent, child) == obj, child_name, "parent identity");
        int ordinal = dim.packed && dim.left > dim.right ? high - i : i - low;
        check_tree(root, child, child_name, dims, rank, indices, depth + 1,
                   bits, offset * size + ordinal);
    }
}

static void check_interconnect(const char *name, const struct dimension *dims,
                               int rank, const char *bits)
{
    PLI_INT32 indices[4];
    vpiHandle root = vpi_handle_by_name(name, NULL);
    check_tree(root, root, name, dims, rank, indices, 0, bits, 0);
}

static vpiHandle check_wire(const char *name, int size, const char *bits)
{
    vpiHandle wire = vpi_handle_by_name(name, NULL);
    check(wire != NULL, name, "ordinary net exists");
    if (wire) {
        const char *full_name = vpi_get_str(vpiFullName, wire);
        check(full_name && strcmp(full_name, name) == 0, name, "ordinary full name");
        check_properties(wire, vpiNet, "vpiNet", size, name);
        check(vpi_get(vpiNetType, wire) == vpiWire, name, "ordinary wire kind");
        check_value(wire, bits, name);
    }
    return wire;
}

static PLI_INT32 probe(PLI_BYTE8 *user_data)
{
    (void)user_data;
    const struct dimension packed[] = {{3, 0, 1}};
    const struct dimension both[] = {{0, 1, 0}, {1, 0, 1}};
    const struct dimension mixed[] = {{-2, -1, 0}, {5, 3, 0}, {4, 3, 1}, {-1, 0, 1}};
    const struct dimension unpacked[] = {{-1, -1, 0}};
    const struct dimension typed[] = {{1, 0, 1}, {1, 0, 1}};
    check_interconnect("top.packed_link", packed, 1, "1010");
    check_interconnect("top.both_link", both, 2, "0110");
    check_interconnect("top.mixed_link", mixed, 4, mixed_values);
    check_interconnect("top.bit_link", unpacked, 1, "1");
    check_interconnect("top.typed_link", typed, 2, "1011");

    vpiHandle top = vpi_handle_by_name("top", NULL);
    if (top) {
        vpiHandle iter = vpi_iterate(interconnect_array, top);
        unsigned count = 0;
        if (iter) {
            while (vpi_scan(iter)) ++count;
        }
        check(count == 5, "top", "interconnect declarations");
    }

    vpiHandle wire = check_wire("top.dst.plain_wire", 1, "1");
    vpiHandle vector = check_wire("top.dst.plain_vector", 3, "101");
    vpiHandle packed_out = check_wire("top.src[0].packed_out", 4, "1010");
    if (packed_out) check_range(packed_out, 0, 3, "packed_out");
    if (wire) check(!vpi_get(vpiPacked, wire), "plain_wire", "ordinary packed flag");
    if (vector) {
        check_range(vector, 4, 2, "plain_vector");
        check(!vpi_get(vpiPacked, vector), "plain_vector", "ordinary packed flag");
        vpiHandle bit = vpi_handle_by_index(vector, 4);
        check(bit && vpi_get(vpiType, bit) == vpiNetBit, "plain_vector", "ordinary bit type");
    }

    vpiHandle array = vpi_handle_by_name("top.dst.plain_array", NULL);
    check(array != NULL, "plain_array", "ordinary array exists");
    if (array) {
        check_properties(array, vpiNetArray, "vpiNetArray", 2, "plain_array");
        check_range(array, 4, 5, "plain_array");
        check(!vpi_get(vpiPacked, array), "plain_array", "ordinary packed flag");
        vpiHandle word = check_wire("top.dst.plain_array[4]", 2, "01");
        check(word && vpi_handle_by_index(array, 4) == word, "plain_array", "word identity");
    }

    /* The source port shares word nexuses with the interconnect. The sink
       sees the same values through its whole-array input connection. */
    const char *port_names[] = {"top.src[0].mixed_out", "top.dst.whole"};
    for (unsigned port = 0; port < sizeof port_names / sizeof *port_names; ++port) {
        const char *port_name = port_names[port];
        vpiHandle port_net = vpi_handle_by_name(port_name, NULL);
        check(port_net != NULL, port_name, "port net exists");
        if (!port_net) continue;
        check_properties(port_net, vpiNetArray, "vpiNetArray", 6, port_name);
        for (int word = 0; word < 6; ++word) {
            char word_name[64], link_name[64];
            snprintf(word_name, sizeof word_name, "%s[%d]", port_name, word);
            snprintf(link_name, sizeof link_name, "top.mixed_link[%d][%d]",
                     word / 3 - 2, word % 3 + 3);
            char bits[5] = {0};
            memcpy(bits, mixed_values + word * 4, 4);
            vpiHandle alias = check_wire(word_name, 4, bits);
            vpiHandle link = vpi_handle_by_name(link_name, NULL);
            check(alias && link && alias != link, word_name, "distinct declaration handles");
        }
    }

    if (failed) vpip_set_return_value(1);
    else vpi_printf("PASSED\n");
    return 0;
}

static void setup(void)
{
    s_vpi_systf_data tf = {.type = vpiSysTask, .tfname = "$probe_arrays",
                          .calltf = probe};
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {setup, NULL};
