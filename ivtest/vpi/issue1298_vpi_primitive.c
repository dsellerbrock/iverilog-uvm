#include <string.h>
#include <vpi_user.h>

#ifndef vpiGate
#define vpiGate 21
#define vpiSwitch 55
#define vpiUdp 65
#define vpiPrimTerm 46
#define vpiTableEntry 58
#endif
#ifndef vpiPrimitive
#define vpiPrimitive 103
#endif
#ifndef vpiTermIndex
#define vpiTermIndex 30
#define vpiAndPrim 1
#define vpiNotPrim 8
#define vpiSeqPrim 27
#define vpiCombPrim 28
#endif

static int check_terminals(const char *path, unsigned count,
                           const int *directions, const int *values)
{
    vpiHandle primitive = vpi_handle_by_name((PLI_BYTE8 *)path, 0);
    vpiHandle iter = primitive ? vpi_iterate(vpiPrimTerm, primitive) : 0;
    vpiHandle terminal;
    unsigned index = 0;

    while (iter && (terminal = vpi_scan(iter))) {
        s_vpi_value value;
        if (index >= count || vpi_get(vpiTermIndex, terminal) != (int)index
            || vpi_get(vpiDirection, terminal) != directions[index]
            || vpi_handle(vpiPrimitive, terminal) != primitive) {
            vpi_printf("FAIL %s terminal metadata at index %u\n", path, index);
            return 0;
        }
        value.format = vpiScalarVal;
        vpi_get_value(terminal, &value);
        if (value.value.scalar != values[index]) {
            vpi_printf("FAIL %s terminal value at index %u: %d\n",
                       path, index, value.value.scalar);
            return 0;
        }
        index++;
    }
    if (index != count) {
        vpi_printf("FAIL %s terminal count %u, expected %u\n",
                   path, index, count);
        return 0;
    }
    return 1;
}

static int check_udp_table(vpiHandle udp)
{
    static const char *expected[] = { "000", "010", "100", "111" };
    vpiHandle definition = vpi_handle(vpiUdpDefn, udp);
    vpiHandle iter;
    vpiHandle entry;
    unsigned index = 0;

    if (!definition || vpi_get(vpiType, definition) != vpiUdpDefn
        || vpi_get(vpiSize, definition) != 2
        || vpi_get(vpiPrimType, definition) != vpiCombPrim
        || !vpi_get_str(vpiDefName, definition)
        || strcmp(vpi_get_str(vpiDefName, definition), "myudp") != 0) {
        vpi_printf("FAIL UDP definition metadata\n");
        return 0;
    }

    iter = vpi_iterate(vpiTableEntry, definition);
    while (iter && (entry = vpi_scan(iter))) {
        s_vpi_value value;
        if (index >= sizeof expected / sizeof expected[0]) {
            vpi_printf("FAIL too many UDP table entries\n");
            return 0;
        }
        value.format = vpiStringVal;
        vpi_get_value(entry, &value);
        if (!value.value.str || strcmp(value.value.str, expected[index]) != 0) {
            vpi_printf("FAIL UDP table entry %u\n", index);
            return 0;
        }
        index++;
    }
    if (index != sizeof expected / sizeof expected[0]) {
        vpi_printf("FAIL UDP table entry count %u\n", index);
        return 0;
    }
    return 1;
}

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    static const struct {
        const char *name;
        int type;
        int primitive_type;
        unsigned inputs;
    } expected[] = {
        { "top.g", vpiGate, vpiAndPrim, 2 },
        { "top.inv", vpiGate, vpiNotPrim, 1 },
        { "top.udp1", vpiUdp, vpiCombPrim, 2 }
    };
    static const int and_directions[] = { vpiOutput, vpiInput, vpiInput };
    static const int and_values[] = { vpi0, vpi0, vpi1 };
    static const int not_directions[] = { vpiOutput, vpiInput };
    static const int not_values[] = { vpi1, vpi0 };
    vpiHandle top = vpi_handle_by_name((PLI_BYTE8 *)"top", 0);
    vpiHandle iter = top ? vpi_iterate(vpiPrimitive, top) : 0;
    vpiHandle primitive;
    unsigned count = 0;
    unsigned name_mask = 0;
    unsigned idx;

    (void)data;
    while (iter && (primitive = vpi_scan(iter))) {
        const char *name = vpi_get_str(vpiFullName, primitive);
        unsigned idx;
        if (!name) {
            vpi_printf("FAIL primitive without full name\n");
            goto fail;
        }
        for (idx = 0; idx < sizeof expected / sizeof expected[0]; idx++)
            if (strcmp(name, expected[idx].name) == 0) break;
        if (idx == sizeof expected / sizeof expected[0]
            || (name_mask & (1u << idx))) {
            vpi_printf("FAIL unexpected or duplicate primitive %s\n", name);
            goto fail;
        }
        name_mask |= 1u << idx;
        count++;
    }
    if (count != sizeof expected / sizeof expected[0]
        || name_mask != (1u << (sizeof expected / sizeof expected[0])) - 1) {
        vpi_printf("FAIL primitive count %u\n", count);
        goto fail;
    }

    for (idx = 0; idx < sizeof expected / sizeof expected[0]; idx++) {
        vpiHandle handle = vpi_handle_by_name((PLI_BYTE8 *)expected[idx].name, 0);
        if (!handle || vpi_get(vpiType, handle) != expected[idx].type
            || vpi_get(vpiPrimType, handle) != expected[idx].primitive_type
            || vpi_get(vpiSize, handle) != expected[idx].inputs
            || vpi_handle(vpiScope, handle) != top) {
            vpi_printf("FAIL primitive metadata for %s\n", expected[idx].name);
            goto fail;
        }
    }

    if (!check_terminals("top.g", 3, and_directions, and_values)
        || !check_terminals("top.inv", 2, not_directions, not_values)
        || !check_terminals("top.udp1", 3, and_directions, and_values)
        || !check_udp_table(vpi_handle_by_name((PLI_BYTE8 *)"top.udp1", 0)))
        goto fail;

    vpi_printf("PRIMITIVE_COUNT=%u\nPASSED\n", count);
    return 0;

fail:
    vpi_control(vpiFinish, 1);
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$probe_primitives";
    data.calltf = probe;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
